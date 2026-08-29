/// Represents a parsed search query.
///
/// Examples of raw input and what they produce:
///   "zoloft"                              → textOrGroups: [['zoloft']]
///   "'start zoloft' || 'stop zoloft'"    → textOrGroups: [['start zoloft', 'stop zoloft']]
///   "title:zoloft"                        → titleTerm: 'zoloft'
///   "date:2025-01-01..2025-06-01"         → dateFrom/dateTo set
///   "date:>2025-01-01"                    → dateFrom set
///   "date:<2025-01-01"                    → dateTo set
///   "date:2025-01-01"                     → exact: dateFrom == dateTo
///   "startswith:'start zol'"              → startsWithTerm: 'start zol'
///   "-headache"                           → excludeTerms: ['headache']
///   "-'bad day'"                          → excludeTerms: ['bad day']
///   "modified:>2025-08-01"                → modifiedFrom set
///   "modified:2025-08"                    → modifiedFrom/modifiedTo for whole month
///
/// textOrGroups is a list of OR-groups. Each group is a list of phrases
/// that are OR'd together. Groups themselves are AND'd.
/// e.g. "'a' || 'b' 'c'" → [['a','b'], ['c']]
///
/// excludeTerms are AND'd — all must be absent from both title and body.
class SearchQuery {
  final List<String> titleTerms;
  final List<String> startsWithTerms;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final DateTime? modifiedFrom;
  final DateTime? modifiedTo;

  String? get titleTerm => titleTerms.isNotEmpty ? titleTerms.first : null;
  String? get startsWithTerm => startsWithTerms.isNotEmpty ? startsWithTerms.first : null;

  /// Each inner list is an OR group of phrases. Inner lists are AND'd together.
  final List<List<String>> textOrGroups;

  /// Terms that must NOT appear in the note (title or body).
  final List<String> excludeTerms;

  const SearchQuery({
    this.titleTerms = const [],
    this.startsWithTerms = const [],
    this.dateFrom,
    this.dateTo,
    this.modifiedFrom,
    this.modifiedTo,
    this.textOrGroups = const [],
    this.excludeTerms = const [],
  });

  bool get isEmpty =>
      titleTerms.isEmpty &&
      startsWithTerms.isEmpty &&
      dateFrom == null &&
      dateTo == null &&
      modifiedFrom == null &&
      modifiedTo == null &&
      textOrGroups.isEmpty &&
      excludeTerms.isEmpty;

  @override
  String toString() =>
      'SearchQuery(title=$titleTerm, startswith=$startsWithTerm, '
      'from=$dateFrom, to=$dateTo, modifiedFrom=$modifiedFrom, '
      'modifiedTo=$modifiedTo, text=$textOrGroups, exclude=$excludeTerms)';
}
