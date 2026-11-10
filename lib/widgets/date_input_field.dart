import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A robust, segmented date input field for dd/MM/yyyy format.
///
/// Features:
/// - Fixed slashes (`/`) that cannot be deleted or misplaced.
/// - Day restricted to 1..31. Auto-pads 4..9 to 04..09 and jumps to Month.
/// - Month restricted to 1..12. Auto-pads 2..9 to 02..09 and jumps to Year.
/// - Year limited to 4 digits.
/// - Automatically advances cursor/focus upon completing each segment.
/// - Backspace key navigation across empty segments.
/// - Full paste support (e.g. "26/10/2026").
/// - Real-time two-way synchronization with [controller].
class DateInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool enabled;

  const DateInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<DateInputField> createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  late final TextEditingController _dayController;
  late final TextEditingController _monthController;
  late final TextEditingController _yearController;

  late final FocusNode _dayFocus;
  late final FocusNode _monthFocus;
  late final FocusNode _yearFocus;

  bool _isInternalUpdating = false;
  bool _isFormattingDay = false;
  bool _isFormattingMonth = false;
  bool _isFormattingYear = false;

  @override
  void initState() {
    super.initState();
    _dayController = TextEditingController();
    _monthController = TextEditingController();
    _yearController = TextEditingController();

    _dayFocus = FocusNode();
    _monthFocus = FocusNode();
    _yearFocus = FocusNode();

    _dayFocus.addListener(_handleDayFocusChange);
    _monthFocus.addListener(_handleMonthFocusChange);
    _yearFocus.addListener(_handleYearFocusChange);

    _syncFromExternal();
    widget.controller.addListener(_onExternalControllerChanged);
  }

  @override
  void didUpdateWidget(covariant DateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternalControllerChanged);
      widget.controller.addListener(_onExternalControllerChanged);
      _syncFromExternal();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalControllerChanged);
    _dayFocus.removeListener(_handleDayFocusChange);
    _monthFocus.removeListener(_handleMonthFocusChange);
    _yearFocus.removeListener(_handleYearFocusChange);

    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();

    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _handleDayFocusChange() {
    if (_dayFocus.hasFocus) {
      if (_dayController.text.isNotEmpty) {
        _dayController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _dayController.text.length,
        );
      }
    } else {
      // On focus lost: normalize day
      final txt = _dayController.text.trim();
      if (txt.isNotEmpty) {
        final val = int.tryParse(txt);
        if (val != null) {
          final clamped = val.clamp(1, 31);
          final formatted = clamped.toString().padLeft(2, '0');
          if (formatted != txt) {
            _dayController.text = formatted;
            _syncToExternal();
          }
        }
      }
    }
  }

  void _handleMonthFocusChange() {
    if (_monthFocus.hasFocus) {
      if (_monthController.text.isNotEmpty) {
        _monthController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _monthController.text.length,
        );
      }
    } else {
      // On focus lost: normalize month
      final txt = _monthController.text.trim();
      if (txt.isNotEmpty) {
        final val = int.tryParse(txt);
        if (val != null) {
          final clamped = val.clamp(1, 12);
          final formatted = clamped.toString().padLeft(2, '0');
          if (formatted != txt) {
            _monthController.text = formatted;
            _syncToExternal();
          }
        }
      }
    }
  }

  void _handleYearFocusChange() {
    if (_yearFocus.hasFocus) {
      if (_yearController.text.isNotEmpty) {
        _yearController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _yearController.text.length,
        );
      }
    } else {
      // On focus lost: normalize year (e.g. 26 -> 2026)
      final txt = _yearController.text.trim();
      if (txt.isNotEmpty) {
        final val = int.tryParse(txt);
        if (val != null && val >= 0 && val < 100) {
          final expanded = (2000 + val).toString();
          _yearController.text = expanded;
          _syncToExternal();
        }
      }
    }
  }

  void _onExternalControllerChanged() {
    if (_isInternalUpdating) return;
    _syncFromExternal();
  }

  void _syncFromExternal() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      if (_dayController.text.isNotEmpty ||
          _monthController.text.isNotEmpty ||
          _yearController.text.isNotEmpty) {
        setState(() {
          _dayController.text = '';
          _monthController.text = '';
          _yearController.text = '';
        });
      }
      return;
    }

    final parts = text.split(RegExp(r'[/.-]'));
    final newDay = parts.isNotEmpty ? parts[0] : '';
    final newMonth = parts.length > 1 ? parts[1] : '';
    final newYear = parts.length > 2 ? parts[2] : '';

    if (_dayController.text != newDay ||
        _monthController.text != newMonth ||
        _yearController.text != newYear) {
      setState(() {
        _dayController.text = newDay;
        _monthController.text = newMonth;
        _yearController.text = newYear;
      });
    }
  }

  void _syncToExternal() {
    _isInternalUpdating = true;
    final d = _dayController.text.trim();
    final m = _monthController.text.trim();
    final y = _yearController.text.trim();

    if (d.isEmpty && m.isEmpty && y.isEmpty) {
      widget.controller.text = '';
    } else {
      widget.controller.text = '$d/$m/$y';
    }
    _isInternalUpdating = false;
    widget.onChanged?.call();
  }

  bool _tryHandlePaste(String val) {
    if (val.contains('/') || val.contains('-') || val.contains('.') || val.length >= 6) {
      final parts = val.trim().split(RegExp(r'[/.-]'));
      if (parts.length >= 2) {
        final dVal = (int.tryParse(parts[0]) ?? 1).clamp(1, 31).toString().padLeft(2, '0');
        final mVal = (int.tryParse(parts[1]) ?? 1).clamp(1, 12).toString().padLeft(2, '0');
        String yVal = parts.length > 2 ? parts[2].replaceAll(RegExp(r'[^\d]'), '') : _yearController.text;
        if (yVal.length > 4) yVal = yVal.substring(0, 4);

        _isFormattingDay = true;
        _isFormattingMonth = true;
        _isFormattingYear = true;

        _dayController.text = dVal;
        _monthController.text = mVal;
        _yearController.text = yVal;

        _isFormattingDay = false;
        _isFormattingMonth = false;
        _isFormattingYear = false;

        _syncToExternal();
        _yearFocus.requestFocus();
        _yearController.selection = TextSelection.collapsed(offset: _yearController.text.length);
        return true;
      }
    }
    return false;
  }

  void _handleDayChanged(String val) {
    if (_isFormattingDay || _isInternalUpdating) return;

    if (_tryHandlePaste(val)) return;

    final digits = val.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      _isFormattingDay = true;
      _dayController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      _isFormattingDay = false;
      _syncToExternal();
      return;
    }

    if (digits.length == 1) {
      final d = int.tryParse(digits) ?? 0;
      // If user types 4..9, day can never be 40..99, so auto-prefix '0' and move to month
      if (d >= 4) {
        final formatted = '0$d';
        _isFormattingDay = true;
        _dayController.value = TextEditingValue(
          text: formatted,
          selection: const TextSelection.collapsed(offset: 2),
        );
        _isFormattingDay = false;
        _syncToExternal();

        _monthFocus.requestFocus();
        if (_monthController.text.isNotEmpty) {
          _monthController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _monthController.text.length,
          );
        }
        return;
      }

      // If 0, 1, 2, 3: wait for next digit
      _isFormattingDay = true;
      _dayController.value = TextEditingValue(
        text: digits,
        selection: const TextSelection.collapsed(offset: 1),
      );
      _isFormattingDay = false;
      _syncToExternal();
      return;
    }

    // 2 or more digits entered
    final sub = digits.length > 2 ? digits.substring(0, 2) : digits;
    var numVal = int.tryParse(sub) ?? 1;

    // Day cannot exceed 31
    if (numVal > 31) {
      numVal = 31;
    } else if (numVal < 1) {
      numVal = 1;
    }

    final formatted = numVal.toString().padLeft(2, '0');
    _isFormattingDay = true;
    _dayController.value = TextEditingValue(
      text: formatted,
      selection: const TextSelection.collapsed(offset: 2),
    );
    _isFormattingDay = false;
    _syncToExternal();

    // Auto-advance cursor to month
    _monthFocus.requestFocus();
    if (_monthController.text.isNotEmpty) {
      _monthController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _monthController.text.length,
      );
    }
  }

  void _handleMonthChanged(String val) {
    if (_isFormattingMonth || _isInternalUpdating) return;

    if (_tryHandlePaste(val)) return;

    final digits = val.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      _isFormattingMonth = true;
      _monthController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      _isFormattingMonth = false;
      _syncToExternal();
      return;
    }

    if (digits.length == 1) {
      final m = int.tryParse(digits) ?? 0;
      // If user types 2..9, month can never be 20..99, so auto-prefix '0' and move to year
      if (m >= 2) {
        final formatted = '0$m';
        _isFormattingMonth = true;
        _monthController.value = TextEditingValue(
          text: formatted,
          selection: const TextSelection.collapsed(offset: 2),
        );
        _isFormattingMonth = false;
        _syncToExternal();

        _yearFocus.requestFocus();
        if (_yearController.text.isNotEmpty) {
          _yearController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _yearController.text.length,
          );
        }
        return;
      }

      // If 0 or 1: wait for next digit
      _isFormattingMonth = true;
      _monthController.value = TextEditingValue(
        text: digits,
        selection: const TextSelection.collapsed(offset: 1),
      );
      _isFormattingMonth = false;
      _syncToExternal();
      return;
    }

    // 2 or more digits entered
    final sub = digits.length > 2 ? digits.substring(0, 2) : digits;
    var numVal = int.tryParse(sub) ?? 1;

    // Month cannot exceed 12
    if (numVal > 12) {
      numVal = 12;
    } else if (numVal < 1) {
      numVal = 1;
    }

    final formatted = numVal.toString().padLeft(2, '0');
    _isFormattingMonth = true;
    _monthController.value = TextEditingValue(
      text: formatted,
      selection: const TextSelection.collapsed(offset: 2),
    );
    _isFormattingMonth = false;
    _syncToExternal();

    // Auto-advance cursor to year
    _yearFocus.requestFocus();
    if (_yearController.text.isNotEmpty) {
      _yearController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _yearController.text.length,
      );
    }
  }

  void _handleYearChanged(String val) {
    if (_isFormattingYear || _isInternalUpdating) return;

    if (_tryHandlePaste(val)) return;

    var digits = val.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 4) {
      digits = digits.substring(0, 4);
    }

    _isFormattingYear = true;
    _yearController.value = TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
    _isFormattingYear = false;
    _syncToExternal();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFFF59E0B),
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );

    const slashStyle = TextStyle(
      color: Color(0xFFF59E0B),
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    const hintStyle = TextStyle(
      color: Color(0x6694A3B8),
      fontSize: 13,
      fontWeight: FontWeight.normal,
    );

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF261D12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB45309)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Day Input
          SizedBox(
            width: 32,
            child: TextField(
              controller: _dayController,
              focusNode: _dayFocus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              cursorColor: const Color(0xFFF59E0B),
              style: textStyle,
              onChanged: _handleDayChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                hintText: 'dd',
                hintStyle: hintStyle,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),

          // Fixed slash separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('/', style: slashStyle),
          ),

          // Month Input (with backspace to day handler)
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  _monthController.text.isEmpty) {
                _dayFocus.requestFocus();
                _dayController.selection = TextSelection.collapsed(
                  offset: _dayController.text.length,
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: SizedBox(
              width: 32,
              child: TextField(
                controller: _monthController,
                focusNode: _monthFocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                cursorColor: const Color(0xFFF59E0B),
                style: textStyle,
                onChanged: _handleMonthChanged,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  hintText: 'mm',
                  hintStyle: hintStyle,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
          ),

          // Fixed slash separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('/', style: slashStyle),
          ),

          // Year Input (with backspace to month handler)
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  _yearController.text.isEmpty) {
                _monthFocus.requestFocus();
                _monthController.selection = TextSelection.collapsed(
                  offset: _monthController.text.length,
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: SizedBox(
              width: 52,
              child: TextField(
                controller: _yearController,
                focusNode: _yearFocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                cursorColor: const Color(0xFFF59E0B),
                style: textStyle,
                onChanged: _handleYearChanged,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  hintText: 'yyyy',
                  hintStyle: hintStyle,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
