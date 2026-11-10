import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loan_calculator/models/loan_record.dart';
import 'package:loan_calculator/screens/records_screen.dart';
import 'package:loan_calculator/services/storage_service.dart';

void main() {
  testWidgets('RecordsScreen displays records and verifies alignment', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveAllRecords([
      LoanRecord(
        id: 'test-004',
        codeNo: '004',
        name: 'သင်းသင်းယု',
        address: 'ထိန်ကန်',
        phone1: '09973214450',
        phone2: '',
        loanAmount: 200000,
        monthlyInterestRate: 3.0,
        startDate: '15/09/2025',
        endDate: '16/09/2026',
        durationText: '1 နှစ်၊ 0 လ၊ 1 ရက်',
        durationMonths: 12.03,
        totalInterest: 18400,
        totalAmountDue: 218400,
        createdAt: 1000,
        updatedAt: 1000,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: RecordsScreen(),
      ),
    );

    // Pump frames to complete async loading
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify records loaded
    expect(find.text('သိမ်းထားသောစာရင်း'), findsOneWidget);
    expect(find.text('သင်းသင်းယု'), findsOneWidget);

    final nameFinder = find.text('သင်းသင်းယု');
    final codeFinder = find.text('004');
    final totalDueFinder = find.textContaining('ကျသင့်ငွေ:');

    // Find the photo container (height: 101)
    final photoContainerFinder = find.byWidgetPredicate(
      (w) => w is Container && (w.constraints?.minHeight == 101 || (w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border?.top.color == const Color(0xFFB45309))),
    ).first;

    final codeBadgeFinder = find.ancestor(
      of: codeFinder,
      matching: find.byType(Container),
    ).first;

    final photoRect = tester.getRect(photoContainerFinder);
    final codeRect = tester.getRect(codeBadgeFinder);
    final nameRowFinder = find.ancestor(of: nameFinder, matching: find.byType(Row)).first;
    final nameRowRect = tester.getRect(nameRowFinder);
    final totalDueRect = tester.getRect(totalDueFinder.first);

    debugPrint('PhotoContainer top: ${photoRect.top}, NameRow top: ${nameRowRect.top}');
    debugPrint('PhotoContainer bottom: ${photoRect.bottom}');
    debugPrint('CodeBadge bottom: ${codeRect.bottom}, Total Due bottom: ${totalDueRect.bottom}');

    // Photo top and NameRow top should be exactly equal
    expect(photoRect.top, equals(nameRowRect.top));
    // Code bottom and TotalDue bottom should be exactly equal
    expect(codeRect.bottom, equals(totalDueRect.bottom));
  });
}
