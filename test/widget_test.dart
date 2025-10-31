import 'package:flutter_test/flutter_test.dart';
import 'package:ubike_alert/main.dart';

void main() {
  testWidgets('App starts with station list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UbikeAlertApp());

    // Verify that we see the station list screen title.
    expect(find.text('選擇監控站點'), findsOneWidget);
  });
}
