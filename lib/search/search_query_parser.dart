import 'search_query.dart';

/// Parses a raw search string into a [SearchQuery].
///
/// Supported syntax:
///   title:value               — match note title (bare word or quoted)
///   title:'my note'           — multi-word title match
///   date:2025-01-01           — exact date
///   date:2025-01-01..2025-06-01 — date range
///   date:>2025-01-01          — on or after date
///   date:<2025-01-01          — on or before date
///   date:2025                 — whole year  (expands to 2025-01-01..2025-12-31)
///   date:2025-08              — whole month (expands to 2025-08-01..2025-08-31)
///   startswith:'start zol'    — body starts with value (quote for multi-word)
///   'phrase'                  — body or title contains phrase
///   word                      — body or title contains word
///   term1 || term2            — OR between terms/phrases
///
/// Terms separated by spaces (without ||) form AND groups.
/// Terms separated by || form OR groups within an AND group.
class SearchQueryParser {
  static SearchQuery parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return const SearchQuery();

    final titleTerms = <String>[];
    final startsWithTerms = <String>[];
    DateTime? dateFrom;
    DateTime? dateTo;
    DateTime? modifiedFrom;
    DateTime? modifiedTo;
    final textOrGroups = <List<String>>[];
    final excludeTerms = <String>[];

    final tokens = _tokenise(input);
    final segments = _splitOnOr(tokens);

    for (final segment in segments) {
      final orPhrases = <String>[];

      for (final token in segment) {
        if (_tryParseTitle(token, (v) => titleTerms.add(v))) continue;
        if (_tryParseStartsWith(token, (v) => startsWithTerms.add(v))) continue;
        if (_tryParseDate(token, (from, to) {
          dateFrom = from;
          dateTo = to;
        })) {
          continue;
        }
        if (_tryParseModified(token, (from, to) {
          modifiedFrom = from;
          modifiedTo = to;
        })) {
          continue;
        }
        if (_tryParseExclude(token, (v) => excludeTerms.add(v))) continue;
        if (_tryParseContains(token, (groups) => textOrGroups.addAll(groups))) continue;

        String phrase;
        if (token.startsWith('contains:')) {
          phrase = _unquote(token.substring(9).trim());
        } else {
          phrase = _unquote(token);
        }

        if (phrase.isNotEmpty) {
          orPhrases.add(phrase);
        }
      }

      if (orPhrases.isNotEmpty) {
        textOrGroups.add(orPhrases);
      }
    }

    return SearchQuery(
      titleTerms: titleTerms,
      startsWithTerms: startsWithTerms,
      dateFrom: dateFrom,
      dateTo: dateTo,
      modifiedFrom: modifiedFrom,
      modifiedTo: modifiedTo,
      textOrGroups: textOrGroups,
      excludeTerms: excludeTerms,
    );
  }

  // ── Tokeniser ──────────────────────────────────────────────────────────────

  /// Splits input into tokens respecting single-quoted strings.
  ///
  /// Special handling for field prefixes (title:, startswith:, date:):
  ///   - If the value after `:` starts with `'`, the quoted string is consumed
  ///     as part of the same token, e.g. `title:'my note'` → one token.
  ///   - Otherwise everything up to the next space is the value.
  ///
  /// The literal `||` becomes its own token.
  static List<String> _tokenise(String input) {
    final tokens = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    var i = 0;

    while (i < input.length) {
      final ch = input[i];

      if (ch == "'") {
        if (inQuote) {
          // Closing quote — flush the quoted token (including surrounding quotes).
          buf.write(ch);
          tokens.add(buf.toString());
          buf.clear();
          inQuote = false;
        } else {
          // Check if we're inside a field value (buf ends with 'prefix:' or '-').
          final pending = buf.toString();
          if (_isFieldPrefix(pending) || pending == '-') {
            // e.g. buf = "title:" or "-" — continue building this token with the quote.
            buf.write(ch);
            inQuote = true;
          } else {
            // Standalone quoted phrase — flush bare word first.
            final trimmed = pending.trim();
            if (trimmed.isNotEmpty) tokens.add(trimmed);
            buf.clear();
            buf.write(ch);
            inQuote = true;
          }
        }
        i++;
        continue;
      }

      if (inQuote) {
        buf.write(ch);
        i++;
        continue;
      }

      // Check for "contains("
      if (ch == '(' && buf.toString().trim() == 'contains') {
        buf.write(ch);
        i++;
        var depth = 1;
        var parenInQuote = false;
        while (i < input.length && depth > 0) {
          final c = input[i];
          if (c == "'") {
            parenInQuote = !parenInQuote;
          } else if (!parenInQuote) {
            if (c == '(') depth++;
            if (c == ')') depth--;
          }
          buf.write(c);
          i++;
        }
        tokens.add(buf.toString().trim());
        buf.clear();
        continue;
      }

      // Check for "||"
      if (ch == '|' && i + 1 < input.length && input[i + 1] == '|') {
        final pending = buf.toString().trim();
        if (pending.isNotEmpty) tokens.add(pending);
        buf.clear();
        tokens.add('||');
        i += 2;
        continue;
      }

      // Check for "&&"
      if (ch == '&' && i + 1 < input.length && input[i + 1] == '&') {
        final pending = buf.toString().trim();
        if (pending.isNotEmpty) tokens.add(pending);
        buf.clear();
        tokens.add('&&');
        i += 2;
        continue;
      }

      if (ch == ' ' || ch == '\t') {
        final pending = buf.toString().trim();
        if (pending.isNotEmpty) tokens.add(pending);
        buf.clear();
        i++;
        continue;
      }

      buf.write(ch);
      i++;
    }

    final remaining = buf.toString().trim();
    if (remaining.isNotEmpty) tokens.add(remaining);

    return tokens;
  }

  static bool _isFieldPrefix(String s) {
    return s == 'title:' ||
        s == 'startswith:' ||
        s == 'date:' ||
        s == 'modified:' ||
        s == 'contains:';
  }

  /// Groups tokens by `||` separator into OR segments.
  static List<List<String>> _splitOnOr(List<String> tokens) {
    final result = <List<String>>[];
    var currentOrGroup = <String>[];
    var expectOrContinuation = false;

    for (final token in tokens) {
      if (token == '&&') {
        if (currentOrGroup.isNotEmpty) {
          result.add(List.unmodifiable(currentOrGroup));
          currentOrGroup = [];
        }
        expectOrContinuation = false;
        continue;
      }

      if (token == '||') {
        expectOrContinuation = true;
        continue;
      }

      final isNonOrField = _isNonOrFieldToken(token);

      if (expectOrContinuation && !isNonOrField && currentOrGroup.isNotEmpty) {
        currentOrGroup.add(token);
        expectOrContinuation = false;
      } else {
        if (currentOrGroup.isNotEmpty) {
          result.add(List.unmodifiable(currentOrGroup));
          currentOrGroup = [];
        }
        expectOrContinuation = false;
        if (isNonOrField) {
          result.add([token]);
        } else {
          currentOrGroup.add(token);
        }
      }
    }

    if (currentOrGroup.isNotEmpty) {
      result.add(List.unmodifiable(currentOrGroup));
    }

    return result;
  }

  static bool _isNonOrFieldToken(String token) {
    return token.startsWith('date:') ||
        token.startsWith('modified:') ||
        (token.startsWith('contains(') && token.endsWith(')')) ||
        _isExcludeToken(token);
  }

  static bool _isExcludeToken(String token) {
    if (!token.startsWith('-') || token.length < 2) return false;
    final rest = token.substring(1);
    // Must be -word or -'phrase', not a negative number or bare dash.
    return rest.startsWith("'") || RegExp(r'^[a-zA-ZåäöÅÄÖ\w]').hasMatch(rest);
  }

  // ── Field parsers ──────────────────────────────────────────────────────────

  static bool _tryParseTitle(String token, void Function(String) onResult) {
    if (!token.startsWith('title:')) return false;
    final value = _unquote(token.substring(6).trim());
    if (value.isNotEmpty) onResult(value);
    return true;
  }

  static bool _tryParseStartsWith(String token, void Function(String) onResult) {
    if (!token.startsWith('startswith:')) return false;
    final value = _unquote(token.substring(11).trim());
    if (value.isNotEmpty) onResult(value);
    return true;
  }

  /// Parses exclusion tokens: -word or -'multi word phrase'.
  static bool _tryParseExclude(String token, void Function(String) onResult) {
    if (!_isExcludeToken(token)) return false;
    final value = _unquote(token.substring(1));
    if (value.isNotEmpty) onResult(value);
    return true;
  }

  /// Parses modified: tokens — same date syntax as date: but targets lastModified.
  static bool _tryParseModified(
      String token, void Function(DateTime from, DateTime to) onResult) {
    if (!token.startsWith('modified:')) return false;
    // Reuse date parsing by substituting the prefix.
    return _tryParseDate('date:${token.substring(9)}', onResult);
  }

  static bool _tryParseDate(
      String token, void Function(DateTime from, DateTime to) onResult) {
    if (!token.startsWith('date:')) return false;
    final value = token.substring(5).trim();

    // Range: date:2025-01-01..2025-06-01
    if (value.contains('..')) {
      final parts = value.split('..');
      if (parts.length == 2) {
        final from = _parseDate(parts[0]);
        final to = _parseDate(parts[1]);
        if (from != null && to != null) {
          onResult(from, _endOfDay(to));
        }
      }
      return true;
    }

    // After: date:>2025-01-01
    if (value.startsWith('>')) {
      final d = _parseDate(value.substring(1));
      if (d != null) onResult(d, DateTime(9999));
      return true;
    }

    // Before: date:<2025-01-01
    if (value.startsWith('<')) {
      final d = _parseDate(value.substring(1));
      if (d != null) onResult(DateTime(0), _endOfDay(d));
      return true;
    }

    // Whole year: date:2025
    if (RegExp(r'^\d{4}$').hasMatch(value)) {
      final year = int.parse(value);
      onResult(DateTime(year, 1, 1), DateTime(year, 12, 31, 23, 59, 59));
      return true;
    }

    // Whole month: date:2025-08
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
      final parts = value.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final lastDay = DateTime(year, month + 1, 0).day;
      onResult(DateTime(year, month, 1), DateTime(year, month, lastDay, 23, 59, 59));
      return true;
    }

    // Exact date: date:2025-01-01
    final d = _parseDate(value);
    if (d != null) {
      onResult(d, _endOfDay(d));
      return true;
    }

    return true; // consumed even if unparseable
  }

  /// Parses contains(...) constructs.
  /// Supports:
  ///   contains(a, b) -> AND groups [['a'], ['b']]
  ///   contains(a | b) or contains(a || b) -> OR group [['a', 'b']]
  ///   contains('phrase 1', 'phrase 2') -> quotes respected
  static bool _tryParseContains(
      String token, void Function(List<List<String>>) onResult) {
    if (!token.startsWith('contains(') || !token.endsWith(')')) return false;
    final inner = token.substring(9, token.length - 1).trim();
    if (inner.isEmpty) return true;

    final groups = _parseContainsInner(inner);
    if (groups.isNotEmpty) {
      onResult(groups);
    }
    return true;
  }

  static List<List<String>> _parseContainsInner(String inner) {
    final groups = <List<String>>[];
    // Split on ',' or '&&' outside quotes for AND groups
    final andChunks = _splitRespectingQuotes(inner, {',', '&&'});

    for (final chunk in andChunks) {
      // Split each chunk on '|' or '||' outside quotes for OR alternatives
      final orPieces = _splitRespectingQuotes(chunk, {'||', '|'});
      final orPhrases = <String>[];
      for (final piece in orPieces) {
        final unquoted = _unquote(piece.trim());
        if (unquoted.isNotEmpty) {
          orPhrases.add(unquoted);
        }
      }
      if (orPhrases.isNotEmpty) {
        groups.add(orPhrases);
      }
    }
    return groups;
  }

  static List<String> _splitRespectingQuotes(String input, Set<String> delimiters) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    var i = 0;

    while (i < input.length) {
      final ch = input[i];

      if (ch == "'") {
        inQuote = !inQuote;
        buf.write(ch);
        i++;
        continue;
      }

      if (!inQuote) {
        // Check 2-character delimiter first
        if (i + 1 < input.length) {
          final twoChar = input.substring(i, i + 2);
          if (delimiters.contains(twoChar)) {
            final trimmed = buf.toString().trim();
            if (trimmed.isNotEmpty) result.add(trimmed);
            buf.clear();
            i += 2;
            continue;
          }
        }
        // Check 1-character delimiter
        if (delimiters.contains(ch)) {
          final trimmed = buf.toString().trim();
          if (trimmed.isNotEmpty) result.add(trimmed);
          buf.clear();
          i++;
          continue;
        }
      }

      buf.write(ch);
      i++;
    }

    final remaining = buf.toString().trim();
    if (remaining.isNotEmpty) result.add(remaining);

    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime? _parseDate(String s) {
    try {
      return DateTime.parse(s.trim());
    } catch (_) {
      return null;
    }
  }

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  /// Strips surrounding single quotes from a token if present.
  static String _unquote(String s) {
    if (s.startsWith("'") && s.endsWith("'") && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }
}
