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
    _copyRange(controller, start, end);
  }

  static void copyLine(QuillController controller) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return;

    final text = controller.document.toPlainText();
    if (text.isEmpty) return;
    final offset = selection.extentOffset.clamp(0, text.length);
    final previousNewline =
        offset == 0 ? -1 : text.lastIndexOf('\n', offset - 1);
    final start = previousNewline + 1;
    final nextNewline = text.indexOf('\n', offset);
    final end = nextNewline == -1 ? text.length : nextNewline + 1;
    if (start < end) _copyRange(controller, start, end);
  }

  static void _copyRange(QuillController controller, int start, int end) {
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
    controller.replaceText(
        start, len, '', TextSelection.collapsed(offset: start));
  }

  static Future<void> pasteClipboard(QuillController controller) async {
    final sysData = await Clipboard.getData(Clipboard.kTextPlain);
    final sysText = sysData?.text;

    final start = controller.selection.start;
    final len = controller.selection.isCollapsed
        ? 0
        : (controller.selection.end - start);

    if (_copiedDelta != null && (sysText == null || sysText == _plainText)) {
      if (len > 0) {
        controller.replaceText(
            start, len, '', TextSelection.collapsed(offset: start));
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
      _insertExternalText(controller, sysText, start, len);
    }
  }

  static void _insertExternalText(
    QuillController controller,
    String text,
    int start,
    int length,
  ) {
    final url = _parseWebUrl(text.trim());
    final pastedText = url == null ? text : _displayTextForUrl(url);
    controller.replaceText(
      start,
      length,
      pastedText,
      TextSelection.collapsed(offset: start + pastedText.length),
    );
    if (url != null) {
      controller.formatText(
          start, pastedText.length, LinkAttribute(url.toString()));
    }
  }

  static Uri? _parseWebUrl(String text) {
    final value = text.startsWith('www.') ? 'https://$text' : text;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static String _displayTextForUrl(Uri url) {
    return url.toString().replaceFirst(RegExp(r'^https?://'), '');
  }
}
