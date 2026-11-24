import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notel/infrastructure/category_icons.dart';

class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: CategoryIcons.all.entries.map((entry) {
        final selected = entry.key == selectedKey;
        return IconButton(
          tooltip: entry.key.replaceAll('_', ' '),
          onPressed: () => onSelected(entry.key),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            minimumSize: const Size(44, 44),
          ),
          icon: Icon(entry.value),
        );
      }).toList(),
    );
  }
}

class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({
    super.key,
    required this.selectedColor,
    required this.onSelected,
  });

  final int? selectedColor;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final color = selectedColor == null ? themeColor : Color(selectedColor!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorPicker(
          pickerColor: color,
          onColorChanged: (color) {
            // Color.value supports the Flutter 3.24 SDK used by CI.
            // ignore: deprecated_member_use
            onSelected(color.value);
          },
          colorPickerWidth: 260,
          pickerAreaHeightPercent: 0.65,
          enableAlpha: false,
          displayThumbColor: true,
          labelTypes: const [],
          paletteType: PaletteType.hsv,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: selectedColor == null ? null : () => onSelected(null),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to default'),
          ),
        ),
      ],
    );
  }
}
