import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

class ExerciseDetails {
  const ExerciseDetails({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.notes,
  });

  final String name;
  final String sets;
  final String reps;
  final String weight;
  final String notes;

  Map<String, String> toJson() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'notes': notes,
      };

  factory ExerciseDetails.fromJsonString(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['name'] is! String) {
      throw const FormatException('Invalid exercise card');
    }

    String read(String key) =>
        decoded[key] is String ? decoded[key] as String : '';

    return ExerciseDetails(
      name: read('name'),
      sets: read('sets'),
      reps: read('reps'),
      weight: read('weight'),
      notes: read('notes'),
    );
  }
}

Future<ExerciseDetails?> showExerciseDialog(
  BuildContext context, {
  ExerciseDetails? initial,
}) {
  return showDialog<ExerciseDetails>(
    context: context,
    builder: (context) => _ExerciseDialog(initial: initial),
  );
}

class ExerciseEmbedBuilder extends EmbedBuilder {
  const ExerciseEmbedBuilder();

  static const type = 'exercise-card';

  @override
  String get key => type;

  @override
  String toPlainText(Embed node) {
    final exercise = ExerciseDetails.fromJsonString(node.value.data);
    return [
      exercise.name,
      if (exercise.sets.isNotEmpty) '${exercise.sets} sets',
      if (exercise.reps.isNotEmpty) '${exercise.reps} reps',
      if (exercise.weight.isNotEmpty) exercise.weight,
      if (exercise.notes.isNotEmpty) exercise.notes,
    ].join(' ');
  }

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final exercise = ExerciseDetails.fromJsonString(node.value.data);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!readOnly)
              IconButton(
                tooltip: 'Edit exercise',
                onPressed: () async {
                  final updated = await showExerciseDialog(
                    context,
                    initial: exercise,
                  );
                  if (updated == null) return;
                  final replacement = Delta()
                    ..insert({type: jsonEncode(updated.toJson())});
                  controller.replaceText(
                    node.documentOffset,
                    1,
                    replacement,
                    TextSelection.collapsed(offset: node.documentOffset + 1),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise.sets.isNotEmpty || exercise.reps.isNotEmpty)
                  Text([
                    if (exercise.sets.isNotEmpty) '${exercise.sets} sets',
                    if (exercise.reps.isNotEmpty) '${exercise.reps} reps',
                  ].join(' × ')),
                if (exercise.weight.isNotEmpty)
                  Text('Weight: ${exercise.weight}'),
                if (exercise.notes.isNotEmpty) Text(exercise.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({this.initial});

  final ExerciseDetails? initial;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name);
    _setsController = TextEditingController(text: widget.initial?.sets);
    _repsController = TextEditingController(text: widget.initial?.reps);
    _weightController = TextEditingController(text: widget.initial?.weight);
    _notesController = TextEditingController(text: widget.initial?.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(ExerciseDetails(
      name: name,
      sets: _setsController.text.trim(),
      reps: _repsController.text.trim(),
      weight: _weightController.text.trim(),
      notes: _notesController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add exercise' : 'Edit exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('exercise-name'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Exercise'),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('exercise-sets'),
                    controller: _setsController,
                    decoration: const InputDecoration(labelText: 'Sets'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('exercise-reps'),
                    controller: _repsController,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('exercise-weight'),
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Weight'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              key: const ValueKey('exercise-notes'),
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
