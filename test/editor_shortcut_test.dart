import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/editor_shortcut.dart';

void main() {
  test('editor shortcuts persist their replacement and bold formatting', () {
    const shortcut = EditorShortcut(
      trigger: '.ss',
      replacement: 'start',
      bold: true,
    );

    final decoded = EditorShortcut.decodeList(
      EditorShortcut.encodeList([shortcut]),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.trigger, '.ss');
    expect(decoded.single.replacement, 'start');
    expect(decoded.single.bold, isTrue);
  });

  test('invalid stored shortcut data is ignored', () {
    expect(EditorShortcut.decodeList('not json'), isEmpty);
    expect(EditorShortcut.decodeList('[{"trigger":"","replacement":"x"}]'),
        isEmpty);
  });
}
