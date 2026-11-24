import 'dart:convert';

import 'package:notel/infrastructure/note.dart';

enum ActivityLogAction { start, stop }

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.noteId,
    required this.activityName,
    required this.activity,
    required this.action,
    required this.timestamp,
    required this.hasExplicitTime,
    required this.lineIndex,
  });

  final int noteId;
  final String activityName;
  final String activity;
  final ActivityLogAction action;
  final DateTime timestamp;
  final bool hasExplicitTime;
  final int lineIndex;

  String get activityKey => activityName.toLowerCase();
  String get activityLabelKey => activity.toLowerCase();

  static final _linePattern = RegExp(
    r'^\s*(?:(\d{1,2}):(\d{2})\s+)?(start|stop)\s+([^\s]+)(?:\s+(.*?))?\s*$',
    caseSensitive: false,
  );
  static final _quantityPattern = RegExp(r'^(\d+(?:[.,]\d+)?)([a-zA-Zµμ%]+)?$');
  static const _quantityUnits = {
    'mg',
    'g',
    'mcg',
    'µg',
    'μg',
    'ug',
    'ml',
    'l',
    'mmol',
    'iu',
    'ie',
    '%',
  };

  static List<ActivityLogEntry> fromNote(Note note) {
    final lines = _plainText(note.displayText).split('\n');
    final entries = <ActivityLogEntry>[];

    for (var index = 0; index < lines.length; index++) {
      final match = _linePattern.firstMatch(lines[index]);
      if (match == null) continue;

      final hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');
      if (hour != null && (hour > 23 || minute == null || minute > 59)) {
        continue;
      }

      final noteDate = note.date.toDateTime();
      final modified = note.lastModified;
      final fallbackTime = modified != null &&
              modified.year == noteDate.year &&
              modified.month == noteDate.month &&
              modified.day == noteDate.day
          ? modified
          : noteDate;
      final timestamp = hour == null
          ? fallbackTime
          : DateTime(
              noteDate.year, noteDate.month, noteDate.day, hour, minute!);
      final activityName = match.group(4)!;
      final quantity = _extractQuantity(match.group(5));

      entries.add(ActivityLogEntry(
        noteId: note.id,
        activityName: activityName,
        activity: quantity == null ? activityName : '$activityName $quantity',
        action: match.group(3)!.toLowerCase() == 'start'
            ? ActivityLogAction.start
            : ActivityLogAction.stop,
        timestamp: timestamp,
        hasExplicitTime: hour != null,
        lineIndex: index,
      ));
    }

    return entries;
  }

  static String? _extractQuantity(String? trailingText) {
    if (trailingText == null || trailingText.isEmpty) return null;
    final tokens = trailingText.split(RegExp(r'\s+'));

    for (var index = 0; index < tokens.length; index++) {
      final match = _quantityPattern.firstMatch(tokens[index]);
      if (match == null) continue;

      final amount = match.group(1)!;
      final attachedUnit = match.group(2);
      if (attachedUnit != null) {
        return _quantityUnits.contains(attachedUnit.toLowerCase())
            ? '$amount$attachedUnit'
            : amount;
      }

      if (index + 1 < tokens.length &&
          _quantityUnits.contains(tokens[index + 1].toLowerCase())) {
        return '$amount ${tokens[index + 1]}';
      }
      return amount;
    }

    return null;
  }

  static String _plainText(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((operation) => operation['insert'])
            .whereType<String>()
            .join();
      }
    } on FormatException {
      return text;
    }
    return text;
  }
}
