import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/loan_record.dart';
import '../services/storage_service.dart';
import '../utils/loan_calculator_helper.dart';
import '../dialogs/print_receipt_dialog.dart';
import '../dialogs/sidebar_dialogs.dart';
import 'records_screen.dart';
import 'image_crop_screen.dart';
import '../widgets/date_input_field.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLockApp;

  const HomeScreen({super.key, required this.onLockApp});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Store info
  String _storeName = 'ပညာရေး အလှူငွေ';
  String _storeSubtitle = 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';

  // Form Controllers
  final _codeNoController = TextEditingController(text: '001');
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guaranteeController = TextEditingController();
  final _amountController = TextEditingController(text: '100,000');
  final _rateController = TextEditingController(text: '2.0');
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _searchController = TextEditingController();

  // Active record state
  String _currentId = '';
  bool _isSaved = false;
  String? _photoPath;
  String _durationText = '1 လ၊ 0 ရက်';
  double _durationMonths = 1.0;
  int _durationYears = 0;
  int _durationMonthsPart = 1;
  int _durationDaysPart = 0;
  double _yearsInterest = 0.0;
  double _monthsInterest = 2000.0;
  double _daysInterest = 0.0;
  double _totalInterest = 2000.0;
  double _totalDue = 102000.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDateController.text = LoanCalculatorHelper.formatDMY(now);
    _endDateController.text = LoanCalculatorHelper.formatDMY(
      LoanCalculatorHelper.addMonths(now, 1),
    );
    _initApp();
  }

  Future<void> _initApp() async {
    final info = await StorageService.getStoreInfo();
    setState(() {
      _storeName = info['name'] ?? 'ပညာရေး အလှူငွေ';
      _storeSubtitle = info['subtitle'] ?? 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';
    });

    final now = DateTime.now();
    _startDateController.text = LoanCalculatorHelper.formatDMY(now);
    final oneMonthAhead = LoanCalculatorHelper.addMonths(now, 1);
    _endDateController.text = LoanCalculatorHelper.formatDMY(oneMonthAhead);

    _startNewRecord(showToast: false);
  }

  Future<void> _startNewRecord({bool showToast = true}) async {
    final nextCode = await StorageService.getNextCodeNumber();
    final now = DateTime.now();
    final todayStr = LoanCalculatorHelper.formatDMY(now);
    final oneMonthAhead = LoanCalculatorHelper.addMonths(now, 1);
    final nextMonthStr = LoanCalculatorHelper.formatDMY(oneMonthAhead);

    setState(() {
      _currentId = 'rec-${DateTime.now().millisecondsSinceEpoch}';
      _isSaved = false;
      _codeNoController.text = nextCode;
      _nameController.clear();
      _addressController.clear();
      _phoneController.clear();
      _guaranteeController.clear();
      _amountController.text = '100,000';
      _rateController.text = '2.0';
      _startDateController.text = todayStr;
      _endDateController.text = nextMonthStr;
      _photoPath = null;
      _searchController.clear();
    });

    _recalculate();

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('စာရင်းအသစ် ($nextCode) စတင်ပါပြီ'),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _loadRecord(LoanRecord record) {
    final now = DateTime.now();
    final todayStr = LoanCalculatorHelper.formatDMY(now);

    setState(() {
      _currentId = record.id;
      _isSaved = false;
      _codeNoController.text = record.codeNo;
      _nameController.text = record.name;
      _addressController.text = record.address;
      _phoneController.text = record.phone1.isNotEmpty
          ? record.phone1
          : record.phone2;
      _guaranteeController.text = record.guarantee ?? record.notes ?? '';
      _amountController.text = LoanCalculatorHelper.formatCurrency(
        record.loanAmount,
      );
      _rateController.text = record.monthlyInterestRate.toString();
      _startDateController.text = record.startDate.isNotEmpty
          ? record.startDate
          : todayStr;
      _endDateController.text = todayStr;
      _photoPath =
          (record.photoPath != null &&
              record.photoPath!.isNotEmpty &&
              File(record.photoPath!).existsSync())
          ? record.photoPath
          : null;
      _searchController.clear();
    });

    _recalculate();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ကုတ် [${record.codeNo}] ${record.name} ကို ထည့်သွင်းပြီးပါပြီ',
          ),
          backgroundColor: const Color(0xFF0284C7),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _recalculate() {
    final start = LoanCalculatorHelper.parseDMY(_startDateController.text);
    final end = LoanCalculatorHelper.parseDMY(_endDateController.text);

    final durResult = LoanCalculatorHelper.calculateDuration(start, end);
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    final calcResult = LoanCalculatorHelper.calculateLoan(
      loanAmount: amount,
      monthlyRatePercent: rate,
      durationMonths: durResult.isValid ? durResult.totalMonthsFraction : 0.0,
    );

    final monthlyInt = (amount * rate) / 100.0;
    final years = durResult.isValid ? durResult.years : 0;
    final months = durResult.isValid ? durResult.months : 0;
    final days = durResult.isValid ? durResult.days : 0;

    setState(() {
      _durationText = durResult.displayText;
      _durationMonths = durResult.isValid ? durResult.totalMonthsFraction : 0.0;
      _durationYears = years;
      _durationMonthsPart = months;
      _durationDaysPart = days;
      _yearsInterest = monthlyInt * 12.0 * years;
      _monthsInterest = monthlyInt * months;
      _daysInterest = (monthlyInt / 30.0) * days;
      _totalInterest = calcResult.totalInterest;
      _totalDue = calcResult.totalAmountDue;
    });
  }

  Future<void> _cropAndSetPhoto(String rawPath) async {
    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          imageFile: File(rawPath),
          aspectRatio: 92.0 / 122.0,
        ),
      ),
    );
    if (croppedPath != null && mounted) {
      setState(() => _photoPath = croppedPath);
    }
  }

  Future<void> _pickPhoto() async {
    final bool hasValidPhoto =
        _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131D30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFF59E0B)),
              title: const Text(
                'ကင်မရာဖြင့် ရိုက်မည်',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final pic = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1920,
                  imageQuality: 90,
                );
                if (pic != null) {
                  await _cropAndSetPhoto(pic.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFF59E0B),
              ),
              title: const Text(
                'Gallery မှ ရွေးမည်',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final pic = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  imageQuality: 90,
                );
                if (pic != null) {
                  await _cropAndSetPhoto(pic.path);
                }
              },
            ),
            if (hasValidPhoto)
              ListTile(
                leading: const Icon(Icons.crop, color: Color(0xFFF59E0B)),
                title: const Text(
                  'လက်ရှိဓာတ်ပုံကို Crop ပြန်လုပ်မည်',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _cropAndSetPhoto(_photoPath!);
                },
              ),
            if (hasValidPhoto)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'ဓာတ်ပုံ ဖျက်မည်',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSaved = false;
                    _photoPath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecord() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ကျေးဇူးပြု၍ "အမည်" ထည့်သွင်းပါ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    final record = LoanRecord(
      id: _currentId.isNotEmpty
          ? _currentId
          : 'rec-${DateTime.now().millisecondsSinceEpoch}',
      codeNo: _codeNoController.text.trim(),
      name: name,
      address: _addressController.text.trim(),
      phone1: _phoneController.text.trim(),
      phone2: '',
      guarantee: _guaranteeController.text.trim(),
      notes: _guaranteeController.text.trim(),
      loanAmount: amount,
      monthlyInterestRate: rate,
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim(),
      durationText: _durationText,
      durationMonths: _durationMonths,
      totalInterest: _totalInterest,
      totalAmountDue: _totalDue,
      photoPath: _photoPath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await StorageService.saveRecord(record);

    if (mounted) {
      setState(() {
        _isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ကုတ် [${record.codeNo}] ${record.name} စာရင်း သိမ်းဆည်းပြီးပါပြီ!',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  LoanRecord _getCurrentRecord() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    return LoanRecord(
      id: _currentId,
      codeNo: _codeNoController.text.trim(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone1: _phoneController.text.trim(),
      phone2: '',
      guarantee: _guaranteeController.text.trim(),
      notes: _guaranteeController.text.trim(),
      loanAmount: amount,
      monthlyInterestRate: rate,
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim(),
      durationText: _durationText,
      durationMonths: _durationMonths,
      totalInterest: _totalInterest,
      totalAmountDue: _totalDue,
      photoPath: _photoPath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _onQuickSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    final records = await StorageService.getRecords();
    final match = records.where((r) {
      return r.codeNo.toLowerCase() == q ||
          r.name.toLowerCase().contains(q) ||
          r.phone1.contains(q);
    }).firstOrNull;

    if (match != null) {
      _loadRecord(match);
    }
  }

  @override
  void dispose() {
    _codeNoController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _guaranteeController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curAmount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1527),
      drawer: _buildSidebarDrawer(context),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1527),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'မီနူး',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            Text(
              _storeName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              _storeSubtitle,
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Section: Search, Code, + New, Camera
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2B43)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side inputs
                          Expanded(
                            child: Column(
                              children: [
                                // Row 1: ရှာရန် | Code / အမည်
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 48,
                                      child: Text(
                                        'ရှာရန်',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B111F),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          onSubmitted: _onQuickSearch,
                                          textInputAction:
                                              TextInputAction.search,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          cursorColor: const Color(0xFFF59E0B),
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Code / အမည်',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                              fontWeight: FontWeight.normal,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 0,
                                                ),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Row 2: Code | 006
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 48,
                                      child: Text(
                                        'Code',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B111F),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _codeNoController.text,
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Row 3: + အသစ် button
                                InkWell(
                                  onTap: () => _startNewRecord(),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B111F),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '+ အသစ်',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Right side: Camera box (ပုံထည့်)
                          InkWell(
                            onTap: _pickPhoto,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 92,
                              height: 122,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B111F),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                              child:
                                  _photoPath != null &&
                                      File(_photoPath!).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.file(
                                        File(_photoPath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Color(0xFFF59E0B),
                                          size: 28,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'ပုံထည့်',
                                          style: TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Form Inputs Container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2B43)),
                      ),
                      child: Column(
                        children: [
                          _formRow(
                            label: 'အမည်',
                            child: _inputBox(
                              controller: _nameController,
                              hint: 'ချေးယူသူ အမည်',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'နေရပ်',
                            child: _inputBox(
                              controller: _addressController,
                              hint: 'ရွာ၊ ရပ်ကွက်၊ မြို့နယ်',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'Phone',
                            child: _inputBox(
                              controller: _phoneController,
                              hint: '09...',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'အာမခံ',
                            child: _inputBox(
                              controller: _guaranteeController,
                              hint: 'ကူညီမှူချေးငွေ',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'ချေးငွေ',
                            child: _inputBox(
                              controller: _amountController,
                              hint: '100,000',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                ThousandsSeparatorInputFormatter(),
                              ],
                              suffix: 'ကျပ်',
                              onChanged: (_) => _recalculate(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Quick Chips for 10 သိန်း, 20 သိန်း, 50 သိန်း
                          Row(
                            children: [
                              const SizedBox(width: 100),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _quickAmountChip(
                                        '10 သိန်း',
                                        1000000,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _quickAmountChip(
                                        '20 သိန်း',
                                        2000000,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _quickAmountChip(
                                        '50 သိန်း',
                                        5000000,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'တလတိုး%',
                            child: _inputBox(
                              controller: _rateController,
                              hint: '2.0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              suffix: '%',
                              onChanged: (_) => _recalculate(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Quick Chips for 2%, 3%, 4%, 5%
                          Row(
                            children: [
                              const SizedBox(width: 100),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(child: _quickRateChip(2.0)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickRateChip(3.0)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickRateChip(4.0)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickRateChip(5.0)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'စတင်ရက်',
                            child: _dateInputBox(_startDateController),
                          ),
                          const SizedBox(height: 10),
                          _formRow(
                            label: 'ပြီးဆုံးရက်',
                            child: _dateInputBox(_endDateController),
                          ),
                          const SizedBox(height: 8),

                          // Quick Chips for 3 လ, 4 လ, 5 လ, 6 လ
                          Row(
                            children: [
                              const SizedBox(width: 100),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(child: _quickMonthChip(3)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickMonthChip(4)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickMonthChip(5)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _quickMonthChip(6)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ကြာချိန်
                          _formRow(
                            label: 'ကြာချိန်',
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF452206),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3D1E05),
                                    Color(0xFF542A07),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _durationText,
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Highlighted "ကျသင့်ငွေ" Box
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B2D05),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF662C05), Color(0xFF853B08)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFBBF24),
                                width: 1.8,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33F59E0B),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ကျသင့်ငွေ',
                                  style: TextStyle(
                                    color: Color(0xFFFEF3C7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${LoanCalculatorHelper.formatCurrency(_totalDue)} ကျပ်',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Breakdown Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _breakdownLine(
                            'ချေးငွေရင်း',
                            '${LoanCalculatorHelper.formatCurrency(curAmount)} ကျပ်',
                          ),
                          const SizedBox(height: 6),
                          _breakdownLine(
                            '$_durationYears နှစ်တိုးငွေ',
                            '${LoanCalculatorHelper.formatCurrency(_yearsInterest)} ကျပ်',
                          ),
                          const SizedBox(height: 6),
                          _breakdownLine(
                            '$_durationMonthsPart လတိုးငွေ',
                            '${LoanCalculatorHelper.formatCurrency(_monthsInterest)} ကျပ်',
                          ),
                          const SizedBox(height: 6),
                          _breakdownLine(
                            '$_durationDaysPart ရက်တိုးငွေ',
                            '${LoanCalculatorHelper.formatCurrency(_daysInterest)} ကျပ်',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Navigation / Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF090E1B),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  // Amber Button: Print (enabled only after Save is pressed)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _isSaved
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF334155),
                          foregroundColor: _isSaved
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          Icons.print,
                          size: 16,
                          color: _isSaved
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                        label: const Text(
                          'Print',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          if (!_isSaved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Print ထုတ်ရန် ကျေးဇူးပြု၍ "Save" ခလုတ်ကို အရင်နှိပ်ပါ',
                                ),
                                backgroundColor: Color(0xFFD97706),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (_) => PrintReceiptDialog(
                              record: _getCurrentRecord(),
                              storeName: _storeName,
                              storeSubtitle: _storeSubtitle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Green Button: Save
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _saveRecord,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF261D12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB45309)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (val) {
          if (_isSaved) {
            setState(() => _isSaved = false);
          }
          onChanged?.call(val);
        },
        cursorColor: const Color(0xFFF59E0B),
        style: const TextStyle(
          color: Color(0xFFF59E0B),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0x9994A3B8),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          isDense: true,
          suffixText: suffix,
          suffixStyle: const TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _dateInputBox(TextEditingController controller) {
    return DateInputField(
      controller: controller,
      onChanged: () {
        if (_isSaved) {
          setState(() => _isSaved = false);
        }
        _recalculate();
      },
    );
  }

  void _setQuickAmount(double amount) {
    setState(() {
      _isSaved = false;
      _amountController.text = LoanCalculatorHelper.formatCurrency(amount);
    });
    _recalculate();
  }

  bool _isQuickAmountActive(double amount) {
    final cur =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    return (cur - amount).abs() < 0.01;
  }

  Widget _quickAmountChip(String label, double amount) {
    final isSelected = _isQuickAmountActive(amount);
    return InkWell(
      onTap: () => _setQuickAmount(amount),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _setQuickRate(double rate) {
    setState(() {
      _isSaved = false;
      _rateController.text = rate.toStringAsFixed(1);
    });
    _recalculate();
  }

  bool _isQuickRateActive(double rate) {
    final cur = double.tryParse(_rateController.text) ?? 0.0;
    return (cur - rate).abs() < 0.01;
  }

  Widget _quickRateChip(double rate) {
    final isSelected = _isQuickRateActive(rate);
    final label = '${rate.toInt()}%';
    return InkWell(
      onTap: () => _setQuickRate(rate),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _setQuickMonths(int months) {
    var start = LoanCalculatorHelper.parseDMY(_startDateController.text);
    if (start == null) {
      start = DateTime.now();
      _startDateController.text = LoanCalculatorHelper.formatDMY(start);
    }
    final newEnd = LoanCalculatorHelper.addMonths(start, months);
    setState(() {
      _isSaved = false;
      _endDateController.text = LoanCalculatorHelper.formatDMY(newEnd);
    });
    _recalculate();
  }

  bool _isQuickMonthActive(int months) {
    final start = LoanCalculatorHelper.parseDMY(_startDateController.text);
    final end = LoanCalculatorHelper.parseDMY(_endDateController.text);
    if (start == null || end == null) return false;
    final targetEnd = LoanCalculatorHelper.addMonths(start, months);
    return targetEnd.year == end.year &&
        targetEnd.month == end.month &&
        targetEnd.day == end.day;
  }

  Widget _quickMonthChip(int months) {
    final isSelected = _isQuickMonthActive(months);
    return InkWell(
      onTap: () => _setQuickMonths(months),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$months လ',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _breakdownLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _openRecordsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordsScreen(
          onEditRecord: (r) => _loadRecord(r),
          drawerBuilder: (ctx, onRefresh) => _buildSidebarDrawer(
            ctx,
            isOnRecordsScreen: true,
            onRecordsChanged: onRefresh,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDrawer(
    BuildContext context, {
    bool isOnRecordsScreen = false,
    VoidCallback? onRecordsChanged,
  }) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1527),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF131D30),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E2B43), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _storeSubtitle,
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sidebar Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                children: [
                  _sidebarItem(
                    icon: Icons.history,
                    title: 'သိမ်းထားသော စာရင်း',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (isOnRecordsScreen) {
                        onRecordsChanged?.call();
                      } else {
                        _openRecordsScreen();
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.analytics_outlined,
                    title: 'ချေးငွေ စာရင်းချုပ်',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => LoanSummaryDialog(
                          onViewAllRecords: () {
                            if (isOnRecordsScreen) {
                              onRecordsChanged?.call();
                            } else {
                              _openRecordsScreen();
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.drive_file_rename_outline,
                    title: 'အမည်ပြောင်းရန်',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => ChangeNameDialog(
                          onUpdated: () async {
                            final info = await StorageService.getStoreInfo();
                            if (mounted) {
                              setState(() {
                                _storeName = info['name'] ?? 'ပညာရေး အလှူငွေ';
                                _storeSubtitle =
                                    info['subtitle'] ??
                                    'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.lock_reset,
                    title: 'Password ပြောင်းရန်',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.phonelink_setup,
                    title: 'Device Code ယူရန်',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const DeviceCodeDialog(),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Activation ပြုလုပ်ရန်',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const ActivationDialog(),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.import_export,
                    title: 'Import / Export .vcf',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => VcfImportExportDialog(
                          onRecordsImported: () async {
                            final nextCode =
                                await StorageService.getNextCodeNumber();
                            if (mounted) {
                              setState(() {
                                _codeNoController.text = nextCode;
                              });
                            }
                            onRecordsChanged?.call();
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _sidebarItem(
                    icon: Icons.info_outline_rounded,
                    title: 'App Info',
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const AppInfoDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Lock Action in Sidebar
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: _sidebarItem(
                icon: Icons.lock_outline,
                title: 'App Lock ချမည်',
                iconColor: const Color(0xFFEF4444),
                borderColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  widget.onLockApp();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFF59E0B),
    Color borderColor = const Color(0xFF1E2B43),
  }) {
    return Material(
      color: const Color(0xFF131D30),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
