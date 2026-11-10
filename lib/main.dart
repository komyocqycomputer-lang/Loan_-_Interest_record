import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'dialogs/pin_lock_dialog.dart';
import 'dialogs/sidebar_dialogs.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1527),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LoanCalculatorApp());
}

class LoanCalculatorApp extends StatefulWidget {
  const LoanCalculatorApp({super.key});

  @override
  State<LoanCalculatorApp> createState() => _LoanCalculatorAppState();
}

class _LoanCalculatorAppState extends State<LoanCalculatorApp>
    with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _isActivated = true;
  bool _isCheckingPin = true;
  Timer? _expiryCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLockState();
    _expiryCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshActivationStatus(),
    );
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshActivationStatus();
    }
  }

  Future<void> _refreshActivationStatus() async {
    final activated = await StorageService.isActivated();
    if (mounted && _isActivated != activated) {
      setState(() {
        _isActivated = activated;
      });
    }
  }

  Future<void> _checkInitialLockState() async {
    final isPinEnabled = await StorageService.isPinEnabled();
    final isActivated = await StorageService.isActivated();
    if (!mounted) return;
    setState(() {
      _isLocked = isPinEnabled;
      _isActivated = isActivated;
      _isCheckingPin = false;
    });
  }

  Future<void> _unlockApp() async {
    final isActivated = await StorageService.isActivated();
    if (!mounted) return;
    setState(() {
      _isLocked = false;
      _isActivated = isActivated;
    });
  }

  void _lockApp() {
    setState(() {
      _isLocked = true;
    });
  }

  void _onActivated() {
    setState(() {
      _isActivated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0D1527);
    const primaryAmber = Color(0xFFF59E0B);

    return MaterialApp(
      title: 'ပညာရေး အလှူငွေ (တိုးရင်း စာရင်း)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDark,
        primaryColor: primaryAmber,
        colorScheme: const ColorScheme.dark(
          primary: primaryAmber,
          surface: Color(0xFF131D30),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
        ),
      ),
      home: _isCheckingPin
          ? const Scaffold(
              backgroundColor: bgDark,
              body: Center(
                child: CircularProgressIndicator(color: primaryAmber),
              ),
            )
          : _isLocked
              ? PinLockScreen(onUnlocked: _unlockApp)
              : !_isActivated
                  ? Scaffold(
                      backgroundColor: bgDark,
                      body: SafeArea(
                        child: Center(
                          child: ActivationDialog(
                            isLockScreen: true,
                            onActivated: _onActivated,
                          ),
                        ),
                      ),
                    )
                  : HomeScreen(onLockApp: _lockApp),
    );
  }
}
