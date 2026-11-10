import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String _targetPin = '1234';
  String _storeName = 'ပညာရေး အလှူငွေ';
  String _storeSubtitle = 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final pin = await StorageService.getPin();
    final info = await StorageService.getStoreInfo();
    setState(() {
      _targetPin = pin;
      _storeName = info['name'] ?? 'ပညာရေး အလှူငွေ';
      _storeSubtitle = info['subtitle'] ?? 'ရွှေကျင်ကျေးရွာ၊ ဝက်လက်မြို့နယ်။';
    });
  }

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      final next = _pin + digit;
      setState(() {
        _pin = next;
        _errorMessage = '';
      });

      if (next.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (next == _targetPin) {
            widget.onUnlocked();
          } else {
            setState(() {
              _errorMessage = 'PIN ကုဒ် မှားယွင်းနေပါသည်။';
              _pin = '';
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1527),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Store Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Store Title
                Text(
                  _storeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  _storeSubtitle,
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Prompt
                Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : 'အသုံးပြုရန် PIN ကုဒ် (၄) လုံး ရိုက်ထည့်ပါ',
                  style: TextStyle(
                    color: _errorMessage.isNotEmpty
                        ? Colors.redAccent
                        : const Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: _errorMessage.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 24),

                // 4 PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? const Color(0xFFF59E0B) : Colors.transparent,
                        border: Border.all(
                          color: isFilled
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF334155),
                          width: 2.2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 36),

                // Keypad
                Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _numpadBtn('1'),
                          _numpadBtn('2'),
                          _numpadBtn('3'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _numpadBtn('4'),
                          _numpadBtn('5'),
                          _numpadBtn('6'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _numpadBtn('7'),
                          _numpadBtn('8'),
                          _numpadBtn('9'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _actionBtn(
                            label: 'ဖျက်',
                            onTap: _onClear,
                          ),
                          _numpadBtn('0'),
                          _actionBtn(
                            icon: Icons.backspace_outlined,
                            onTap: _onBackspace,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Default PIN Hint
                Text(
                  'မူရင်း PIN: $_targetPin',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numpadBtn(String text) {
    return InkWell(
      onTap: () => _onKeyPress(text),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF283852), width: 1.2),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({String? label, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF151F33),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(
                  icon,
                  color: const Color(0xFF94A3B8),
                  size: 22,
                ),
        ),
      ),
    );
  }
}
