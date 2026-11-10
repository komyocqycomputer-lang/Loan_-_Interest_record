import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DurationResult {
  final int years;
  final int months;
  final int days;
  final double totalMonthsFraction;
  final String displayText;
  final bool isValid;

  DurationResult({
    required this.years,
    required this.months,
    required this.days,
    required this.totalMonthsFraction,
    required this.displayText,
    required this.isValid,
  });
}

class CalculationResult {
  final double principal;
  final double monthlyRate;
  final double monthlyInterest;
  final double durationMonths;
  final double totalInterest;
  final double totalAmountDue;

  CalculationResult({
    required this.principal,
    required this.monthlyRate,
    required this.monthlyInterest,
    required this.durationMonths,
    required this.totalInterest,
    required this.totalAmountDue,
  });
}

class LoanCalculatorHelper {
  static final DateFormat _dmyFormat = DateFormat('dd/MM/yyyy');
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  static String formatDMY(DateTime date) {
    return _dmyFormat.format(date);
  }

  static DateTime addMonths(DateTime from, int months) {
    var newYear = from.year;
    var newMonth = from.month + months;
    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }
    while (newMonth < 1) {
      newYear--;
      newMonth += 12;
    }
    final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = from.day > daysInNewMonth ? daysInNewMonth : from.day;
    return DateTime(newYear, newMonth, newDay);
  }

  static DateTime? parseDMY(String dmy) {
    final clean = dmy.trim();
    if (clean.isEmpty) return null;
    final parts = clean.split(RegExp(r'[/.-]'));
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    if (year >= 0 && year < 100) {
      year += 2000;
    }
    if (year < 1900 || year > 2100) return null;

    try {
      final date = DateTime(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static DurationResult calculateDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return DurationResult(
        years: 0,
        months: 0,
        days: 0,
        totalMonthsFraction: 0,
        displayText: 'ရက်စွဲ ထည့်သွင်းပါ',
        isValid: false,
      );
    }

    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    if (endDate.isBefore(startDate)) {
      return DurationResult(
        years: 0,
        months: 0,
        days: 0,
        totalMonthsFraction: 0,
        displayText: 'ပြီးဆုံးရက်သည် စတင်ရက်ထက် ကြီးရမည်',
        isValid: false,
      );
    }

    var years = endDate.year - startDate.year;
    var months = endDate.month - startDate.month;
    var days = endDate.day - startDate.day;

    if (days < 0) {
      months -= 1;
      final prevMonthLastDay = DateTime(endDate.year, endDate.month, 0).day;
      days += prevMonthLastDay;
    }

    if (months < 0) {
      years -= 1;
      months += 12;
    }

    // Financial prorating in months
    final totalMonthsFraction = (years * 12.0) + months + (days / 30.0);

    final parts = <String>[];
    if (years > 0) parts.add('$years နှစ်');
    if (months > 0 || years > 0) parts.add('$months လ');
    parts.add('$days ရက်');

    final displayText = parts.join('၊ ');

    return DurationResult(
      years: years,
      months: months,
      days: days,
      totalMonthsFraction: totalMonthsFraction < 0 ? 0 : totalMonthsFraction,
      displayText: displayText,
      isValid: true,
    );
  }

  static CalculationResult calculateLoan({
    required double loanAmount,
    required double monthlyRatePercent,
    required double durationMonths,
  }) {
    final principal = loanAmount < 0 ? 0.0 : loanAmount;
    final rate = monthlyRatePercent < 0 ? 0.0 : monthlyRatePercent;
    final duration = durationMonths < 0 ? 0.0 : durationMonths;

    final monthlyInterest = (principal * rate) / 100.0;
    final totalInterest = monthlyInterest * duration;
    final totalAmountDue = principal + totalInterest;

    return CalculationResult(
      principal: principal,
      monthlyRate: rate,
      monthlyInterest: monthlyInterest,
      durationMonths: duration,
      totalInterest: totalInterest,
      totalAmountDue: totalAmountDue,
    );
  }

  static String formatCurrency(num amount) {
    return _currencyFormat.format(amount.round());
  }

  static String toMyanmarDigits(String input) {
    const mmDigits = ['၀', '၁', '၂', '၃', '၄', '၅', '၆', '၇', '၈', '၉'];
    var result = input;
    for (var i = 0; i <= 9; i++) {
      result = result.replaceAll(i.toString(), mmDigits[i]);
    }
    return result;
  }
}

/// Automatically formats numbers with thousand separators (e.g., 1,000,000)
/// in real time while maintaining exact cursor position.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Keep only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final newFormatted = _formatter.format(number);

    // Calculate cursor position based on digits before cursor
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, end)
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    var newOffset = 0;
    var count = 0;
    for (var i = 0; i < newFormatted.length; i++) {
      if (RegExp(r'\d').hasMatch(newFormatted[i])) {
        count++;
      }
      if (count == digitsBeforeCursor) {
        newOffset = i + 1;
        break;
      }
    }

    if (digitsBeforeCursor == 0) {
      newOffset = 0;
    }

    return TextEditingValue(
      text: newFormatted,
      selection: TextSelection.collapsed(offset: newOffset.clamp(0, newFormatted.length)),
    );
  }
}

/// Automatically formats date input as dd/MM/yyyy in real time as the user types.
/// Restricts Day <= 31 and Month <= 12.
class DateAutoSlashInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final clampedDigits = digits.length > 8 ? digits.substring(0, 8) : digits;

    String d = '';
    String m = '';
    String y = '';

    if (clampedDigits.length <= 2) {
      d = clampedDigits;
      final dNum = int.tryParse(d);
      if (dNum != null && dNum > 31) d = '31';
    } else if (clampedDigits.length <= 4) {
      d = clampedDigits.substring(0, 2);
      final dNum = int.tryParse(d);
      if (dNum != null && dNum > 31) d = '31';

      m = clampedDigits.substring(2);
      final mNum = int.tryParse(m);
      if (mNum != null && mNum > 12) m = '12';
    } else {
      d = clampedDigits.substring(0, 2);
      final dNum = int.tryParse(d);
      if (dNum != null && dNum > 31) d = '31';

      m = clampedDigits.substring(2, 4);
      final mNum = int.tryParse(m);
      if (mNum != null && mNum > 12) m = '12';

      y = clampedDigits.substring(4);
    }

    final buffer = StringBuffer(d);
    if (d.length == 2 && clampedDigits.length > 2) {
      buffer.write('/$m');
      if (m.length == 2 && clampedDigits.length > 4) {
        buffer.write('/$y');
      }
    } else if (d.length == 2 && clampedDigits.length == 2) {
      buffer.write('/');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

