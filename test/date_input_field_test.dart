import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_calculator/widgets/date_input_field.dart';

void main() {
  testWidgets('DateInputField initializes with external controller value', (tester) async {
    final controller = TextEditingController(text: '26/10/2026');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller),
        ),
      ),
    );

    expect(find.text('26'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(2));
  });

  testWidgets('DateInputField restricts day to max 31', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller),
        ),
      ),
    );

    // Enter Day: '35'
    final dayField = find.byType(TextField).at(0);
    await tester.enterText(dayField, '35');
    await tester.pump();

    // Should clamp to 31
    expect(find.text('31'), findsOneWidget);
    expect(controller.text.startsWith('31/'), isTrue);
  });

  testWidgets('DateInputField restricts month to max 12', (tester) async {
    final controller = TextEditingController(text: '15/01/2026');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller),
        ),
      ),
    );

    // Enter Month: '18'
    final monthField = find.byType(TextField).at(1);
    await tester.enterText(monthField, '18');
    await tester.pump();

    // Should clamp to 12
    expect(find.text('12'), findsOneWidget);
    expect(controller.text.contains('/12/'), isTrue);
  });

  testWidgets('DateInputField auto-pads day >= 4 and advances focus', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller),
        ),
      ),
    );

    final dayField = find.byType(TextField).at(0);
    await tester.tap(dayField);
    await tester.pump();

    await tester.enterText(dayField, '5');
    await tester.pump();

    // 5 becomes 05
    expect(find.text('05'), findsOneWidget);
  });

  testWidgets('DateInputField auto-pads month >= 2 and advances focus', (tester) async {
    final controller = TextEditingController(text: '05//2026');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller),
        ),
      ),
    );

    final monthField = find.byType(TextField).at(1);
    await tester.enterText(monthField, '6');
    await tester.pump();

    // 6 becomes 06
    expect(find.text('06'), findsOneWidget);
  });
}
