import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPrinterDevice {
  final String name;
  final String address;
  final bool isPrinter;

  const BluetoothPrinterDevice({
    required this.name,
    required this.address,
    this.isPrinter = false,
  });
}

class PrinterService {
  static const MethodChannel _channel = MethodChannel(
    'com.kynstore.loan_calculator/printer',
  );

  static const String _savedBtAddressKey = 'saved_bt_printer_address';
  static const String _savedBtNameKey = 'saved_bt_printer_name';
  static const String _savedWifiIpKey = 'saved_wifi_printer_ip';
  static const String _savedWifiPortKey = 'saved_wifi_printer_port';
  static const String _savedPaperSizeKey = 'saved_printer_paper_size';

  static Future<Map<String, String>> getSavedPrinterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'btAddress': prefs.getString(_savedBtAddressKey) ?? '',
      'btName': prefs.getString(_savedBtNameKey) ?? '',
      'wifiIp': prefs.getString(_savedWifiIpKey) ?? '192.168.1.100',
      'wifiPort': (prefs.getInt(_savedWifiPortKey) ?? 9100).toString(),
      'paperSize': prefs.getString(_savedPaperSizeKey) ?? '80mm',
    };
  }

  static Future<void> savePaperSize(String paperSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPaperSizeKey, paperSize);
  }

  static Future<void> saveSelectedBluetoothPrinter(
    String name,
    String address,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedBtNameKey, name);
    await prefs.setString(_savedBtAddressKey, address);
  }

  static Future<void> clearSavedBluetoothPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedBtNameKey);
    await prefs.remove(_savedBtAddressKey);
  }

  static Future<void> saveWifiPrinter(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedWifiIpKey, ip.trim());
    await prefs.setInt(_savedWifiPortKey, port);
  }

  static Future<bool> ensureBluetoothPermissions() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'ensureBluetoothPermissions',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothPrinterDevice>> getPairedBluetoothDevices() async {
    final hasPerm = await ensureBluetoothPermissions();
    if (!hasPerm) {
      throw Exception('Bluetooth ခွင့်ပြုချက် (Permission) မရရှိပါ');
    }
    final rawList = await _channel.invokeMethod<List<dynamic>>(
      'getPairedBluetoothDevices',
    );
    if (rawList == null) return [];
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return BluetoothPrinterDevice(
        name: (map['name'] ?? 'Bluetooth Printer').toString(),
        address: (map['address'] ?? '').toString(),
        isPrinter: map['isPrinter'] == true,
      );
    }).toList();
  }

  static Future<Map<String, String>> printViaBluetooth({
    required Uint8List escPosBytes,
    String? address,
  }) async {
    final hasPerm = await ensureBluetoothPermissions();
    if (!hasPerm) {
      throw Exception('Bluetooth ခွင့်ပြုချက် လိုအပ်ပါသည်');
    }
    final prefs = await SharedPreferences.getInstance();
    final targetAddress =
        (address != null && address.trim().isNotEmpty)
        ? address.trim()
        : (prefs.getString(_savedBtAddressKey) ?? '');

    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'printBluetoothEscPos',
      {
        'address': targetAddress,
        'bytes': escPosBytes,
      },
    );

    final devName = (res?['name'] ?? 'Bluetooth Printer').toString();
    final devAddr = (res?['address'] ?? targetAddress).toString();
    if (devAddr.isNotEmpty) {
      await saveSelectedBluetoothPrinter(devName, devAddr);
    }
    return {'name': devName, 'address': devAddr};
  }

  static Future<void> printViaNetwork({
    required String host,
    required int port,
    required Uint8List escPosBytes,
  }) async {
    await saveWifiPrinter(host, port);
    await _channel.invokeMethod('printNetworkEscPos', {
      'host': host.trim(),
      'port': port,
      'bytes': escPosBytes,
    });
  }

  static Future<String> printViaUsb({
    required Uint8List escPosBytes,
  }) async {
    final name = await _channel.invokeMethod<String>('printUsbEscPos', {
      'bytes': escPosBytes,
    });
    return name ?? 'USB Printer';
  }

  static Future<void> printViaSystemService({
    required Uint8List pngBytes,
    required String jobName,
  }) async {
    await _channel.invokeMethod('printSystemBitmap', {
      'pngBytes': pngBytes,
      'jobName': jobName,
    });
  }

  static Future<void> printViaRawBt({
    required Uint8List pngBytes,
  }) async {
    final b64 = base64Encode(pngBytes);
    await _channel.invokeMethod('openRawBt', {
      'base64Png': b64,
    });
  }

  static Future<String> saveReceiptToGallery({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    final savedPath = await _channel.invokeMethod<String>(
      'saveReceiptToGallery',
      {
        'pngBytes': pngBytes,
        'fileName': fileName,
      },
    );
    return savedPath ?? fileName;
  }

  /// Converts a rendered Flutter [ui.Image] into ESC/POS Raster Bit Image (GS v 0) bytes
  /// in 256-line horizontal strips for 100% compatibility with all 80mm (576 dots) & 58mm (384 dots) thermal printers.
  static Future<Uint8List> convertImageToEscPosRaster(
    ui.Image image, {
    bool is58mm = false,
  }) async {
    final int width = image.width;
    final int height = image.height;
    final ByteData? rgbaData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (rgbaData == null) {
      throw Exception('Receipt image data could not be encoded');
    }

    final Uint8List pixels = rgbaData.buffer.asUint8List();
    final int widthBytes = (width + 7) ~/ 8;

    // Detect vertical bounds of actual dark pixels so no excess top/bottom blank space is printed
    int firstDarkY = 0;
    int lastDarkY = height - 1;
    bool foundTop = false;

    for (int y = 0; y < height; y++) {
      bool rowHasDark = false;
      for (int x = 0; x < width; x++) {
        final int idx = (y * width + x) * 4;
        final int a = pixels[idx + 3];
        if (a >= 128) {
          final double lum =
              pixels[idx] * 0.299 +
              pixels[idx + 1] * 0.587 +
              pixels[idx + 2] * 0.114;
          if (lum < 125.0) {
            rowHasDark = true;
            break;
          }
        }
      }
      if (rowHasDark) {
        if (!foundTop) {
          firstDarkY = y;
          foundTop = true;
        }
        lastDarkY = y;
      }
    }

    final int cropStartY = foundTop ? (firstDarkY - 4).clamp(0, height - 1) : 0;
    final int cropEndY = foundTop ? (lastDarkY + 28).clamp(1, height) : height;
    final int croppedHeight = cropEndY - cropStartY;

    final BytesBuilder builder = BytesBuilder();
    // Initialize printer: ESC @
    builder.add(const [0x1B, 0x40]);
    // Center align: ESC a 1
    builder.add(const [0x1B, 0x61, 0x01]);

    // Send image in horizontal bands of 24 rows so no Bluetooth printer buffer ever overflows or clips the bottom
    const int bandHeight = 24;
    for (int offsetY = 0; offsetY < croppedHeight; offsetY += bandHeight) {
      final int currentBandH = (offsetY + bandHeight <= croppedHeight)
          ? bandHeight
          : (croppedHeight - offsetY);
      final Uint8List bandBytes = Uint8List(widthBytes * currentBandH);

      for (int y = 0; y < currentBandH; y++) {
        final int srcY = cropStartY + offsetY + y;
        for (int x = 0; x < width; x++) {
          final int idx = (srcY * width + x) * 4;
          final int r = pixels[idx];
          final int g = pixels[idx + 1];
          final int b = pixels[idx + 2];
          final int a = pixels[idx + 3];

          final double luminance =
              a < 128 ? 255.0 : (r * 0.299 + g * 0.587 + b * 0.114);
          // Use 125.0 threshold so anti-aliased gray edges do not bloat or close up Myanmar characters on thermal paper
          if (luminance < 125.0) {
            final int byteIndex = y * widthBytes + (x >> 3);
            bandBytes[byteIndex] |= (0x80 >> (x & 7));
          }
        }
      }

      final int xL = widthBytes & 0xFF;
      final int xH = (widthBytes >> 8) & 0xFF;
      final int yL = currentBandH & 0xFF;
      final int yH = (currentBandH >> 8) & 0xFF;

      // GS v 0 0 xL xH yL yH
      builder.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
      builder.add(bandBytes);
    }

    // Feed 8 compact lines (adds ~0.3" more bottom clearance for easy tearing) + zero-feed partial cut (GS V 1)
    builder.add(const [
      0x0A,
      0x0A,
      0x0A,
      0x0A,
      0x0A,
      0x0A,
      0x0A,
      0x0A,
      0x1D,
      0x56,
      0x01,
    ]);
    return builder.toBytes();
  }
}
