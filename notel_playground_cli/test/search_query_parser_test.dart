import 'package:test/test.dart';
import 'package:notel_playground_cli/search/search_query_parser.dart';

void main() {
  group('SearchQueryParser', () {
    // ── Empty / trivial ───────────────────────────────────────────────────────

    test('empty string returns empty query', () {
      final q = SearchQueryParser.parse('');
      expect(q.isEmpty, isTrue);
    });

    test('whitespace-only string returns empty query', () {
      final q = SearchQueryParser.parse('   ');
      expect(q.isEmpty, isTrue);
    });

    // ── Plain text terms ──────────────────────────────────────────────────────

    test('single bare word becomes one text group', () {
      final q = SearchQueryParser.parse('zoloft');
      expect(q.textOrGroups, equals([['zoloft']]));
    });

    test('two bare words become two separate AND groups', () {
      final q = SearchQueryParser.parse('zoloft headache');
      expect(q.textOrGroups, equals([['zoloft'], ['headache']]));
    });

    test('quoted phrase becomes one text group', () {
      final q = SearchQueryParser.parse("'start zoloft'");
      expect(q.textOrGroups, equals([['start zoloft']]));
    });

    test('two quoted phrases separated by || become one OR group', () {
      final q = SearchQueryParser.parse("'start zoloft' || 'stop zoloft'");
      expect(q.textOrGroups, equals([['start zoloft', 'stop zoloft']]));
    });

    test('three terms with || form one OR group', () {
      final q = SearchQueryParser.parse("alpha || beta || gamma");
      expect(q.textOrGroups, equals([['alpha', 'beta', 'gamma']]));
    });

    test('OR group followed by space-separated term produces OR group + AND term', () {
      // "'a' || 'b' c" → OR group ['a','b'] AND separate group ['c']
      final q = SearchQueryParser.parse("'a' || 'b' c");
      expect(q.textOrGroups, equals([['a', 'b'], ['c']]));
    });

    // ── title: ────────────────────────────────────────────────────────────────

    test('title: bare word', () {
      final q = SearchQueryParser.parse('title:zoloft');
      expect(q.titleTerm, equals('zoloft'));
      expect(q.textOrGroups, isEmpty);
    });

    test('title: quoted multi-word', () {
      final q = SearchQueryParser.parse("title:'my daily note'");
      expect(q.titleTerm, equals('my daily note'));
    });

    test('title: does not bleed into text groups', () {
      final q = SearchQueryParser.parse('title:zoloft headache');
      expect(q.titleTerm, equals('zoloft'));
      expect(q.textOrGroups, equals([['headache']]));
    });

    // ── startswith: ───────────────────────────────────────────────────────────

    test('startswith: bare word', () {
      final q = SearchQueryParser.parse('startswith:daily');
      expect(q.startsWithTerm, equals('daily'));
    });

    test('startswith: quoted multi-word', () {
      final q = SearchQueryParser.parse("startswith:'start zol'");
      expect(q.startsWithTerm, equals('start zol'));
    });

    // ── date: ─────────────────────────────────────────────────────────────────

    test('date: exact date sets dateFrom and dateTo to same day', () {
      final q = SearchQueryParser.parse('date:2025-01-15');
      expect(q.dateFrom, equals(DateTime(2025, 1, 15)));
      expect(q.dateTo, equals(DateTime(2025, 1, 15, 23, 59, 59)));
    });

    test('date: range sets dateFrom and dateTo', () {
      final q = SearchQueryParser.parse('date:2025-01-01..2025-06-30');
      expect(q.dateFrom, equals(DateTime(2025, 1, 1)));
      expect(q.dateTo, equals(DateTime(2025, 6, 30, 23, 59, 59)));
    });

    test('date: > sets dateFrom only (dateTo is far future)', () {
      final q = SearchQueryParser.parse('date:>2025-08-01');
      expect(q.dateFrom, equals(DateTime(2025, 8, 1)));
      expect(q.dateTo, equals(DateTime(9999)));
    });

    test('date: < sets dateTo only (dateFrom is epoch)', () {
      final q = SearchQueryParser.parse('date:<2025-08-01');
      expect(q.dateFrom, equals(DateTime(0)));
      expect(q.dateTo, equals(DateTime(2025, 8, 1, 23, 59, 59)));
    });

    test('date: whole year expands to Jan 1 – Dec 31', () {
      final q = SearchQueryParser.parse('date:2025');
      expect(q.dateFrom, equals(DateTime(2025, 1, 1)));
      expect(q.dateTo, equals(DateTime(2025, 12, 31, 23, 59, 59)));
    });

    test('date: whole month expands correctly', () {
      final q = SearchQueryParser.parse('date:2025-02');
      expect(q.dateFrom, equals(DateTime(2025, 2, 1)));
      expect(q.dateTo, equals(DateTime(2025, 2, 28, 23, 59, 59)));
    });

    test('date: whole month expands correctly for 31-day month', () {
      final q = SearchQueryParser.parse('date:2025-08');
      expect(q.dateFrom, equals(DateTime(2025, 8, 1)));
      expect(q.dateTo, equals(DateTime(2025, 8, 31, 23, 59, 59)));
    });

    // ── modified: ─────────────────────────────────────────────────────────────

    test('modified: exact date', () {
      final q = SearchQueryParser.parse('modified:2025-08-26');
      expect(q.modifiedFrom, equals(DateTime(2025, 8, 26)));
      expect(q.modifiedTo, equals(DateTime(2025, 8, 26, 23, 59, 59)));
    });

    test('modified: year expands to full year', () {
      final q = SearchQueryParser.parse('modified:2025');
      expect(q.modifiedFrom, equals(DateTime(2025, 1, 1)));
      expect(q.modifiedTo, equals(DateTime(2025, 12, 31, 23, 59, 59)));
    });

    test('modified: > sets modifiedFrom', () {
      final q = SearchQueryParser.parse('modified:>2025-01-01');
      expect(q.modifiedFrom, equals(DateTime(2025, 1, 1)));
      expect(q.modifiedTo, equals(DateTime(9999)));
    });

    // ── exclusions ────────────────────────────────────────────────────────────

    test('-word adds to excludeTerms', () {
      final q = SearchQueryParser.parse('zoloft -headache');
      expect(q.textOrGroups, equals([['zoloft']]));
      expect(q.excludeTerms, equals(['headache']));
    });

    test("-'multi word' adds phrase to excludeTerms", () {
      final q = SearchQueryParser.parse("zoloft -'bad day'");
      expect(q.excludeTerms, equals(['bad day']));
    });

    test('multiple exclusions are all collected', () {
      final q = SearchQueryParser.parse('zoloft -headache -nausea');
      expect(q.excludeTerms, equals(['headache', 'nausea']));
    });

    test('bare dash is not treated as exclusion', () {
      final q = SearchQueryParser.parse('zoloft -');
      expect(q.excludeTerms, isEmpty);
      // bare dash should be ignored or treated as text but not crash
    });

    // ── combined queries ──────────────────────────────────────────────────────

    test('title + date + OR text terms all parsed together', () {
      final q = SearchQueryParser.parse(
          "title:zoloft date:2025-01-01..2025-01-02 'start zoloft' || 'stop zoloft'");
      expect(q.titleTerm, equals('zoloft'));
      expect(q.dateFrom, equals(DateTime(2025, 1, 1)));
      expect(q.dateTo, equals(DateTime(2025, 1, 2, 23, 59, 59)));
      expect(q.textOrGroups, equals([['start zoloft', 'stop zoloft']]));
    });

    test('all filter types combined', () {
      final q = SearchQueryParser.parse(
          "title:zoloft date:2025 startswith:daily 'headache' -nausea modified:>2025-08-01");
      expect(q.titleTerm, equals('zoloft'));
      expect(q.dateFrom, equals(DateTime(2025, 1, 1)));
      expect(q.startsWithTerm, equals('daily'));
      expect(q.textOrGroups, equals([['headache']]));
      expect(q.excludeTerms, equals(['nausea']));
      expect(q.modifiedFrom, equals(DateTime(2025, 8, 1)));
    });

    // ── isEmpty ───────────────────────────────────────────────────────────────

    test('isEmpty is false when any field is set', () {
      expect(SearchQueryParser.parse('zoloft').isEmpty, isFalse);
      expect(SearchQueryParser.parse('title:x').isEmpty, isFalse);
      expect(SearchQueryParser.parse('date:2025').isEmpty, isFalse);
      expect(SearchQueryParser.parse('-x').isEmpty, isFalse);
    });

    // ── edge cases ────────────────────────────────────────────────────────────

    test('unclosed quote does not crash', () {
      expect(() => SearchQueryParser.parse("'unclosed"), returnsNormally);
    });

    test('extra spaces between tokens are handled', () {
      final q = SearchQueryParser.parse('  zoloft   headache  ');
      expect(q.textOrGroups, equals([['zoloft'], ['headache']]));
    });

    test('|| at start is ignored gracefully', () {
      final q = SearchQueryParser.parse("|| zoloft");
      expect(q.textOrGroups, equals([['zoloft']]));
    });

    test('|| at end is ignored gracefully', () {
      final q = SearchQueryParser.parse("zoloft ||");
      expect(q.textOrGroups, equals([['zoloft']]));
    });

    // ── contains: and contains(...) ──────────────────────────────────────────

    test('contains: bare word', () {
      final q = SearchQueryParser.parse('contains:zoloft');
      expect(q.textOrGroups, equals([['zoloft']]));
    });

    test('contains: quoted phrase', () {
      final q = SearchQueryParser.parse("contains:'start zoloft'");
      expect(q.textOrGroups, equals([['start zoloft']]));
    });

    test('contains:x && contains:y produces two AND groups', () {
      final q = SearchQueryParser.parse('contains:medA && contains:medB');
      expect(q.textOrGroups, equals([['medA'], ['medB']]));
    });

    test('contains:x || contains:y produces one OR group', () {
      final q = SearchQueryParser.parse('contains:medA || contains:medB');
      expect(q.textOrGroups, equals([['medA', 'medB']]));
    });

    test('contains(a, b) produces two AND groups', () {
      final q = SearchQueryParser.parse('contains(medA, medB)');
      expect(q.textOrGroups, equals([['medA'], ['medB']]));
    });

    test('contains(a && b) produces two AND groups', () {
      final q = SearchQueryParser.parse('contains(medA && medB)');
      expect(q.textOrGroups, equals([['medA'], ['medB']]));
    });

    test('contains(a | b) produces one OR group', () {
      final q = SearchQueryParser.parse('contains(medA | medB)');
      expect(q.textOrGroups, equals([['medA', 'medB']]));
    });

    test('contains(a || b) produces one OR group', () {
      final q = SearchQueryParser.parse('contains(medA || medB)');
      expect(q.textOrGroups, equals([['medA', 'medB']]));
    });

    test('contains with quoted multi-word phrases', () {
      final q = SearchQueryParser.parse("contains('start zoloft', 'stop zoloft')");
      expect(q.textOrGroups, equals([['start zoloft'], ['stop zoloft']]));
    });

    test('contains combined with title and date', () {
      final q = SearchQueryParser.parse("contains(aspirin, tylenol) title:'health log' date:2025");
      expect(q.titleTerm, equals('health log'));
      expect(q.dateFrom, equals(DateTime(2025, 1, 1)));
      expect(q.textOrGroups, equals([['aspirin'], ['tylenol']]));
    });

    test('term1 && term2 explicit AND produces two AND groups', () {
      final q = SearchQueryParser.parse('headache && fever');
      expect(q.textOrGroups, equals([['headache'], ['fever']]));
    });

    test('startswith: a || startswith: b parses multiple startswith terms', () {
      final q = SearchQueryParser.parse('startswith:alpha || startswith:beta');
      expect(q.startsWithTerms, equals(['alpha', 'beta']));
      expect(q.startsWithTerm, equals('alpha'));
    });

    test('title: a || title: b parses multiple title terms', () {
      final q = SearchQueryParser.parse('title:work || title:personal');
      expect(q.titleTerms, equals(['work', 'personal']));
      expect(q.titleTerm, equals('work'));
    });
  });
}
