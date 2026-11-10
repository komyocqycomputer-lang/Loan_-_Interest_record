import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/loan_record.dart';
import '../services/printer_service.dart';
import '../utils/loan_calculator_helper.dart';

class PrintReceiptDialog extends StatefulWidget {
  final LoanRecord record;
  final String storeName;
  final String storeSubtitle;

  const PrintReceiptDialog({
    super.key,
    required this.record,
    required this.storeName,
    required this.storeSubtitle,
  });

  @override
  State<PrintReceiptDialog> createState() => _PrintReceiptDialogState();
}

class _PrintReceiptDialogState extends State<PrintReceiptDialog> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();

  String _paperSize = '80mm';
  String _selectedBtName = '';
  String _selectedBtAddress = '';
  final TextEditingController _wifiIpController = TextEditingController(
    text: '192.168.1.100',
  );
  final TextEditingController _wifiPortController = TextEditingController(
    text: '9100',
  );
  bool _showWifiConfig = false;

  bool _isBusy = false;
  bool _includePhotoForCapture = false;
  String? _statusText;
  String _statusType = 'info'; // 'info' | 'success' | 'error'
  late final String _printDateStr;

  @override
  void initState() {
    super.initState();
    _printDateStr = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    _loadSavedConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = widget.record.photoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      precacheImage(FileImage(File(path)), context);
    }
  }

  @override
  void dispose() {
    _wifiIpController.dispose();
    _wifiPortController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final cfg = await PrinterService.getSavedPrinterConfig();
    if (!mounted) return;
    setState(() {
      _paperSize = cfg['paperSize'] ?? '80mm';
      _selectedBtName = cfg['btName'] ?? '';
      _selectedBtAddress = cfg['btAddress'] ?? '';
      _wifiIpController.text = cfg['wifiIp'] ?? '192.168.1.100';
      _wifiPortController.text = cfg['wifiPort'] ?? '9100';
    });
  }

  void _setStatus(String text, String type) {
    if (!mounted) return;
    setState(() {
      _statusText = text;
      _statusType = type;
    });
  }

  String _formattedHeading() {
    final raw = widget.storeName.trim().isNotEmpty
        ? widget.storeName.trim()
        : 'ပညာရေး ရန်ပုံငွေ';
    if (raw.startsWith('"') && raw.endsWith('"')) {
      return raw;
    }
    return '"$raw"';
  }

  String _formattedPhone() {
    final r = widget.record;
    final phones = [
      r.phone1.trim(),
      r.phone2.trim(),
    ].where((p) => p.isNotEmpty).join(', ');
    return phones.isNotEmpty ? phones : '-';
  }

  String _formattedGuarantee() {
    final r = widget.record;
    if (r.guarantee != null && r.guarantee!.trim().isNotEmpty) {
      return r.guarantee!.trim();
    }
    if (r.notes != null && r.notes!.trim().isNotEmpty) {
      return r.notes!.trim();
    }
    return '-';
  }

  String _formattedRate() {
    final rate = widget.record.monthlyInterestRate;
    if (rate % 1 == 0) {
      return '${rate.toInt()}%';
    }
    return '$rate%';
  }

  /// Captures the visual receipt widget as a crisp [ui.Image] scaled to the exact thermal dot width
  /// (576 dots for 80mm, 384 dots for 58mm).
  /// [includePhoto] controls whether the customer photo is included (true only for Save PNG, false for all printers).
  Future<ui.Image> _captureReceiptImage({required bool includePhoto}) async {
    if (_includePhotoForCapture != includePhoto && mounted) {
      setState(() {
        _includePhotoForCapture = includePhoto;
      });
    }
    if (includePhoto) {
      final path = widget.record.photoPath;
      if (path != null &&
          path.isNotEmpty &&
          File(path).existsSync() &&
          mounted) {
        await precacheImage(FileImage(File(path)), context);
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 40));
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        _receiptBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('ပြေစာ ပုံဖော်ရာတွင် အခက်အခဲရှိနေပါသည်');
    }
    final logicalWidth = boundary.size.width;
    final targetDots = _paperSize == '58mm' ? 384.0 : 576.0;
    final pixelRatio = (targetDots / logicalWidth).clamp(1.2, 3.0);
    return await boundary.toImage(pixelRatio: pixelRatio);
  }

  Future<Uint8List> _captureReceiptPngBytes() async {
    try {
      final image = await _captureReceiptImage(includePhoto: true);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('PNG အဖြစ် ပြောင်းလဲ၍ မရပါ');
      }
      return byteData.buffer.asUint8List();
    } finally {
      if (mounted && _includePhotoForCapture) {
        setState(() {
          _includePhotoForCapture = false;
        });
      }
    }
  }

  Future<Uint8List> _captureReceiptEscPosBytes() async {
    final image = await _captureReceiptImage(includePhoto: false);
    return await PrinterService.convertImageToEscPosRaster(
      image,
      is58mm: _paperSize == '58mm',
    );
  }

  Future<void> _handleBluetoothPrint({String? overrideAddress}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _setStatus(
      'Bluetooth ($_paperSize) Printer သို့ ချိတ်ဆက်၍ Print ထုတ်နေပါသည်...',
      'info',
    );

    try {
      final escPosBytes = await _captureReceiptEscPosBytes();
      final connected = await PrinterService.printViaBluetooth(
        escPosBytes: escPosBytes,
        address: overrideAddress ?? _selectedBtAddress,
      );
      if (mounted) {
        setState(() {
          _selectedBtName = connected['name'] ?? 'Bluetooth Printer';
          _selectedBtAddress = connected['address'] ?? '';
        });
      }
      _setStatus(
        'Bluetooth Printer (${connected['name']}) သို့ Print ထုတ်ပြီးပါပြီ!',
        'success',
      );
    } on PlatformException catch (e) {
      _setStatus(e.message ?? 'Bluetooth Print မအောင်မြင်ပါ', 'error');
    } catch (e) {
      _setStatus(e.toString().replaceFirst('Exception: ', ''), 'error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showBluetoothDevicePicker() async {
    try {
      final devices = await PrinterService.getPairedBluetoothDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        _setStatus(
          'Pair လုပ်ထားသော Bluetooth Printer မတွေ့ပါ။ ဖုန်း၏ Bluetooth Settings တွင် Printer ကို အရင် Pair လုပ်ပေးပါ။',
          'error',
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F182C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bluetooth, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text(
                            'Bluetooth Printer ရွေးချယ်ရန်',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          await PrinterService.clearSavedBluetoothPrinter();
                          if (mounted) {
                            setState(() {
                              _selectedBtName = '';
                              _selectedBtAddress = '';
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Auto ထားမည်',
                          style: TextStyle(color: Color(0xFFF59E0B)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (_, i) {
                        final d = devices[i];
                        final isSelected = d.address == _selectedBtAddress;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Icon(
                            d.isPrinter ? Icons.print : Icons.bluetooth_audio,
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          title: Text(
                            d.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            d.address,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          trailing: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            onPressed: () async {
                              await PrinterService.saveSelectedBluetoothPrinter(
                                d.name,
                                d.address,
                              );
                              if (mounted) {
                                setState(() {
                                  _selectedBtName = d.name;
                                  _selectedBtAddress = d.address;
                                });
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _handleBluetoothPrint(
                                overrideAddress: d.address,
                              );
                            },
                            child: const Text(
                              'ချိတ်ပြီး Print',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on PlatformException catch (e) {
      _setStatus(e.message ?? 'Bluetooth ရှာဖွေ၍ မရပါ', 'error');
    } catch (e) {
      _setStatus(e.toString().replaceFirst('Exception: ', ''), 'error');
    }
  }

  Future<void> _handleWifiPrint() async {
    if (_isBusy) return;
    final host = _wifiIpController.text.trim();
    final port = int.tryParse(_wifiPortController.text.trim()) ?? 9100;
    if (host.isEmpty) {
      setState(() => _showWifiConfig = true);
      _setStatus('ကျေးဇူးပြု၍ WiFi Printer IP Address ထည့်သွင်းပါ', 'error');
      return;
    }

    setState(() => _isBusy = true);
    _setStatus(
      'WiFi / Network Printer ($host:$port) သို့ ပို့နေပါသည်...',
      'info',
    );
    try {
      final escPosBytes = await _captureReceiptEscPosBytes();
      await PrinterService.printViaNetwork(
        host: host,
        port: port,
        escPosBytes: escPosBytes,
      );
      _setStatus(
        'WiFi Printer ($host:$port) သို့ Print ထုတ်ပြီးပါပြီ!',
        'success',
      );
    } on PlatformException catch (e) {
      _setStatus(e.message ?? 'WiFi Print မအောင်မြင်ပါ', 'error');
    } catch (e) {
      _setStatus(e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleUsbPrint() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _setStatus('USB Printer သို့ ချိတ်ဆက်၍ Print ထုတ်နေပါသည်...', 'info');
    try {
      final escPosBytes = await _captureReceiptEscPosBytes();
      final usbName = await PrinterService.printViaUsb(
        escPosBytes: escPosBytes,
      );
      _setStatus('USB Printer ($usbName) သို့ Print ထုတ်ပြီးပါပြီ!', 'success');
    } on PlatformException catch (e) {
      _setStatus(e.message ?? 'USB Print မအောင်မြင်ပါ', 'error');
    } catch (e) {
      _setStatus(e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleSavePngToGallery() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _setStatus('ပြေစာပုံ (PNG) ကို Gallery ထဲသို့ သိမ်းဆည်းနေပါသည်...', 'info');
    try {
      final pngBytes = await _captureReceiptPngBytes();
      final code = widget.record.codeNo.isNotEmpty
          ? widget.record.codeNo
          : '001';
      final fileName =
          'Receipt_${code}_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedLocation = await PrinterService.saveReceiptToGallery(
        pngBytes: pngBytes,
        fileName: fileName,
      );
      _setStatus(
        'ပြေစာ PNG ကို Gallery ($savedLocation) တွင် သိမ်းဆည်းပြီးပါပြီ!',
        'success',
      );
    } on PlatformException catch (e) {
      _setStatus(e.message ?? 'PNG သိမ်းဆည်းမှု မအောင်မြင်ပါ', 'error');
    } catch (e) {
      _setStatus(e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final hasPhoto =
        r.photoPath != null &&
        r.photoPath!.isNotEmpty &&
        File(r.photoPath!).existsSync();

    final durResult = LoanCalculatorHelper.calculateDuration(
      LoanCalculatorHelper.parseDMY(r.startDate),
      LoanCalculatorHelper.parseDMY(r.endDate),
    );
    final int years = durResult.isValid ? durResult.years : 0;
    final int months = durResult.isValid ? durResult.months : 0;
    final int days = durResult.isValid ? durResult.days : 0;
    final double monthlyInt = (r.loanAmount * r.monthlyInterestRate) / 100.0;
    final double yearsInterest = monthlyInt * 12.0 * years;
    final double monthsInterest = monthlyInt * months;
    final double daysInterest = (monthlyInt / 30.0) * days;

    return Dialog(
      backgroundColor: const Color(0xFF0F182C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.print,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'All Device Print',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Paper Size + Bluetooth Device Selector Bar
            Row(
              children: [
                _sizeOption('80mm'),
                const SizedBox(width: 6),
                _sizeOption('58mm'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _showBluetoothDevicePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162136),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF24324D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bluetooth_connected,
                            color: Color(0xFF10B981),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _selectedBtName.isNotEmpty
                                  ? _selectedBtName
                                  : 'Auto BT Printer (ရွေးရန်)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Optional WiFi IP / Port configuration bar
            if (_showWifiConfig) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _wifiIpController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Printer IP (192.168.1.100)',
                            hintStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF090E1B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _wifiPortController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                          decoration: InputDecoration(
                            hintText: '9100',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF090E1B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                      ),
                      onPressed: _handleWifiPrint,
                      child: const Text(
                        'Print',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Status Banner
            if (_statusText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _statusType == 'error'
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : _statusType == 'success'
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusType == 'error'
                        ? const Color(0xFFEF4444)
                        : _statusType == 'success'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0EA5E9),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isBusy)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF59E0B),
                        ),
                      )
                    else
                      Icon(
                        _statusType == 'error'
                            ? Icons.error_outline
                            : _statusType == 'success'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 16,
                        color: _statusType == 'error'
                            ? const Color(0xFFF87171)
                            : _statusType == 'success'
                            ? const Color(0xFF34D399)
                            : const Color(0xFF38BDF8),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText!,
                        style: TextStyle(
                          color: _statusType == 'error'
                              ? const Color(0xFFFCA5A5)
                              : _statusType == 'success'
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFBAE6FD),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Receipt Paper Visual Preview (Captured by RepaintBoundary for 100% exact thermal graphic printing)
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090E1B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: SingleChildScrollView(
                  child: Center(
                    child: RepaintBoundary(
                      key: _receiptBoundaryKey,
                      child: Container(
                        width: _paperSize == '58mm' ? 255 : 320,
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Top Heading (Center Aligned)
                            Text(
                              _formattedHeading(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 3),

                            // 2. Subtitle (Center Aligned)
                            Text(
                              widget.storeSubtitle.trim().isNotEmpty
                                  ? widget.storeSubtitle.trim()
                                  : 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // 3. Code No. (Center Aligned)
                            Text(
                              'Code No. : ${r.codeNo.isNotEmpty ? r.codeNo : "001"}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // 4. Optional Customer Photo (Only included when saving PNG, omitted for Bluetooth/WiFi/LAN/USB/Network prints)
                            if (hasPhoto && _includePhotoForCapture) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.black54,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.file(
                                      File(r.photoPath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            _dashedDivider(),
                            const SizedBox(height: 8),

                            // 5. Receipt Body Rows (Exact labels & alignment requested)
                            _receiptRow(
                              'အမည်',
                              r.name.isNotEmpty ? r.name : '-',
                            ),
                            _receiptRow(
                              'နေရပ်။',
                              r.address.isNotEmpty ? r.address : '-',
                            ),
                            _receiptRow('Phone:', _formattedPhone()),
                            _receiptRow('အာမခံ', _formattedGuarantee()),
                            _receiptRow(
                              'ချေးငွေ',
                              LoanCalculatorHelper.formatCurrency(r.loanAmount),
                            ),
                            _receiptRow('အတိုးနှုန်း', _formattedRate()),
                            _receiptRow(
                              'စတင်ရက်',
                              r.startDate.isNotEmpty ? r.startDate : '-',
                            ),
                            _receiptRow(
                              'ပြီးဆုံးရက်',
                              r.endDate.isNotEmpty ? r.endDate : '-',
                            ),
                            _receiptRow(
                              'ကြာချိန်',
                              r.durationText.isNotEmpty ? r.durationText : '-',
                            ),

                            const SizedBox(height: 6),
                            _dashedDivider(),
                            const SizedBox(height: 6),

                            // 6. Breakdown Summary Rows
                            _receiptRow(
                              'ချေးငွေရင်း',
                              LoanCalculatorHelper.formatCurrency(r.loanAmount),
                            ),
                            if (years > 0)
                              _receiptRow(
                                '$years နှစ်တိုးငွေ',
                                LoanCalculatorHelper.formatCurrency(
                                  yearsInterest,
                                ),
                              ),
                            if (months > 0)
                              _receiptRow(
                                '$months လတိုးငွေ',
                                LoanCalculatorHelper.formatCurrency(
                                  monthsInterest,
                                ),
                              ),
                            if (days > 0)
                              _receiptRow(
                                '$days ရက်တိုးငွေ',
                                LoanCalculatorHelper.formatCurrency(
                                  daysInterest,
                                ),
                              ),
                            const SizedBox(height: 6),
                            _dashedDivider(),
                            const SizedBox(height: 6),
                            _receiptRow(
                              'တိုးရင်းပေါင်း',
                              LoanCalculatorHelper.formatCurrency(
                                r.totalAmountDue,
                              ),
                              isBoldValue: true,
                            ),

                            const SizedBox(height: 6),
                            _dashedDivider(),
                            const SizedBox(height: 8),

                            // 7. Footer (Center Aligned)
                            const Text(
                              'သတ်မှတ်ရက်တွင် အကြေပေးချေပါ။',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Print date: $_printDateStr',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Primary Action: Wireless Bluetooth 80mm/58mm Auto Connect & Print
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: const Icon(Icons.bluetooth, size: 20),
                label: const Text(
                  'Bluetooth Print',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isBusy ? null : () => _handleBluetoothPrint(),
              ),
            ),

            const SizedBox(height: 8),

            // Secondary Row: WiFi / USB / Save png
            Row(
              children: [
                Expanded(
                  child: _quickModeButton(
                    icon: Icons.wifi,
                    label: 'WiFi/LAN',
                    onTap: () {
                      setState(() => _showWifiConfig = !_showWifiConfig);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quickModeButton(
                    icon: Icons.usb,
                    label: 'USB Print',
                    onTap: _handleUsbPrint,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quickModeButton(
                    icon: Icons.download_rounded,
                    label: 'Save png',
                    onTap: _handleSavePngToGallery,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBoldValue = false}) {
    // 0.2 inch ≈ 19.2 logical pixels (at 96 DPI)
    const double zeroPointTwoInch = 19.2;
    return Padding(
      padding: const EdgeInsets.only(
        left: zeroPointTwoInch,
        top: 3.0,
        bottom: 3.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _paperSize == '58mm' ? 86 : 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: zeroPointTwoInch),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.2;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black87),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _quickModeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE2E8F0),
        side: const BorderSide(color: Color(0xFF334155)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      onPressed: _isBusy ? null : onTap,
      onLongPress: _isBusy ? null : onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeOption(String size) {
    final isSelected = _paperSize == size;
    return InkWell(
      onTap: () {
        setState(() => _paperSize = size);
        PrinterService.savePaperSize(size);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD97706).withValues(alpha: 0.25)
              : const Color(0xFF162136),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF24324D),
          ),
        ),
        child: Text(
          isSelected ? '✓ $size' : size,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}
