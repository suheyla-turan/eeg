import 'package:flutter_test/flutter_test.dart';

import 'package:eeg_ai_mobile/main.dart';

void main() {
  testWidgets('Uygulama ana ekranı yüklenir', (WidgetTester tester) async {
    await tester.pumpWidget(const EegAiApp());
    await tester.pump();

    expect(find.text('EEG AI'), findsOneWidget);
    expect(find.text('Duygu Yorumlama'), findsOneWidget);
  });
}
