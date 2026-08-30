import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'notel_clipboard.dart';

class NoteTextToolbar extends StatelessWidget {
  const NoteTextToolbar({super.key, required QuillController controller})
      : _controller = controller;

  final QuillController _controller;

  void _showMoreToolbar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      barrierColor: Colors.transparent,
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: QuillToolbar.simple(
            configurations: QuillSimpleToolbarConfigurations(
              controller: _controller,
              multiRowsDisplay: true,
              showFontSize: true,
              showSubscript: true,
              showSuperscript: true,
              showClearFormat: true,
              showAlignmentButtons: true,
              showIndent: true,
              showFontFamily: false,
              showBoldButton: false,
              showItalicButton: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showHeaderStyle: false,
              showListNumbers: false,
              showListBullets: false,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showLink: false,
              showUndo: false,
              showRedo: false,
              showSearchButton: false,
              showInlineCode: false,
              showLineHeightButton: false,
              showDirection: false,
              showClipboardCut: false,
              showClipboardCopy: false,
              showClipboardPaste: false,
            ),
          ),
        ),
      ),
    );
  }

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
            showFontSize: false,
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
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.more_horiz, size: 18),
                tooltip: 'More formatting options',
                onPressed: () => _showMoreToolbar(context),
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
