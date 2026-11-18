import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'notel_clipboard.dart';
import 'section_divider.dart';

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
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showColorButton: false,
              showBackgroundColorButton: false,
              showHeaderStyle: false,
              showListNumbers: true,
              showListBullets: false,
              showListCheck: true,
              showCodeBlock: true,
              showQuote: true,
              showLink: false,
              showUndo: false,
              showRedo: false,
              showSearchButton: false,
              showInlineCode: true,
              showLineHeightButton: false,
              showDirection: true,
              showClipboardCut: false,
              showClipboardCopy: false,
              showClipboardPaste: false,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.copy_all, size: 18),
                  tooltip: 'Copy current line',
                  onPressed: () => NotelClipboard.copyLine(_controller),
                ),
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.cut, size: 18),
                  tooltip: 'Cut formatted text',
                  onPressed: () => NotelClipboard.cutSelection(_controller),
                ),
                QuillToolbarCustomButtonOptions(
                  tooltip: 'Font color',
                  childBuilder: (options, extraOptions) =>
                      QuillToolbarColorButton(
                    controller: extraOptions.controller,
                    isBackground: false,
                  ),
                ),
                QuillToolbarCustomButtonOptions(
                  tooltip: 'Background color',
                  childBuilder: (options, extraOptions) =>
                      QuillToolbarColorButton(
                    controller: extraOptions.controller,
                    isBackground: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLinkDialog(BuildContext context) async {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final start = selection.start;
    final length = selection.end - selection.start;
    final result = await showDialog<_LinkDraft>(
      context: context,
      builder: (context) => _LinkDialog(
        initialText:
            length > 0 ? _controller.document.getPlainText(start, length) : '',
        initialUrl: '',
      ),
    );
    if (result == null) return;

    _controller
      ..replaceText(start, length, result.text, null)
      ..formatText(start, result.text.length, LinkAttribute(result.url));
  }

  void _insertSectionDivider() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final plainText = _controller.document.toPlainText();
    final start = selection.start;
    final end = selection.end;
    final insertion = Delta();

    if (start > 0 && plainText[start - 1] != '\n') {
      insertion.insert('\n');
    }
    insertion.insert({SectionDividerEmbedBuilder.type: ''});
    if (end < plainText.length && plainText[end] != '\n') {
      insertion.insert('\n');
    }

    _controller.replaceText(
      start,
      selection.end - selection.start,
      insertion,
      TextSelection.collapsed(offset: start + insertion.length.toInt()),
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
            showCodeBlock: false,
            showInlineCode: false,
            showStrikeThrough: false,
            showItalicButton: false,
            showUndo: true,
            showRedo: true,
            showSearchButton: true,
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
            showListNumbers: false,
            showListBullets: true,
            showListCheck: false,
            showQuote: false,
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
                icon: const Icon(Icons.horizontal_rule, size: 18),
                tooltip: 'Insert divider',
                onPressed: _insertSectionDivider,
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy formatted text',
                onPressed: () => NotelClipboard.copySelection(_controller),
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.paste, size: 18),
                tooltip: 'Paste formatted text',
                onPressed: () => NotelClipboard.pasteClipboard(_controller),
              ),
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.link, size: 18),
                tooltip: 'Insert URL',
                onPressed: () => _showLinkDialog(context),
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

class _LinkDraft {
  const _LinkDraft(this.text, this.url);

  final String text;
  final String url;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({
    required this.initialText,
    required this.initialUrl,
  });

  final String initialText;
  final String initialUrl;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _textController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canApply =>
      _textController.text.trim().isNotEmpty &&
      _urlController.text.trim().isNotEmpty;

  void _apply() {
    if (!_canApply) return;
    Navigator.of(context).pop(
      _LinkDraft(
        _textController.text.trim(),
        _urlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('link-text'),
            controller: _textController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Text'),
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          ),
          TextField(
            key: const ValueKey('link-url'),
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'URL'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _apply(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canApply ? _apply : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
