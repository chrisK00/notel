DateTime _addMonths(DateTime date, int months) {
  final firstOfNextMonth = DateTime.utc(date.year, date.month + months, 1);
  final lastDayOfNextMonth =
      DateTime.utc(firstOfNextMonth.year, firstOfNextMonth.month + 1, 0).day;
  final day = date.day < lastDayOfNextMonth ? date.day : lastDayOfNextMonth;
  return DateTime.utc(firstOfNextMonth.year, firstOfNextMonth.month, day);
}

String _joinPeriodParts(List<String> parts) {
  if (parts.length == 1) return parts.single;
  if (parts.length == 2) return '${parts[0]} och ${parts[1]}';
  return '${parts.take(parts.length - 1).join(', ')} och ${parts.last}';
}

String calendarDayDistanceLabel(DateTime selectedDay, DateTime today) {
  final selectedDate =
      DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
  final currentDate = DateTime.utc(today.year, today.month, today.day);
  final days = selectedDate.difference(currentDate).inDays;

  if (days == 0) return 'Idag';
  if (days == 1) return 'Om 1 dag';

  final earlierDate = days < 0 ? selectedDate : currentDate;
  final laterDate = days < 0 ? currentDate : selectedDate;
  var months = 0;
  while (true) {
    if (_addMonths(earlierDate, months + 1).isAfter(laterDate)) break;
    months += 1;
  }
  final cursor = _addMonths(earlierDate, months);
  final remainingDays = laterDate.difference(cursor).inDays;
  final parts = <String>[];

  if (months > 0) {
    parts.add('$months ${months == 1 ? 'månad' : 'månader'}');
  }

  final weeks = remainingDays ~/ 7;
  final daysAfterWeeks = remainingDays % 7;
  if (weeks > 0) {
    parts.add('$weeks ${weeks == 1 ? 'vecka' : 'veckor'}');
  }
  if (daysAfterWeeks > 0) {
    parts.add('$daysAfterWeeks ${daysAfterWeeks == 1 ? 'dag' : 'dagar'}');
  }

  final period = _joinPeriodParts(parts);
  return days < 0 ? '$period sedan' : 'Om $period';
}
