import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/settings_page/user_guide_page.dart';

void main() {
  testWidgets('guide sections start collapsed and examples can be copied',
      (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      const MaterialApp(home: UserGuidePage()),
    );

    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Kopiera exempel'), findsNothing);

    await tester.tap(find.text('Träningslogg'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    final copyButton = find.text('Kopiera exempel').first;
    await tester.scrollUntilVisible(
      copyButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pump();

    expect(copiedText, contains('Helkropp'));
    expect(find.text('Exemplet kopierat'), findsOneWidget);
  });
}
