import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      margin: const EdgeInsets.only(top: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // TODO implement exporting, also later on add encryption
              const Text('Export Notes'),
              ElevatedButton(
                  onPressed: () {},
                  child: const Icon(
                    Icons.save_alt,
                  ))
            ],
          )
        ],
      ),
    );
  }
}
