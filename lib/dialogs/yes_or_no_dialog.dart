import 'package:flutter/material.dart';

class YesOrNoDialog extends StatelessWidget {
  const YesOrNoDialog(
      {super.key,
      required this.title,
      required this.successBtnText,
      required this.dangerBtnText});

  final String title;
  final String successBtnText;
  final String dangerBtnText;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Container(
            color: const Color.fromARGB(255, 231, 104, 93),
            child: SimpleDialogOption(
              child: Text(dangerBtnText),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primary.withGreen(120),
            child: SimpleDialogOption(
              child: Text(successBtnText),
              onPressed: () => Navigator.pop(context, true),
            ),
          )
        ])
      ],
    );
  }
}
