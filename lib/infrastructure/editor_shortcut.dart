import 'dart:convert';

/// A text expansion available in the note editor.
class EditorShortcut {
  const EditorShortcut({
    required this.trigger,
    required this.replacement,
    this.bold = false,
  });

  final String trigger;
  final String replacement;
  final bool bold;

  factory EditorShortcut.fromMap(Map<String, dynamic> map) => EditorShortcut(
        trigger: map['trigger'] as String? ?? '',
        replacement: map['replacement'] as String? ?? '',
        bold: map['bold'] == true,
      );

  Map<String, dynamic> toMap() => {
        'trigger': trigger,
        'replacement': replacement,
        'bold': bold,
      };

  static List<EditorShortcut> decodeList(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
              (item) => EditorShortcut.fromMap(Map<String, dynamic>.from(item)))
          .where((shortcut) =>
              shortcut.trigger.isNotEmpty && shortcut.replacement.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encodeList(List<EditorShortcut> shortcuts) =>
      jsonEncode(shortcuts.map((shortcut) => shortcut.toMap()).toList());
}
