import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'notel_clipboard.dart';

class NoteTextToolbar extends StatelessWidget {
  const NoteTextToolbar({super.key, required QuillController controller})
      : _controller = controller;

  final QuillController _controller;

  void _showHeaderPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      barrierColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              ('Normal', null),
              ('Heading 1', 1),
              ('Heading 2', 2),
              ('Heading 3', 3),
            ])
              ListTile(
                title: Text(option.$1),
                onTap: () {
                  _controller.formatSelection(
                    Attribute.fromKeyValue(Attribute.header.key, option.$2),
                  );
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFontSizePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      barrierColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              ('Small', 'small'),
              ('Large', 'large'),
              ('Huge', 'huge'),
              ('Normal', null),
            ])
              ListTile(
                title: Text(option.$1),
                onTap: () {
                  _controller.formatSelection(
                    Attribute.fromKeyValue(Attribute.size.key, option.$2),
                  );
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

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
              showFontSize: false,
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
            showHeaderStyle: false,
            showDividers: false,
            showCodeBlock: true,
            showInlineCode: false,
            showUndo: true,
            showRedo: true,
            buttonOptions: QuillSimpleToolbarButtonOptions(
              undoHistory: QuillToolbarHistoryButtonOptions(
                childBuilder: (options, extra) => IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo, size: 18),
                  onPressed: extra.onPressed,
                ),
              ),
              redoHistory: QuillToolbarHistoryButtonOptions(
                childBuilder: (options, extra) => IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo, size: 18),
                  onPressed: extra.onPressed,
                ),
              ),
            ),
            showColorButton: false,
            showBackgroundColorButton: false,
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
                icon: const Icon(Icons.format_size, size: 18),
                tooltip: 'Font size',
                onPressed: () => _showFontSizePicker(context),
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.title, size: 18),
                tooltip: 'Text style',
                onPressed: () => _showHeaderPicker(context),
              ),
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
                tooltip: 'Font color',
                childBuilder: (options, extraOptions) => QuillToolbarColorButton(
                  controller: extraOptions.controller,
                  isBackground: false,
                ),
              ),
              QuillToolbarCustomButtonOptions(
                tooltip: 'Background color',
                childBuilder: (options, extraOptions) => QuillToolbarColorButton(
                  controller: extraOptions.controller,
                  isBackground: true,
                ),
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
