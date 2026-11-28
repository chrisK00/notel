import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';

enum NoteAttachmentType { link, image }

class NoteAttachment {
  const NoteAttachment({
    required this.type,
    required this.value,
    required this.label,
  });

  final NoteAttachmentType type;
  final String value;
  final String label;

  static List<NoteAttachment> fromDocument(Document document) {
    final attachments = <NoteAttachment>[];
    final seen = <String>{};

    for (final operation in document.toDelta().toList()) {
      final attributes = operation.attributes;
      final link = attributes?[Attribute.link.key];
      if (link is String && link.isNotEmpty && operation.data is String) {
        final label = (operation.data as String).trim();
        final key = 'link:$link';
        if (seen.add(key)) {
          attachments.add(NoteAttachment(
            type: NoteAttachmentType.link,
            value: link,
            label: label.isEmpty ? link : label,
          ));
        }
      } else if (operation.data is String) {
        final text = operation.data as String;
        final matches = RegExp(r'https?://[^\s<>"{}|\\^`]+').allMatches(text);
        for (final m in matches) {
          final url = m.group(0)!;
          if (seen.add('link:$url')) {
            attachments.add(NoteAttachment(
              type: NoteAttachmentType.link,
              value: url,
              label: url,
            ));
          }
        }
      }

      final data = operation.data;
      if (data is Map && data['image'] is String) {
        final image = data['image'] as String;
        if (image.isNotEmpty && seen.add('image:$image')) {
          attachments.add(NoteAttachment(
            type: NoteAttachmentType.image,
            value: image,
            label: image,
          ));
        }
      }
    }
    return attachments;
  }
}

class NoteAttachmentsSheet extends StatelessWidget {
  const NoteAttachmentsSheet({
    super.key,
    required this.document,
  });

  final Document document;

  Future<void> _open(BuildContext context, NoteAttachment attachment) async {
    if (attachment.type == NoteAttachmentType.image) {
      final val = attachment.value;
      final isNetwork = val.startsWith('http://') || val.startsWith('https://');
      if (isNetwork) {
        final uri = Uri.tryParse(val);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          return;
        }
      }
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNetwork)
                  Image.network(
                    val,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  )
                else if (!kIsWeb && File(val.replaceFirst('file://', '')).existsSync())
                  Image.file(
                    File(val.replaceFirst('file://', '')),
                    fit: BoxFit.contain,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.image_not_supported, size: 48),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    final uri = Uri.tryParse(attachment.value);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open attachment.')),
        );
      }
    }
  }

  Widget _buildLeading(NoteAttachment attachment) {
    if (attachment.type == NoteAttachmentType.image) {
      final val = attachment.value;
      final isNetwork = val.startsWith('http://') || val.startsWith('https://');
      Widget imgWidget;
      if (isNetwork) {
        imgWidget = Image.network(
          val,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      } else if (!kIsWeb && File(val.replaceFirst('file://', '')).existsSync()) {
        imgWidget = Image.file(
          File(val.replaceFirst('file://', '')),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
        );
      } else {
        imgWidget = const Icon(Icons.image_outlined);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(width: 40, height: 40, child: imgWidget),
      );
    }
    return const Icon(Icons.link);
  }

  @override
  Widget build(BuildContext context) {
    final attachments = NoteAttachment.fromDocument(document);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attachments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('${attachments.length}'),
                ],
              ),
            ),
            Expanded(
              child: attachments.isEmpty
                  ? const Center(
                      child: Text('No links or images in this note yet.'),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: attachments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final attachment = attachments[index];
                        final isImage = attachment.type == NoteAttachmentType.image;
                        return ListTile(
                          key: ValueKey('attachment-${attachment.value}'),
                          leading: _buildLeading(attachment),
                          title: Text(
                            attachment.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            isImage ? 'Image' : attachment.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => _open(context, attachment),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
