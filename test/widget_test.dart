import 'package:flutter_test/flutter_test.dart';
import 'package:loan_calculator/main.dart';

void main() {
  testWidgets('Loan Calculator smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LoanCalculatorApp());
    expect(find.byType(LoanCalculatorApp), findsOneWidget);
  });
}
