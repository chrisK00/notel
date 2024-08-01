import 'package:flutter/material.dart';

class SaveChangesDialog extends StatelessWidget {
  const SaveChangesDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text("Save changes?"),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Container(
            color: const Color.fromARGB(255, 231, 104, 93),
            child: SimpleDialogOption(
              child: const Text('ignore'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          Container(
            color: const Color.fromARGB(255, 144, 214, 223),
            child: SimpleDialogOption(
              child: const Text('Save'),
              onPressed: () => Navigator.pop(context, true),
            ),
          )
        ])
      ],
    );
  }
}
