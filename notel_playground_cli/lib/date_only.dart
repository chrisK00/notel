/// A date-only value class with no time-of-day component.
///
/// Used for note creation dates where the time is irrelevant.
/// Stored in the DB as "yyyy-MM-dd" (e.g. "2025-08-26").
class DateOnly implements Comparable<DateOnly> {
  final int year;
  final int month;
  final int day;

  const DateOnly(this.year, this.month, this.day);

  factory DateOnly.fromDateTime(DateTime dt) =>
      DateOnly(dt.year, dt.month, dt.day);

  factory DateOnly.today() {
    final now = DateTime.now();
    return DateOnly(now.year, now.month, now.day);
  }

  /// Parses from "yyyy-MM-dd" or falls back to parsing a full DateTime string
  /// (for backwards compatibility with existing DB rows that stored full timestamps).
  factory DateOnly.parse(String s) {
    final trimmed = s.trim();
    // Try strict date-only format first.
    final parts = trimmed.split('-');
    if (parts.length == 3 && parts[2].length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateOnly(year, month, day);
      }
    }
    // Fall back to DateTime.parse for existing full-timestamp rows.
    final dt = DateTime.parse(trimmed);
    return DateOnly(dt.year, dt.month, dt.day);
  }

  /// Serialises to "yyyy-MM-dd" for DB storage.
  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Converts to a [DateTime] at midnight (for use with date pickers and formatters).
  DateTime toDateTime() => DateTime(year, month, day);

  bool isSameDay(DateOnly other) =>
      year == other.year && month == other.month && day == other.day;

  bool isToday() => isSameDay(DateOnly.today());

  @override
  int compareTo(DateOnly other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
