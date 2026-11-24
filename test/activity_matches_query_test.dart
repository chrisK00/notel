import 'package:flutter_test/flutter_test.dart';
import 'package:notel/activity_log/activity_matches_query.dart';

void main() {
  test('matches all activity variants by a partial case-insensitive query', () {
    for (final activity in ['zoloft', 'zo', 'zo25', 'zo']) {
      expect(activityMatchesQuery(activity, 'zo'), isTrue);
    }
    expect(activityMatchesQuery('running', 'zo'), isFalse);
  });
}
