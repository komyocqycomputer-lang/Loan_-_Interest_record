import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan_record.dart';

class StorageService {
  static const String _recordsKey = 'kyn_store_loan_records_v1';
  static const String _recordsInitializedKey =
      'kyn_store_loan_records_init_v1';
  static const String _storeNameKey = 'kyn_store_name_v2';
  static const String _storeSubtitleKey = 'kyn_store_subtitle_v2';
  static const String _pinKey = 'kyn_store_pin_v1';
  static const String _pinEnabledKey = 'kyn_store_pin_enabled_v1';
  static const String _deviceCodeKey = 'kyn_store_drm_device_id_v1';
  static const String _isActivatedKey = 'kyn_store_activated_v1';
  static const String _activationExpiryKey = 'kyn_store_activation_expiry_v1';
  static const String _activationPlanKey = 'kyn_store_activation_plan_v1';
  static const String _freeTrialInitializedKey =
      'kyn_store_free_trial_init_v1';
  static const String _usedActivationKeysKey =
      'kyn_store_used_activation_keys_v1';
  static const MethodChannel _drmChannel = MethodChannel(
    'com.kynstore.loan_calculator/device_drm',
  );

  static File _getRecordsMirrorBackupFile() {
    final dir = Directory('${Directory.systemTemp.parent.path}/files');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/loan_records_backup_mirror.json');
  }

  static List<LoanRecord>? _parseRecordsJsonSafely(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! List) return null;
      final List<LoanRecord> result = [];
      for (final item in decoded) {
        if (item is Map) {
          try {
            result.add(LoanRecord.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip only a corrupted item, never wipe the entire list
          }
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<List<LoanRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordsKey);

    // 1. Try reading from SharedPreferences first
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final parsed = _parseRecordsJsonSafely(jsonStr);
      if (parsed != null) {
        return parsed;
      }
    }

    // 2. Try recovering from permanent local mirror file so records are never lost
    try {
      final mirrorFile = _getRecordsMirrorBackupFile();
      if (mirrorFile.existsSync()) {
        final mirrorStr = await mirrorFile.readAsString(encoding: utf8);
        if (mirrorStr.trim().isNotEmpty) {
          final recovered = _parseRecordsJsonSafely(mirrorStr);
          if (recovered != null) {
            await prefs.setString(_recordsKey, mirrorStr);
            await prefs.setBool(_recordsInitializedKey, true);
            return recovered;
          }
        }
      }
    } catch (_) {}

    return <LoanRecord>[];
  }

  static Future<void> saveAllRecords(List<LoanRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_recordsKey, encoded);
    await prefs.setBool(_recordsInitializedKey, true);
    try {
      final mirrorFile = _getRecordsMirrorBackupFile();
      await mirrorFile.writeAsString(encoded, encoding: utf8, flush: true);
    } catch (_) {}
  }

  static Future<String?> _ensurePermanentPhotoPath(
    String? rawPath,
    String codeNo,
  ) async {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final srcFile = File(rawPath);
    if (!srcFile.existsSync()) return null;

    try {
      final permanentDir = Directory(
        '${Directory.systemTemp.parent.path}/files/loan_photos',
      );
      if (!permanentDir.existsSync()) {
        await permanentDir.create(recursive: true);
      }
      if (rawPath.startsWith(permanentDir.path)) {
        return rawPath;
      }
      final safeCode = codeNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final destPath =
          '${permanentDir.path}/photo_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.png';
      final copied = await srcFile.copy(destPath);
      return copied.path;
    } catch (_) {
      return rawPath;
    }
  }

  static Future<void> saveRecord(LoanRecord record) async {
    final permanentPhoto = await _ensurePermanentPhotoPath(
      record.photoPath,
      record.codeNo,
    );
    final updatedRecord = LoanRecord(
      id: record.id,
      codeNo: record.codeNo,
      name: record.name,
      address: record.address,
      phone1: record.phone1,
      phone2: record.phone2,
      loanAmount: record.loanAmount,
      monthlyInterestRate: record.monthlyInterestRate,
      startDate: record.startDate,
      endDate: record.endDate,
      durationText: record.durationText,
      durationMonths: record.durationMonths,
      totalInterest: record.totalInterest,
      totalAmountDue: record.totalAmountDue,
      photoPath: permanentPhoto,
      guarantee: record.guarantee,
      notes: record.notes,
      createdAt: record.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final records = await getRecords();
    final index = records.indexWhere(
      (r) => r.id == updatedRecord.id || r.codeNo == updatedRecord.codeNo,
    );
    if (index >= 0) {
      records[index] = updatedRecord;
    } else {
      records.insert(0, updatedRecord);
    }
    await saveAllRecords(records);
  }

  static Future<void> deleteRecord(String id) async {
    final records = await getRecords();
    records.removeWhere((r) => r.id == id);
    await saveAllRecords(records);
  }

  static Future<String> getNextCodeNumber() async {
    final records = await getRecords();
    var maxNum = 0;
    for (final r in records) {
      final match = RegExp(r'\d+').firstMatch(r.codeNo);
      if (match != null) {
        final n = int.tryParse(match.group(0) ?? '');
        if (n != null && n > maxNum) {
          maxNum = n;
        }
      }
    }
    final next = maxNum + 1;
    return next.toString().padLeft(3, '0');
  }

  static Future<Map<String, String>> getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_storeNameKey) ?? 'ပညာရေး အလှူငွေ';
    final subtitle = prefs.getString(_storeSubtitleKey) ?? 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';
    return {'name': name, 'subtitle': subtitle};
  }

  static Future<void> saveStoreInfo(String name, String subtitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeNameKey, name);
    await prefs.setString(_storeSubtitleKey, subtitle);
  }

  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? '1234';
  }

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? true;
  }

  static Future<void> setPinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, enabled);
  }

  static Future<String> getDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final drmId = await _drmChannel.invokeMethod<String>('getDrmDeviceId');
      if (drmId != null && drmId.trim().isNotEmpty) {
        final formatted = drmId.trim().toUpperCase();
        await prefs.setString(_deviceCodeKey, formatted);
        return formatted;
      }
    } catch (_) {
      // Fallback if hot-reloaded before native MethodChannel rebuild
    }

    var saved = prefs.getString(_deviceCodeKey);
    if (saved == null || saved.isEmpty || saved.startsWith('LC-')) {
      const hexChars = '0123456789ABCDEF';
      final rnd = Random();
      String block() =>
          List.generate(4, (_) => hexChars[rnd.nextInt(hexChars.length)]).join();
      saved = '${block()}-${block()}-${block()}-${block()}';
      await prefs.setString(_deviceCodeKey, saved);
    }
    return saved;
  }

  static String generateRandomNonce() {
    const hexChars = '0123456789ABCDEF';
    final rnd = Random.secure();
    return '${hexChars[rnd.nextInt(16)]}${hexChars[rnd.nextInt(16)]}';
  }

  static String _generateLegacyKeyForDevice(
    String deviceCode, {
    int durationDays = 0,
  }) {
    final cleaned = deviceCode
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty) return '';

    final String planCode = durationDays <= 0
        ? 'LIFE'
        : 'D${durationDays.toString().padLeft(3, '0')}';
    final String payload = '$cleaned|$planCode';

    int hash1 = 0x5A3C;
    int hash2 = 0x9E71;
    for (int i = 0; i < payload.length; i++) {
      final c = payload.codeUnitAt(i);
      hash1 = ((hash1 * 33) ^ c) & 0xFFFF;
      hash2 = ((hash2 * 37) + (c * (i + 1))) & 0xFFFF;
    }
    final part1 = hash1.toRadixString(16).toUpperCase().padLeft(4, '0');
    final part2 = hash2.toRadixString(16).toUpperCase().padLeft(4, '0');
    return 'ACT-$planCode-$part1-$part2';
  }

  static String generateKeyForDevice(
    String deviceCode, {
    int durationDays = 0, // 0 = Life Time, 3 = 3 ရက်, 30 = 30 ရက်, 365 = 365 ရက်
    String? nonce,
  }) {
    final cleaned = deviceCode
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty) return '';

    final String cleanNonce =
        (nonce != null && RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(nonce))
        ? nonce.toUpperCase()
        : generateRandomNonce();

    final String planCode = durationDays <= 0
        ? 'LIFE'
        : 'D${durationDays.toString().padLeft(3, '0')}';
    final String payload = '$cleaned|$planCode|$cleanNonce';

    int hash1 = 0x5A3C;
    int hash2 = 0x9E71;
    for (int i = 0; i < payload.length; i++) {
      final c = payload.codeUnitAt(i);
      hash1 = ((hash1 * 33) ^ c) & 0xFFFF;
      hash2 = ((hash2 * 37) + (c * (i + 1))) & 0xFFFF;
    }
    final sigByte = (hash1 ^ (hash1 >> 8)) & 0xFF;
    final sigHex = sigByte.toRadixString(16).toUpperCase().padLeft(2, '0');
    final part1 = '$cleanNonce$sigHex';
    final part2 = hash2.toRadixString(16).toUpperCase().padLeft(4, '0');
    return 'ACT-$planCode-$part1-$part2';
  }

  static File _getUsedKeysBackupFile() {
    final dir = Directory('${Directory.systemTemp.parent.path}/files');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/.used_activation_keys.json');
  }

  static Future<Set<String>> getUsedActivationKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> used = {
      ...(prefs.getStringList(_usedActivationKeysKey) ?? const <String>[]),
    };
    try {
      final file = _getUsedKeysBackupFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item != null && item.toString().isNotEmpty) {
              used.add(item.toString());
            }
          }
        }
      }
    } catch (_) {}
    return used;
  }

  static Future<void> _markActivationKeyAsUsed(String normalizedKey) async {
    final used = await getUsedActivationKeys();
    used.add(normalizedKey);
    final list = used.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_usedActivationKeysKey, list);
    try {
      final file = _getUsedKeysBackupFile();
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (_) {}
  }

  static File _getActivationStateMirrorFile() {
    final dir = Directory('${Directory.systemTemp.parent.path}/files');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/.activation_state_mirror.json');
  }

  static Future<void> _saveActivationMirror({
    required bool activated,
    required int expiryMs,
    required String plan,
  }) async {
    try {
      final file = _getActivationStateMirrorFile();
      await file.writeAsString(
        jsonEncode({
          'trialInit': true,
          'activated': activated,
          'expiryMs': expiryMs,
          'plan': plan,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  static Future<void> ensureFreeTrialInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyInit = prefs.getBool(_freeTrialInitializedKey) ?? false;
    final hasExistingActivation = prefs.containsKey(_isActivatedKey) ||
        prefs.containsKey(_activationExpiryKey);

    if (alreadyInit) return;

    if (hasExistingActivation) {
      await prefs.setBool(_freeTrialInitializedKey, true);
      await _saveActivationMirror(
        activated: prefs.getBool(_isActivatedKey) ?? false,
        expiryMs: prefs.getInt(_activationExpiryKey) ?? 0,
        plan: prefs.getString(_activationPlanKey) ?? '',
      );
      return;
    }

    // Check mirror file in case SharedPreferences was cleared
    try {
      final file = _getActivationStateMirrorFile();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final map = jsonDecode(raw);
        if (map is Map && map['trialInit'] == true) {
          final bool act = map['activated'] == true;
          final int exp = (map['expiryMs'] is int) ? map['expiryMs'] as int : 0;
          final String pl = (map['plan'] ?? 'Free 7 ရက်').toString();
          await prefs.setBool(_freeTrialInitializedKey, true);
          await prefs.setBool(_isActivatedKey, act);
          await prefs.setInt(_activationExpiryKey, exp);
          await prefs.setString(_activationPlanKey, pl);
          return;
        }
      }
    } catch (_) {}

    // First-time install: grant Free 7-day trial automatically
    final expiry = DateTime.now()
        .add(const Duration(days: 7))
        .millisecondsSinceEpoch;
    const planLabel = 'Free 7 ရက်';
    await prefs.setBool(_freeTrialInitializedKey, true);
    await prefs.setBool(_isActivatedKey, true);
    await prefs.setInt(_activationExpiryKey, expiry);
    await prefs.setString(_activationPlanKey, planLabel);
    await _saveActivationMirror(
      activated: true,
      expiryMs: expiry,
      plan: planLabel,
    );
  }

  static Future<bool> isActivated() async {
    await ensureFreeTrialInitialized();
    final prefs = await SharedPreferences.getInstance();
    final activated = prefs.getBool(_isActivatedKey) ?? false;
    if (!activated) return false;

    final expiryMs = prefs.getInt(_activationExpiryKey) ?? 0;
    if (expiryMs > 0 && DateTime.now().millisecondsSinceEpoch > expiryMs) {
      await prefs.setBool(_isActivatedKey, false);
      await _saveActivationMirror(
        activated: false,
        expiryMs: expiryMs,
        plan: prefs.getString(_activationPlanKey) ?? 'Free 7 ရက်',
      );
      return false;
    }
    return true;
  }

  static Future<String> getActivationStatusText() async {
    final prefs = await SharedPreferences.getInstance();
    final activated = await isActivated();
    final expiryMs = prefs.getInt(_activationExpiryKey) ?? 0;
    final plan = prefs.getString(_activationPlanKey) ?? '';

    if (!activated) {
      if (expiryMs > 0 && DateTime.now().millisecondsSinceEpoch > expiryMs) {
        return 'သက်တမ်းကုန်ဆုံးသွားပါပြီ ($plan)';
      }
      return 'Not Activated';
    }

    if (expiryMs <= 0) {
      return 'Activated (Life Time)';
    }

    final diffMs = expiryMs - DateTime.now().millisecondsSinceEpoch;
    final remainingDays = (diffMs / (1000 * 60 * 60 * 24)).ceil();
    return 'Activated ($plan - $remainingDays ရက် ကျန်)';
  }

  /// Returns `'SUCCESS'`, `'USED'`, or `'INVALID'`.
  static Future<String> activateWithKeyDetailed(String inputKey) async {
    final deviceCode = await getDeviceCode();
    final normalizedInput = inputKey
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalizedInput.isEmpty) return 'INVALID';

    // 1. Block any activation key that has already been used
    final usedKeys = await getUsedActivationKeys();
    if (usedKeys.contains(normalizedInput)) {
      return 'USED';
    }

    final candidateDays = <int>{3, 30, 365, 0};
    final customMatch = RegExp(
      r'^ACTD0*([1-9][0-9]*)[0-9A-F]{8}$',
    ).firstMatch(normalizedInput);
    if (customMatch != null) {
      final parsed = int.tryParse(customMatch.group(1)!);
      if (parsed != null && parsed > 0) {
        candidateDays.add(parsed);
      }
    }

    // Extract the 2-hex-char nonce from the start of the 8-hex-char signature block
    final String? inputNonce = normalizedInput.length >= 8
        ? normalizedInput.substring(
            normalizedInput.length - 8,
            normalizedInput.length - 6,
          )
        : null;

    for (final days in candidateDays) {
      final label = days <= 0 ? 'Life Time' : '$days ရက်';

      final expectedSalted = inputNonce != null
          ? generateKeyForDevice(
              deviceCode,
              durationDays: days,
              nonce: inputNonce,
            )
                .trim()
                .toUpperCase()
                .replaceAll(RegExp(r'[^A-Z0-9]'), '')
          : '';

      final expectedLegacy = _generateLegacyKeyForDevice(
        deviceCode,
        durationDays: days,
      ).trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

      if ((expectedSalted.isNotEmpty && normalizedInput == expectedSalted) ||
          normalizedInput == expectedLegacy) {
        await _markActivationKeyAsUsed(normalizedInput);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_freeTrialInitializedKey, true);
        await prefs.setBool(_isActivatedKey, true);
        await prefs.setString(_activationPlanKey, label);
        int savedExpiry = 0;
        if (days <= 0) {
          await prefs.setInt(_activationExpiryKey, 0);
        } else {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final currentExpiryMs = prefs.getInt(_activationExpiryKey) ?? 0;
          final baseMs =
              (currentExpiryMs > nowMs) ? currentExpiryMs : nowMs;
          savedExpiry = DateTime.fromMillisecondsSinceEpoch(baseMs)
              .add(Duration(days: days))
              .millisecondsSinceEpoch;
          await prefs.setInt(_activationExpiryKey, savedExpiry);
        }
        await _saveActivationMirror(
          activated: true,
          expiryMs: savedExpiry,
          plan: label,
        );
        return 'SUCCESS';
      }
    }

    return 'INVALID';
  }

  static Future<bool> activateWithKey(String inputKey) async {
    final res = await activateWithKeyDetailed(inputKey);
    return res == 'SUCCESS';
  }

  static const MethodChannel _printerStorageChannel = MethodChannel(
    'com.kynstore.loan_calculator/printer',
  );

  static Future<bool> openExternalUri(
    String uri, {
    String fallbackUri = '',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _printerStorageChannel.invokeMethod<bool>(
        'openExternalUri',
        {
          'uri': uri,
          'fallbackUri': fallbackUri,
        },
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Streams all records (including embedded base64 photos so 1,000+ records never lose photos)
  /// into a temporary .vcf file and copies it directly to Phone Internal Storage root (`/storage/emulated/0/<fileName>`).
  static Future<String> exportVcfToInternalStorage({
    String fileName = 'loan_records_backup.vcf',
  }) async {
    final records = await getRecords();
    final tempDir = Directory('${Directory.systemTemp.parent.path}/files');
    if (!tempDir.existsSync()) {
      await tempDir.create(recursive: true);
    }
    final tempFile = File('${tempDir.path}/temp_export_backup.vcf');
    final sink = tempFile.openWrite(encoding: utf8);

    try {
      for (final r in records) {
        sink.writeln('BEGIN:VCARD');
        sink.writeln('VERSION:3.0');
        sink.writeln('FN:${r.name}');
        if (r.phone1.isNotEmpty) {
          sink.writeln('TEL;TYPE=CELL:${r.phone1}');
        }
        if (r.address.isNotEmpty) {
          sink.writeln('ADR;TYPE=HOME:;;${r.address};;;;');
        }
        if (r.photoPath != null && r.photoPath!.isNotEmpty) {
          final photoFile = File(r.photoPath!);
          if (photoFile.existsSync()) {
            try {
              final bytes = await photoFile.readAsBytes();
              final b64 = base64Encode(bytes);
              sink.writeln('PHOTO;ENCODING=b;TYPE=PNG:$b64');
            } catch (_) {}
          }
        }
        final noteJson = jsonEncode(r.toJson());
        sink.writeln('NOTE:$noteJson');
        sink.writeln('END:VCARD');
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (Platform.isAndroid) {
      final cleanName = fileName.split(RegExp(r'[/\\]')).last;
      final savedPath = await _printerStorageChannel.invokeMethod<String>(
        'saveVcfToInternalStorage',
        {
          'tempFilePath': tempFile.path,
          'fileName': cleanName.isNotEmpty
              ? cleanName
              : 'loan_records_backup.vcf',
        },
      );
      return savedPath ?? '/storage/emulated/0/loan_records_backup.vcf';
    } else {
      return tempFile.path;
    }
  }

  static Future<Map<String, String>?> pickVcfFile() async {
    if (!Platform.isAndroid) return null;
    final res = await _printerStorageChannel
        .invokeMethod<Map<dynamic, dynamic>>('pickVcfFile');
    if (res == null) return null;
    return {
      'displayPath': (res['displayPath'] ?? '').toString(),
      'localPath': (res['localPath'] ?? '').toString(),
    };
  }

  /// Streams a .vcf file line-by-line so even 1,000+ records with photos import smoothly
  /// without memory limits, restoring every photo to permanent storage.
  static Future<int> importFromVcfFile(File vcfFile) async {
    if (!await vcfFile.exists()) {
      throw Exception('ဖိုင်မတွေ့ပါ (${vcfFile.path})');
    }

    final existing = await getRecords();
    final Map<String, int> indexById = {};
    final Map<String, int> indexByCode = {};
    for (int i = 0; i < existing.length; i++) {
      indexById[existing[i].id] = i;
      indexByCode[existing[i].codeNo] = i;
    }

    final permanentPhotosDir = Directory(
      '${Directory.systemTemp.parent.path}/files/loan_photos',
    );
    if (!permanentPhotosDir.existsSync()) {
      await permanentPhotosDir.create(recursive: true);
    }

    int importedCount = 0;
    bool inVcard = false;
    String? fnLine;
    String? telLine;
    String? adrLine;
    String? noteLine;
    StringBuffer? photoBase64Buffer;
    bool readingPhotoContinuation = false;

    Future<void> processVcard() async {
      final String? photoB64 = photoBase64Buffer?.toString().trim();
      String? restoredPhotoPath;

      Future<String?> savePhotoBytes(String codeHint) async {
        if (photoB64 == null || photoB64.isEmpty) return null;
        try {
          final bytes = base64Decode(photoB64.replaceAll(RegExp(r'\s+'), ''));
          final safeCode = codeHint.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
          final dest = File(
            '${permanentPhotosDir.path}/photo_${safeCode}_${DateTime.now().microsecondsSinceEpoch}.png',
          );
          await dest.writeAsBytes(bytes, flush: true);
          return dest.path;
        } catch (_) {
          return null;
        }
      }

      if (noteLine != null) {
        final noteStr = noteLine.trim();
        if (noteStr.startsWith('{') && noteStr.endsWith('}')) {
          try {
            final Map<String, dynamic> map = jsonDecode(noteStr);
            var rec = LoanRecord.fromJson(map);
            restoredPhotoPath = await savePhotoBytes(rec.codeNo);
            if (restoredPhotoPath != null) {
              rec = rec.copyWith(photoPath: restoredPhotoPath);
            } else if (rec.photoPath != null &&
                rec.photoPath!.isNotEmpty &&
                !File(rec.photoPath!).existsSync()) {
              rec = LoanRecord(
                id: rec.id,
                codeNo: rec.codeNo,
                name: rec.name,
                address: rec.address,
                phone1: rec.phone1,
                phone2: rec.phone2,
                loanAmount: rec.loanAmount,
                monthlyInterestRate: rec.monthlyInterestRate,
                startDate: rec.startDate,
                endDate: rec.endDate,
                durationText: rec.durationText,
                durationMonths: rec.durationMonths,
                totalInterest: rec.totalInterest,
                totalAmountDue: rec.totalAmountDue,
                photoPath: null,
                guarantee: rec.guarantee,
                notes: rec.notes,
                createdAt: rec.createdAt,
                updatedAt: rec.updatedAt,
              );
            }

            final int? existingIdx =
                indexById[rec.id] ?? indexByCode[rec.codeNo];
            if (existingIdx != null &&
                existingIdx >= 0 &&
                existingIdx < existing.length) {
              existing[existingIdx] = rec;
            } else {
              existing.insert(0, rec);
              // Rebuild quick lookup indices
              indexById.clear();
              indexByCode.clear();
              for (int i = 0; i < existing.length; i++) {
                indexById[existing[i].id] = i;
                indexByCode[existing[i].codeNo] = i;
              }
            }
            importedCount++;
            return;
          } catch (_) {}
        }
      }

      final name = fnLine?.trim() ?? '';
      if (name.isEmpty) return;
      final phone = telLine?.trim() ?? '';
      final address = (adrLine ?? '').replaceAll(';', ' ').trim();

      var maxNum = 0;
      for (final r in existing) {
        final m = RegExp(r'\d+').firstMatch(r.codeNo);
        if (m != null) {
          final n = int.tryParse(m.group(0) ?? '');
          if (n != null && n > maxNum) maxNum = n;
        }
      }
      final nextCode = (maxNum + 1).toString().padLeft(3, '0');
      restoredPhotoPath = await savePhotoBytes(nextCode);

      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final newRec = LoanRecord(
        id: 'rec-${now.millisecondsSinceEpoch}-$importedCount',
        codeNo: nextCode,
        name: name,
        address: address,
        phone1: phone,
        phone2: '',
        loanAmount: 100000,
        monthlyInterestRate: 2.0,
        startDate: dateStr,
        endDate: dateStr,
        durationText: '0 ရက်',
        durationMonths: 0,
        totalInterest: 0,
        totalAmountDue: 100000,
        photoPath: restoredPhotoPath,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );
      existing.insert(0, newRec);
      indexById[newRec.id] = 0;
      indexByCode[newRec.codeNo] = 0;
      importedCount++;
    }

    final stream = vcfFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in stream) {
      final line = rawLine.trimRight();
      final upper = line.toUpperCase();

      if (upper == 'BEGIN:VCARD') {
        inVcard = true;
        fnLine = null;
        telLine = null;
        adrLine = null;
        noteLine = null;
        photoBase64Buffer = null;
        readingPhotoContinuation = false;
        continue;
      }

      if (!inVcard) continue;

      if (upper == 'END:VCARD') {
        await processVcard();
        inVcard = false;
        readingPhotoContinuation = false;
        photoBase64Buffer = null;
        continue;
      }

      if (readingPhotoContinuation) {
        if (rawLine.startsWith(' ') || rawLine.startsWith('\t')) {
          photoBase64Buffer?.write(rawLine.trim());
          continue;
        } else {
          readingPhotoContinuation = false;
        }
      }

      if (upper.startsWith('PHOTO')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx >= 0) {
          photoBase64Buffer = StringBuffer(line.substring(colonIdx + 1).trim());
          readingPhotoContinuation = true;
        }
      } else if (upper.startsWith('NOTE:')) {
        noteLine = line.substring(5);
      } else if (upper.startsWith('FN:')) {
        fnLine = line.substring(3);
      } else if (upper.startsWith('TEL')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx >= 0) {
          telLine = line.substring(colonIdx + 1);
        }
      } else if (upper.startsWith('ADR')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx >= 0) {
          adrLine = line.substring(colonIdx + 1);
        }
      }
    }

    if (importedCount > 0) {
      await saveAllRecords(existing);
    }
    return importedCount;
  }
}
