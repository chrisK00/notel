import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SectionDividerEmbedBuilder extends EmbedBuilder {
  const SectionDividerEmbedBuilder();

  static const type = 'section-divider';

  @override
  String get key => type;

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    return const SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1),
      ),
    );
  }
}
