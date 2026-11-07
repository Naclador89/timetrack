import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/main.dart';

void main() {
  testWidgets('app starts and shows its title', (tester) async {
    await tester.pumpWidget(const TimeTrackApp());
    expect(find.text('TimeTrack'), findsOneWidget);
  });
}
