import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notel/infrastructure/note_comment.dart';
import 'package:notel/infrastructure/note_comment_repository.dart';

class CommentThreadsSheet extends StatefulWidget {
  const CommentThreadsSheet({
    super.key,
    required this.noteId,
    required this.quotedText,
    required this.startOffset,
    required this.endOffset,
  });

  final int noteId;
  final String quotedText;
  final int startOffset;
  final int endOffset;

  @override
  State<CommentThreadsSheet> createState() => _CommentThreadsSheetState();
}

class _CommentThreadsSheetState extends State<CommentThreadsSheet> {
  final _commentController = TextEditingController();
  List<NoteComment> _comments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final comments = await NoteCommentRepository.forNote(widget.noteId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load comments: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (widget.quotedText.trim().isEmpty || body.isEmpty) return;
    try {
      await NoteCommentRepository.create(
        noteId: widget.noteId,
        quotedText: widget.quotedText.trim(),
        startOffset: widget.startOffset,
        endOffset: widget.endOffset,
        body: body,
      );
      if (!mounted) return;
      _commentController.clear();
      await _loadComments();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not add comment: $error');
    }
  }

  Future<void> _replyTo(NoteComment parent) async {
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => const _ReplyDialog(),
    );
    if (!mounted || reply == null) return;

    try {
      await NoteCommentRepository.create(
        noteId: widget.noteId,
        parentId: parent.id,
        quotedText: parent.quotedText,
        startOffset: parent.startOffset,
        endOffset: parent.endOffset,
        body: reply,
      );
      await _loadComments();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not add reply: $error');
    }
  }

  List<NoteComment> _repliesFor(NoteComment parent) => _comments
      .where((comment) => comment.parentId == parent.id)
      .toList(growable: false);

  Widget _thread(NoteComment comment) {
    final replies = _repliesFor(comment);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${comment.quotedText.trim()}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(comment.body),
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reply.body)),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('reply-to-comment'),
                onPressed: () => _replyTo(comment),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = _comments
        .where((comment) => comment.parentId == null)
        .toList(growable: false);
    final media = MediaQuery.of(context);
    final height = math.min(
      media.size.height * 0.75,
      math.max(260.0, media.size.height - media.viewInsets.bottom - 40),
    );
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('${threads.length}'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _loadComments,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : threads.isEmpty
                          ? const Center(child: Text('No comment threads yet.'))
                          : ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              children: threads.map(_thread).toList(),
                            ),
            ),
            if (widget.quotedText.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text('Select text in the note to start a comment.'),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comment on “${widget.quotedText.trim()}”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('new-comment'),
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Post comment',
                          onPressed: _commentController.text.trim().isEmpty
                              ? null
                              : _addComment,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog();

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final reply = _controller.text.trim();
    if (reply.isNotEmpty) Navigator.pop(context, reply);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reply'),
      content: TextField(
        key: const ValueKey('comment-reply'),
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'Write a reply'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _send(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('send-comment-reply'),
          onPressed: _controller.text.trim().isEmpty ? null : _send,
          child: const Text('Reply'),
        ),
      ],
    );
  }
}
