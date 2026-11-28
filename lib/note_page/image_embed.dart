import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Storage helper
// ---------------------------------------------------------------------------

/// Copies an image file into the app's documents/note_images directory and
/// returns the persistent absolute path.  Returns null if the copy fails.
Future<String?> copyImageToAppStorage(String sourcePath) async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'note_images'));
    await imagesDir.create(recursive: true);

    final ext = p.extension(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = p.join(imagesDir.path, fileName);
    await File(sourcePath).copy(dest);
    return dest;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Insertion helper
// ---------------------------------------------------------------------------

/// Opens the image picker, copies the selected image to app storage, and
/// inserts it into [controller] at the current selection position.
Future<void> pickAndInsertImage(
    BuildContext context, QuillController controller) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.first;
  final sourcePath = file.path;
  if (sourcePath == null) return;

  final destPath = await copyImageToAppStorage(sourcePath);
  if (destPath == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save image. Try again.')),
      );
    }
    return;
  }

  _insertImageEmbed(controller, destPath);
}

void _insertImageEmbed(QuillController controller, String imagePath) {
  final selection = controller.selection;
  if (!selection.isValid) return;

  final plainText = controller.document.toPlainText();
  final start = selection.start;
  final end = selection.end;

  final insertion = Delta();
  if (start > 0 && plainText[start - 1] != '\n') {
    insertion.insert('\n');
  }
  insertion.insert({'image': imagePath});
  if (end < plainText.length && plainText[end] != '\n') {
    insertion.insert('\n');
  }

  controller.replaceText(
    start,
    end - start,
    insertion,
    TextSelection.collapsed(offset: start + insertion.length.toInt()),
  );
}

// ---------------------------------------------------------------------------
// Embed builder
// ---------------------------------------------------------------------------

class ImageEmbedBuilder extends EmbedBuilder {
  const ImageEmbedBuilder();

  static const double _defaultWidth = 300.0;
  static const double _minWidth = 60.0;

  /// Parse a numeric width from a quill style string like "width:300.0".
  static double? _parseWidth(String? style) {
    if (style == null || style.isEmpty) return null;
    for (final part in style.split(';')) {
      final kv = part.split(':');
      if (kv.length == 2 && kv[0].trim() == 'width') {
        return double.tryParse(kv[1].trim());
      }
    }
    return null;
  }

  @override
  String get key => BlockEmbed.imageType; // 'image'

  @override
  String toPlainText(Embed node) => '[image]';

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final imagePath = node.value.data as String;
    final styleAttr = node.style.attributes[Attribute.style.key];
    final width =
        _parseWidth(styleAttr?.value as String?) ?? _defaultWidth;

    return _ResizableImage(
      imagePath: imagePath,
      initialWidth: width,
      readOnly: readOnly,
      onWidthChanged: (newWidth) {
        controller.formatText(
          node.documentOffset,
          1,
          StyleAttribute('width:$newWidth'),
        );
      },
      onDelete: readOnly
          ? null
          : () {
              controller.replaceText(
                node.documentOffset,
                1,
                '',
                TextSelection.collapsed(offset: node.documentOffset),
              );
            },
    );
  }
}

// ---------------------------------------------------------------------------
// Resizable image widget
// ---------------------------------------------------------------------------

class _ResizableImage extends StatefulWidget {
  const _ResizableImage({
    required this.imagePath,
    required this.initialWidth,
    required this.readOnly,
    required this.onWidthChanged,
    required this.onDelete,
  });

  final String imagePath;
  final double initialWidth;
  final bool readOnly;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback? onDelete;

  @override
  State<_ResizableImage> createState() => _ResizableImageState();
}

class _ResizableImageState extends State<_ResizableImage> {
  late double _width;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  @override
  void didUpdateWidget(_ResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWidth != widget.initialWidth) {
      _width = widget.initialWidth;
    }
  }

  Widget _buildImage() {
    final path = widget.imagePath;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: _width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildBroken(),
      );
    }
    if (!kIsWeb) {
      final cleanPath = path.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: _width,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildBroken(),
        );
      }
    }
    return _buildBroken();
  }

  Widget _buildBroken() {
    return Container(
      width: _width,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child:
            Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
      ),
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _width = (_width + details.delta.dx)
          .clamp(ImageEmbedBuilder._minWidth, 1200.0);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    widget.onWidthChanged(_width);
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = GestureDetector(
      onTap: widget.readOnly
          ? null
          : () => setState(() => _selected = !_selected),
      child: _buildImage(),
    );

    if (widget.readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: imageWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        alignment: Alignment.centerRight,
        fit: StackFit.passthrough,
        children: [
          imageWidget,
          if (_selected) ...[
            // Right-edge drag handle for resizing
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.75),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: const Icon(Icons.drag_handle,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
            // Delete button
            if (widget.onDelete != null)
              Positioned(
                top: 0,
                right: 22,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home-page thumbnail helper
// ---------------------------------------------------------------------------

/// Returns the path/URL of the first image embedded in a quill JSON string,
/// or null if there is none.
String? firstImagePath(String quillJson) {
  if (quillJson.isEmpty) return null;
  try {
    final dynamic decoded = jsonDecode(quillJson);
    if (decoded is! List) return null;
    for (final op in decoded) {
      if (op is Map) {
        final insert = op['insert'];
        if (insert is Map && insert['image'] is String) {
          return insert['image'] as String;
        }
      }
    }
  } catch (_) {}
  return null;
}

/// Builds a compact image thumbnail widget suitable for the home-page list.
Widget buildNoteImageThumbnail(String imagePath,
    {double size = 56, BorderRadius? borderRadius}) {
  borderRadius ??= BorderRadius.circular(6);
  Widget img;

  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    img = Image.network(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, size: 24),
    );
  } else if (!kIsWeb) {
    final cleanPath = imagePath.replaceFirst('file://', '');
    final file = File(cleanPath);
    if (file.existsSync()) {
      img = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_outlined, size: 24),
      );
    } else {
      img = const Icon(Icons.image_not_supported_outlined, size: 24);
    }
  } else {
    img = const Icon(Icons.image_outlined, size: 24);
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(width: size, height: size, child: img),
  );
}
