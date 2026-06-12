import 'package:flutter_test/flutter_test.dart';
import 'package:set_control/main.dart';

void main() {
  testWidgets('SET-STOP app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SetStopApp());
    expect(find.text('SET-STOP'), findsWidgets);
  });
}
