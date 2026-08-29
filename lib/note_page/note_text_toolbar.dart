import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'notel_clipboard.dart';

class NoteTextToolbar extends StatelessWidget {
  const NoteTextToolbar({super.key, required QuillController controller})
      : _controller = controller;

  final QuillController _controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: QuillToolbar.simple(
          configurations: QuillSimpleToolbarConfigurations(
            showFontFamily: false,
            showCodeBlock: true,
            showInlineCode: false,
            showUnderLineButton: false,
            showSubscript: false,
            showSuperscript: false,
            showClearFormat: false,
            showIndent: false,
            showLink: false,
            showClipboardCopy: false,
            showClipboardCut: false,
            showClipboardPaste: false,
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy formatted text',
                onPressed: () => NotelClipboard.copySelection(_controller),
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.cut, size: 18),
                tooltip: 'Cut formatted text',
                onPressed: () => NotelClipboard.cutSelection(_controller),
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.paste, size: 18),
                tooltip: 'Paste formatted text',
                onPressed: () => NotelClipboard.pasteClipboard(_controller),
              ),
            ],
            multiRowsDisplay: false,
            controller: _controller,
          ),
        ),
      ),
    );
  }
}
