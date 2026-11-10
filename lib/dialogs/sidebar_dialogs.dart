import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../utils/loan_calculator_helper.dart';

// 1. ချေးငွေ စာရင်းချုပ် Dialog
class LoanSummaryDialog extends StatefulWidget {
  final VoidCallback onViewAllRecords;

  const LoanSummaryDialog({super.key, required this.onViewAllRecords});

  @override
  State<LoanSummaryDialog> createState() => _LoanSummaryDialogState();
}

class _LoanSummaryDialogState extends State<LoanSummaryDialog> {
  bool _isLoading = true;
  int _recordCount = 0;
  double _totalPrincipal = 0;
  double _totalInterest = 0;
  double _totalDue = 0;

  @override
  void initState() {
    super.initState();
    _calculateSummary();
  }

  Future<void> _calculateSummary() async {
    setState(() => _isLoading = true);
    final records = await StorageService.getRecords();
    final now = DateTime.now();

    double sumPrincipal = 0;
    double sumInterest = 0;
    double sumDue = 0;

    for (final r in records) {
      sumPrincipal += r.loanAmount;
      final start = LoanCalculatorHelper.parseDMY(r.startDate) ?? now;
      final dur = LoanCalculatorHelper.calculateDuration(start, now);
      final calc = LoanCalculatorHelper.calculateLoan(
        loanAmount: r.loanAmount,
        monthlyRatePercent: r.monthlyInterestRate,
        durationMonths: dur.isValid
            ? dur.totalMonthsFraction
            : r.durationMonths,
      );
      sumInterest += calc.totalInterest;
      sumDue += calc.totalAmountDue;
    }

    if (mounted) {
      setState(() {
        _recordCount = records.length;
        _totalPrincipal = sumPrincipal;
        _totalInterest = sumInterest;
        _totalDue = sumDue;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Color(0xFFF59E0B),
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'ချေးငွေ စာရင်းချုပ်',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          _summaryRow(
                            'စုစုပေါင်း ဦးရေ',
                            '$_recordCount ဦး',
                            const Color(0xFF38BDF8),
                          ),
                          const Divider(color: Color(0xFF1E293B), height: 22),
                          _summaryStackedRow(
                            'ချေးငွေရင်း',
                            '${LoanCalculatorHelper.formatCurrency(_totalPrincipal)} ကျပ်',
                            const Color(0xFFF59E0B),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          const SizedBox(height: 14),
                          _summaryStackedRow(
                            'အတိုးစုစုပေါင်း',
                            '+ ${LoanCalculatorHelper.formatCurrency(_totalInterest)} ကျပ်',
                            const Color(0xFFFBBF24),
                            icon: Icons.trending_up_rounded,
                          ),
                          const SizedBox(height: 14),
                          _summaryStackedRow(
                            'ရင်း/တိုး စုစုပေါင်း',
                            '${LoanCalculatorHelper.formatCurrency(_totalDue)} ကျပ်',
                            const Color(0xFF10B981),
                            icon: Icons.payments_outlined,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: const Text(
                        'စာရင်းအားလုံး ကြည့်ရန်',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onViewAllRecords();
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryStackedRow(
    String label,
    String value,
    Color valueColor, {
    IconData? icon,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: valueColor),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFF1F5F9),
                  fontSize: isBold ? 16 : 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF090F1E),
                valueColor.withValues(alpha: isBold ? 0.22 : 0.14),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: valueColor.withValues(alpha: isBold ? 0.75 : 0.45),
              width: isBold ? 1.5 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: valueColor.withValues(alpha: isBold ? 0.18 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: isBold ? 18.5 : 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 4,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFCBD5E1),
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 6,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: isBold ? 16 : 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 2. အမည်ပြောင်းရန် Dialog
class ChangeNameDialog extends StatefulWidget {
  final VoidCallback onUpdated;

  const ChangeNameDialog({super.key, required this.onUpdated});

  @override
  State<ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends State<ChangeNameDialog> {
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await StorageService.getStoreInfo();
    if (mounted) {
      setState(() {
        _nameController.text = info['name'] ?? 'ပညာရေး အလှူငွေ';
        _subtitleController.text =
            info['subtitle'] ?? 'ရွှေကျင်ရပ်ကွက်၊ ချမ်းသာမြို့နယ်။';
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final sub = _subtitleController.text.trim();
    if (name.isEmpty) return;

    await StorageService.saveStoreInfo(name, sub);
    widget.onUpdated();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('အမည်ပြောင်းလဲသိမ်းဆည်းပြီးပါပြီ'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'အမည်ပြောင်းရန်',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
              const Divider(color: Color(0xFF1E293B), height: 20),
              const Text(
                'ဆိုင်အမည် / ခေါင်းစဉ်',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              _dialogTextField(_nameController, 'ပညာရေး အလှူငွေ'),
              const SizedBox(height: 14),
              const Text(
                'လိပ်စာ / အညွှန်း',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              _dialogTextField(
                _subtitleController,
                'ရွှေကျင်ရပ်ကွက်၊ ချမ်းသာမြို့နယ်။',
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'သိမ်းဆည်းမည်',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Password ပြောင်းရန် Dialog
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String _savedPin = '1234';
  bool _isPinEnabled = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await StorageService.getPin();
    final enabled = await StorageService.isPinEnabled();
    if (mounted) {
      setState(() {
        _savedPin = pin;
        _isPinEnabled = enabled;
      });
    }
  }

  Future<void> _savePassword() async {
    final cur = _currentPinController.text.trim();
    final next = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (cur != _savedPin) {
      setState(() => _errorText = 'လက်ရှိ Password မမှန်ကန်ပါ');
      return;
    }
    if (next.length != 4 || int.tryParse(next) == null) {
      setState(() => _errorText = 'Password အသစ်သည် ဂဏန်း ၄ လုံး ဖြစ်ရပါမည်');
      return;
    }
    if (next != confirm) {
      setState(() => _errorText = 'Password အသစ် ၂ ကြိမ် ရိုက်ထည့်မှု မတူညီပါ');
      return;
    }

    await StorageService.savePin(next);
    await StorageService.setPinEnabled(_isPinEnabled);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password အသစ် ပြောင်းလဲပြီးပါပြီ'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Password ပြောင်းရန်',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 20),
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const Text(
                'လက်ရှိ Password (၄ လုံး)',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              _dialogTextField(
                _currentPinController,
                '****',
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Password အသစ် (၄ လုံး)',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              _dialogTextField(
                _newPinController,
                '****',
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Password အသစ် အတည်ပြုရန်',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              _dialogTextField(
                _confirmPinController,
                '****',
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'PIN Lock ဖွင့်ထားမည်',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                value: _isPinEnabled,
                activeTrackColor: const Color(0xFFF59E0B),
                onChanged: (val) async {
                  setState(() => _isPinEnabled = val);
                  await StorageService.setPinEnabled(val);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _savePassword,
                child: const Text(
                  'Password ပြောင်းမည်',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. Device Code ယူရန် Dialog
class DeviceCodeDialog extends StatefulWidget {
  const DeviceCodeDialog({super.key});

  @override
  State<DeviceCodeDialog> createState() => _DeviceCodeDialogState();
}

class _DeviceCodeDialogState extends State<DeviceCodeDialog> {
  String _deviceCode = '...';
  bool _isActivated = false;
  String _activationStatusText = 'Not Activated';

  @override
  void initState() {
    super.initState();
    _loadDeviceCode();
  }

  Future<void> _loadDeviceCode() async {
    final code = await StorageService.getDeviceCode();
    final activated = await StorageService.isActivated();
    final statusText = await StorageService.getActivationStatusText();
    if (mounted) {
      setState(() {
        _deviceCode = code;
        _isActivated = activated;
        _activationStatusText = statusText;
      });
    }
  }

  Future<void> _openTelegram() async {
    final launched = await StorageService.openExternalUri(
      'tg://resolve?domain=CQY_COMPUTER',
      fallbackUri: 'https://t.me/CQY_COMPUTER',
    );
    if (!launched && mounted) {
      Clipboard.setData(const ClipboardData(text: '@CQY_COMPUTER'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram (@CQY_COMPUTER) ကို ကူးယူပြီးပါပြီ'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.phonelink_setup,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Device Code ယူရန်',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
              const Divider(color: Color(0xFF1E293B), height: 20),
              const Text(
                'device code ကိုကူးယူပြီး Admin ထံပေးပို့၍ Activation Key ပြန်တောင်းယူပါ။',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF090E1B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Device ID',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SelectableText(
                        _deviceCode,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _isActivated
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _activationStatusText,
                        style: TextStyle(
                          color: _isActivated
                              ? const Color(0xFF10B981)
                              : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text(
                  'Device ID Copy ကူးမည်',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _deviceCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Device ID ($_deviceCode) ကို ကူးယူပြီးပါပြီ',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _openTelegram,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.telegram,
                        color: Color(0xFF2AABEE),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Telegram: ',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                '@CQY_COMPUTER',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF38BDF8),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 5. Activation ပြုလုပ်ရန် Dialog
class ActivationDialog extends StatefulWidget {
  final bool isLockScreen;
  final VoidCallback? onActivated;

  const ActivationDialog({
    super.key,
    this.isLockScreen = false,
    this.onActivated,
  });

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final _keyController = TextEditingController();
  String _deviceCode = '...';
  bool _isActivated = false;
  String _activationStatusText = 'Not Activated';
  String? _statusMsg;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final code = await StorageService.getDeviceCode();
    final activated = await StorageService.isActivated();
    final statusText = await StorageService.getActivationStatusText();
    if (mounted) {
      setState(() {
        _deviceCode = code;
        _isActivated = activated;
        _activationStatusText = statusText;
      });
    }
  }

  Future<void> _pasteKey() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().isNotEmpty && mounted) {
      setState(() {
        _keyController.text = clip.text!.trim();
      });
    }
  }

  Future<void> _activate() async {
    final result = await StorageService.activateWithKeyDetailed(
      _keyController.text,
    );
    final ok = result == 'SUCCESS';
    if (ok) {
      // Ensure existing saved records remain intact and synced to mirror backup
      final existingRecords = await StorageService.getRecords();
      await StorageService.saveAllRecords(existingRecords);
    }
    final statusText = await StorageService.getActivationStatusText();
    if (mounted) {
      setState(() {
        _isActivated = ok || _isActivated;
        _activationStatusText = statusText;
        _isSuccess = ok;
        if (result == 'SUCCESS') {
          _statusMsg =
              'Activation အောင်မြင်ပါသည်! ($statusText)\nသိမ်းဆည်းထားသော စာရင်းအချက်အလက်များ အားလုံး မပျက်မစီး ဆက်လက်ရှိနေပါသည်။';
        } else if (result == 'USED') {
          _statusMsg = 'ဤ Activation Key သည် အသုံးပြုပြီးသား ဖြစ်နေပါသဖြင့် ပြန်လည်အသုံးပြု၍ မရပါ။';
        } else {
          _statusMsg = 'Activation Key မမှန်ကန်ပါ။ ပြန်လည်စစ်ဆေးပါ။';
        }
      });
      if (ok && widget.onActivated != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            widget.onActivated!();
          }
        });
      }
    }
  }

  void _copyDeviceId() {
    if (_deviceCode.isEmpty || _deviceCode == '...') return;
    Clipboard.setData(ClipboardData(text: _deviceCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device ID ($_deviceCode) ကို ကူးယူပြီးပါပြီ'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openTelegram() async {
    final launched = await StorageService.openExternalUri(
      'tg://resolve?domain=CQY_COMPUTER',
      fallbackUri: 'https://t.me/CQY_COMPUTER',
    );
    if (!launched && mounted) {
      Clipboard.setData(const ClipboardData(text: '@CQY_COMPUTER'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram (@CQY_COMPUTER) ကို ကူးယူပြီးပါပြီ'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Activation ပြုလုပ်ရန်',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isLockScreen)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Device ID:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: InkWell(
                      onTap: _copyDeviceId,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _deviceCode,
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _activationStatusText,
                        style: TextStyle(
                          color: _isActivated
                              ? const Color(0xFF10B981)
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _openTelegram,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.telegram,
                            color: Color(0xFF2AABEE),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Telegram:',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                '@CQY_COMPUTER',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF38BDF8),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activation Key ထည့်သွင်းပါ',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.content_paste,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    label: const Text(
                      'Paste',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _pasteKey,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _dialogTextField(_keyController, 'ACT-XXXX-XXXX-XXXX'),
              if (_statusMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMsg!,
                  style: TextStyle(
                    color: _isSuccess
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Activate ပြုလုပ်မည်',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _activate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 7. Import / Export .vcf Dialog
class VcfImportExportDialog extends StatefulWidget {
  final VoidCallback onRecordsImported;

  const VcfImportExportDialog({super.key, required this.onRecordsImported});

  @override
  State<VcfImportExportDialog> createState() => _VcfImportExportDialogState();
}

class _VcfImportExportDialogState extends State<VcfImportExportDialog> {
  final _pathController = TextEditingController();
  String? _pickedLocalPath;
  String? _statusMessage;
  bool _isError = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initDefaultPath();
  }

  void _initDefaultPath() {
    final defaultPath = Platform.isAndroid
        ? '/storage/emulated/0/loan_records_backup.vcf'
        : '${Directory.systemTemp.path}/loan_records_backup.vcf';
    _pathController.text = defaultPath;
  }

  Future<bool> _showConfirmDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCBD5E1),
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _browseVcfFile() async {
    try {
      final picked = await StorageService.pickVcfFile();
      if (picked != null && mounted) {
        setState(() {
          _pickedLocalPath = picked['localPath'];
          _pathController.text =
              picked['displayPath'] ?? picked['localPath'] ?? '';
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _statusMessage = 'ဖိုင်ရွေးချယ်မှု အမှား: $e';
        });
      }
    }
  }

  Future<void> _exportVcf() async {
    final confirmed = await _showConfirmDialog(
      'ချေးငွေစာရင်းများကို ဖုန်းအတွင်း သိမ်းဆည်းမည်',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });
    try {
      String rawPath = _pathController.text.trim();
      String fileName = 'loan_records_backup.vcf';
      if (rawPath.isNotEmpty) {
        final parts = rawPath.replaceAll('\\', '/').split('/');
        final lastPart = parts.last.trim();
        if (lastPart.isNotEmpty) {
          fileName = lastPart.toLowerCase().endsWith('.vcf')
              ? lastPart
              : '$lastPart.vcf';
        }
      }

      final savedPath = await StorageService.exportVcfToInternalStorage(
        fileName: fileName,
      );
      _pathController.text = savedPath;
      _pickedLocalPath = savedPath;

      if (mounted) {
        setState(() {
          _isBusy = false;
          _isError = false;
          _statusMessage =
              'စာရင်းများကို သိမ်းဆည်းပြီးပါပြီ!\nလမ်းကြောင်း: $savedPath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isError = true;
          _statusMessage = 'Export အမှား: $e';
        });
      }
    }
  }

  Future<void> _importVcfFromFile() async {
    final confirmed = await _showConfirmDialog(
      'ဖုန်း အတွင်း သိမ်းဆည်းထားသော စာရင်းများကို ပြန်ထည့်မည်',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });
    try {
      File? targetFile;
      if (_pickedLocalPath != null && await File(_pickedLocalPath!).exists()) {
        targetFile = File(_pickedLocalPath!);
      } else {
        final typedFile = File(_pathController.text.trim());
        if (await typedFile.exists()) {
          targetFile = typedFile;
        } else {
          // Open file picker if the specified file doesn't exist yet
          final picked = await StorageService.pickVcfFile();
          if (picked != null && picked['localPath'] != null) {
            _pickedLocalPath = picked['localPath'];
            _pathController.text =
                picked['displayPath'] ?? picked['localPath']!;
            targetFile = File(_pickedLocalPath!);
          }
        }
      }

      if (targetFile == null || !await targetFile.exists()) {
        throw Exception('ထည့်သွင်းမည့် စာရင်းဖိုင်.vcfကို ရွေးချယ်ပေးပါ။');
      }

      final count = await StorageService.importFromVcfFile(targetFile);
      widget.onRecordsImported();
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isError = count == 0;
          _statusMessage = count > 0
              ? 'စာရင်း ($count) ခု ထည့်သွင်း ယူပြီးပါပြီ!'
              : '.vcf ဖိုင်ထဲတွင် စာရင်းမတွေ့ပါ။';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isError = true;
          _statusMessage = 'Import အမှား: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.import_export,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Import / Export .vcf',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
              const Divider(color: Color(0xFF1E293B), height: 20),
              const Text(
                'စာရင်းဖိုင် ယူရန်/သိမ်းရန် လမ်းကြောင်းရွေးပါ။',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _dialogTextField(
                      _pathController,
                      '/storage/emulated/0/loan_records_backup.vcf',
                      onChanged: (_) {
                        _pickedLocalPath = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    tooltip: 'ဖိုင်ရှာရန်',
                    icon: const Icon(Icons.folder_open, size: 20),
                    onPressed: _isBusy ? null : _browseVcfFile,
                  ),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isError ? Colors.red : const Color(0xFF10B981))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isError
                          ? Colors.redAccent
                          : const Color(0xFF10B981),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isError
                          ? Colors.redAccent
                          : const Color(0xFF10B981),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text(
                        'Export .vcf',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: _isBusy ? null : _exportVcf,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.download_for_offline, size: 18),
                      label: const Text(
                        'Import .vcf',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: _isBusy ? null : _importVcfFromFile,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 8. App Info (About App) Dialog
class AppInfoDialog extends StatefulWidget {
  const AppInfoDialog({super.key});

  @override
  State<AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<AppInfoDialog> {
  Future<void> _openTelegram() async {
    final launched = await StorageService.openExternalUri(
      'tg://resolve?domain=CQY_COMPUTER',
      fallbackUri: 'https://t.me/CQY_COMPUTER',
    );
    if (!launched && mounted) {
      Clipboard.setData(const ClipboardData(text: '@CQY_COMPUTER'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram (@CQY_COMPUTER) ကို ကူးယူပြီးပါပြီ'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Text(
            content,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0F172A),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'ပိတ်မည်',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Color(0xFF1E293B), thickness: 1.2, height: 1),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E2D4A), width: 1.2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header (About App)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'App Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
              const Divider(color: Color(0xFF1E293B), height: 16),

              // 1. App Name & Version 1.0.0
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFFF59E0B),
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'တိုးရင်းစာရင်း (Loan & Interest Record)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionDivider(),

              // 2. DEVELOPER INFO
              _sectionHeader('DEVELOPER INFO', Icons.code_rounded),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2B43)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"CQY" Computer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Developer: KoMyo_ShweKyin',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              _sectionDivider(),

              // 3. CONTACT & SUPPORT
              _sectionHeader('CONTACT & SUPPORT', Icons.support_agent_rounded),

              // Telegram Button + QR Code Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _openTelegram,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.telegram,
                              color: Color(0xFF2AABEE),
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Telegram: @CQY_COMPUTER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionDivider(),

              // 4. LEGAL
              _sectionHeader('LEGAL INFO', Icons.gavel_rounded),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2B43)),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      onTap: () => _showLegalDialog(
                        'Privacy Policy',
                        'ယခု App သည် Offline App ဖြစ်သည်။ App တွင် ထည့်သွင်း သိမ်းဆည်းထားသော ချေးငွေစာရင်းများ၊ ဓာတ်ပုံများနှင့် ကိုယ်ရေး အချက်အလက်များ အားလုံးကို သုံးစွဲသူ၏ ဖုန်းအတွင်း၌သာ လုံခြုံစွာ သိမ်းဆည်းထားပြီး ပြင်ပ Server များသို့ ပေးပို့ခြင်း လုံးဝ မရှိပါ။',
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '- Privacy Policy',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      onTap: () => _showLegalDialog(
                        'Terms & Conditions',
                        'ယခု App ကို "CQY" Computer (Developer: KoMyo_Shwekyin) မှ ရေးသား ထုတ်လုပ်ထားပြီး တရားဝင် Activation Key ဖြင့်သာ အသုံးပြု နိုင်မည်ဖြစ်ပါသည်။ ခွင့်ပြုချက်မရှိဘဲ ပြန်လည်ဖြန့်ဝေခြင်း သို့မဟုတ် ပြုပြင် ပြောင်းလဲခြင်းကို တားမြစ်ထားပါသည်။',
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '- Terms & Conditions',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionDivider(),

              // 6. Footer Copyright
              const Center(
                child: Text(
                  '© 2026 "CQY" Computer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _dialogTextField(
  TextEditingController controller,
  String hint, {
  TextInputType? keyboardType,
  int? maxLength,
  bool obscureText = false,
  ValueChanged<String>? onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF090E1B),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1E293B)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
    ),
  );
}
