import 'package:flutter_test/flutter_test.dart';
import 'package:eeg_mobil/main.dart';

void main() {
  testWidgets('App opens with live EEG tab', (WidgetTester tester) async {
    await tester.pumpWidget(const EegMobilApp());
    await tester.pump(); // first frame
    expect(find.text('Canlı EEG Durumu'), findsOneWidget);
    expect(find.text('Canlı EEG'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
