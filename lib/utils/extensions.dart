extension DateTimeExtensions on DateTime {
  bool isSameDate(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension StringExtensions on String {
  bool isEmptyOrWhitespace() => trim().isEmpty;
}

extension NullStringExtensions on String? {
  bool isNullOrWhitespace() => this == null || this!.isEmptyOrWhitespace();
}
