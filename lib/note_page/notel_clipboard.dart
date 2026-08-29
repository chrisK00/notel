import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

class NotelClipboard {
  static Delta? _copiedDelta;
  static String? _plainText;

  static bool get hasData => _copiedDelta != null;

  static void copySelection(QuillController controller) {
    if (controller.selection.isCollapsed) return;
    final start = controller.selection.start;
    final end = controller.selection.end;
    final slice = controller.document.toDelta().slice(start, end);
    _copiedDelta = slice;
    final text = controller.document.getPlainText(start, end - start);
    _plainText = text;
    Clipboard.setData(ClipboardData(text: text));
  }

  static void cutSelection(QuillController controller) {
    if (controller.selection.isCollapsed) return;
    copySelection(controller);
    final start = controller.selection.start;
    final len = controller.selection.end - start;
    controller.replaceText(start, len, '', TextSelection.collapsed(offset: start));
  }

  static Future<void> pasteClipboard(QuillController controller) async {
    final sysData = await Clipboard.getData(Clipboard.kTextPlain);
    final sysText = sysData?.text;

    final start = controller.selection.start;
    final len = controller.selection.isCollapsed ? 0 : (controller.selection.end - start);

    if (_copiedDelta != null && (sysText == null || sysText == _plainText)) {
      if (len > 0) {
        controller.replaceText(start, len, '', TextSelection.collapsed(offset: start));
      }

      var currentOffset = controller.selection.baseOffset;
      for (final op in _copiedDelta!.toList()) {
        if (op.isInsert && op.data is String) {
          final str = op.data as String;
          controller.replaceText(
            currentOffset,
            0,
            str,
            TextSelection.collapsed(offset: currentOffset + str.length),
          );
          if (op.attributes != null) {
            for (final entry in op.attributes!.entries) {
              controller.formatText(
                currentOffset,
                str.length,
                Attribute.fromKeyValue(entry.key, entry.value),
              );
            }
          }
          currentOffset += str.length;
        }
      }
    } else if (sysText != null && sysText.isNotEmpty) {
      controller.replaceText(
        start,
        len,
        sysText,
        TextSelection.collapsed(offset: start + sysText.length),
      );
    }
  }
}
