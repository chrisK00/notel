bool activityMatchesQuery(String activity, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  return normalizedQuery.isEmpty ||
      activity.toLowerCase().contains(normalizedQuery);
}
