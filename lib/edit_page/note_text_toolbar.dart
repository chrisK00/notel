import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class NoteTextToolbar extends StatelessWidget {
  const NoteTextToolbar({super.key, required QuillController controller})
      : _controller = controller;

  final QuillController _controller;

  @override
  Widget build(BuildContext context) => QuillToolbar.simple(
        configurations: QuillSimpleToolbarConfigurations(
          showFontFamily: false,
          showCodeBlock: false,
          showUnderLineButton: false,
          showSubscript: false,
          showSuperscript: false,
          showClearFormat: false,
          showIndent: false,
          showLink: false,
          showClipboardCopy: false,
          showClipboardCut: false,
          showInlineCode: false,
          multiRowsDisplay: false,
          controller: _controller,
        ),
      );
}
