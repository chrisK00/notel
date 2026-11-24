import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notel/activity_log/activity_calendar_date.dart';
import 'package:notel/activity_log/activity_log_entry.dart';
import 'package:notel/activity_log/activity_log_repository.dart';
import 'package:notel/activity_log/activity_matches_query.dart';
import 'package:notel/note_page/edit_page.dart';
import 'package:notel/note_page/note_page_repository.dart';

class ActivityCalendarPage extends StatefulWidget {
  const ActivityCalendarPage({super.key});

  @override
  State<ActivityCalendarPage> createState() => _ActivityCalendarPageState();
}

class _ActivityCalendarPageState extends State<ActivityCalendarPage> {
  static const _monthNames = [
    'januari',
    'februari',
    'mars',
    'april',
    'maj',
    'juni',
    'juli',
    'augusti',
    'september',
    'oktober',
    'november',
    'december',
  ];
  static const _weekDays = ['M', 'T', 'O', 'T', 'F', 'L', 'S'];

  final _activitySearchController = TextEditingController();
  late DateTime _month;
  late DateTime _selectedDay;
  String? _selectedActivity;
  List<ActivityLogEntry> _entries = [];
  bool _isLoading = true;
  String? _loadError;
  int _loadRequestId = 0;
  Timer? _midnightRefresh;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadMonth();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightRefresh?.cancel();
    _activitySearchController.dispose();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnightRefresh = Timer(tomorrow.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _loadMonth() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final notes = await ActivityLogRepository.loadActivityNotes();
      final entries = notes.expand(ActivityLogEntry.fromNote).toList()
        ..sort(_compareEntries);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _entries = entries;
        if (_selectedActivity != null) {
          final selectedKey = _selectedActivity!.toLowerCase();
          final matchingEntries =
              entries.where((entry) => entry.activityLabelKey == selectedKey);
          _selectedActivity =
              matchingEntries.isEmpty ? null : matchingEntries.first.activity;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _loadError = 'Kunde inte läsa kalendern: $error';
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDay = DateTime(_month.year, _month.month, 1);
    });
  }

  Future<void> _selectMonthAndYear() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      currentDate: DateTime.now(),
      firstDate: DateTime(_month.year - 100),
      lastDate: DateTime(_month.year + 100, 12, 31),
    );
    if (!mounted || date == null) return;
    setState(() {
      _month = DateTime(date.year, date.month);
      _selectedDay = DateTime(date.year, date.month, date.day);
    });
  }

  List<String> get _activities {
    final namesByKey = <String, String>{};
    for (final entry in _entries) {
      namesByKey.putIfAbsent(entry.activityLabelKey, () => entry.activity);
    }
    return namesByKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool _matchesActivityFilter(ActivityLogEntry entry) {
    final query = _activitySearchController.text.trim();
    if (query.isNotEmpty) {
      return activityMatchesQuery(entry.activity, query);
    }
    return _selectedActivity == null ||
        entry.activityLabelKey == _selectedActivity!.toLowerCase();
  }

  List<ActivityLogEntry> get _visibleEntries {
    return _entries.where((entry) {
      return entry.timestamp.year == _selectedDay.year &&
          entry.timestamp.month == _selectedDay.month &&
          entry.timestamp.day == _selectedDay.day &&
          _matchesActivityFilter(entry);
    }).toList()
      ..sort(_compareEntries);
  }

  List<DateTime> get _occurrenceDays {
    final dates = <DateTime>{};
    for (final entry in _entries) {
      if (_matchesActivityFilter(entry)) {
        dates.add(DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        ));
      }
    }
    return dates.toList()..sort();
  }

  DateTime? _adjacentOccurrence(List<DateTime> dates,
      {required bool previous}) {
    DateTime? result;
    for (final date in dates) {
      final comparison = date.compareTo(_selectedDay);
      if (previous && comparison < 0) result = date;
      if (!previous && comparison > 0) return date;
    }
    return result;
  }

  void _selectOccurrence(DateTime date) {
    setState(() {
      _month = DateTime(date.year, date.month);
      _selectedDay = date;
    });
  }

  int _compareEntries(ActivityLogEntry a, ActivityLogEntry b) {
    final timeOrder = a.timestamp.compareTo(b.timestamp);
    if (timeOrder != 0) return timeOrder;
    final noteOrder = a.noteId.compareTo(b.noteId);
    return noteOrder != 0 ? noteOrder : a.lineIndex.compareTo(b.lineIndex);
  }

  Map<ActivityLogEntry, Duration> _durationsForHistory() {
    final active = <String, ActivityLogEntry>{};
    final durations = <ActivityLogEntry, Duration>{};
    for (final entry in _entries
        .where((entry) => !entry.timestamp.isAfter(DateTime.now()))) {
      if (entry.action == ActivityLogAction.start) {
        active[entry.activityKey] = entry;
      } else {
        final start = active.remove(entry.activityKey);
        if (start != null && start.hasExplicitTime && entry.hasExplicitTime) {
          final duration = entry.timestamp.difference(start.timestamp);
          durations[start] = duration;
          durations[entry] = duration;
        }
      }
    }
    return durations;
  }

  Future<void> _openNote(ActivityLogEntry entry) async {
    try {
      final note = await NotePageRepository.getNoteById(entry.noteId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => EditPage(noteId: note.id, initialNote: note),
        ),
      );
      if (mounted) _loadMonth();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte öppna anteckningen: $error')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes ~/ 60) % 24;
    final minutes = totalMinutes % 60;
    if (days > 0) return '$days d $hours h';
    if (hours > 0) return '$hours h $minutes min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final activities = _activities;
    final occurrenceDays = _occurrenceDays;
    final previousOccurrence =
        _adjacentOccurrence(occurrenceDays, previous: true);
    final nextOccurrence = _adjacentOccurrence(occurrenceDays, previous: false);
    final dayEntries = _visibleEntries;
    final durations = _durationsForHistory();
    final occurrenceButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Föregående månad',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Tooltip(
                      message: 'Välj månad och år',
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _selectMonthAndYear,
                        child: Text(
                          '${_monthNames[_month.month - 1]} ${_month.year}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Nästa månad',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            _buildCalendarGrid(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _activitySearchController,
                    decoration: InputDecoration(
                      labelText: 'Sök aktivitet',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _activitySearchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Rensa sökning',
                              onPressed: () {
                                _activitySearchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() => _selectedActivity = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedActivity,
                              isExpanded: true,
                              hint: const Text(
                                'Ordlista',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              items: activities
                                  .map((activity) => DropdownMenuItem(
                                        value: activity,
                                        child: Text(
                                          activity,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: activities.isEmpty
                                  ? null
                                  : (activity) => setState(() {
                                        _activitySearchController.clear();
                                        _selectedActivity = activity;
                                      }),
                            ),
                          ),
                        ),
                        if (_selectedActivity != null)
                          IconButton(
                            tooltip: 'Visa alla aktiviteter',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                                width: 32, height: 40),
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                setState(() => _selectedActivity = null),
                            icon: const Icon(Icons.clear, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: occurrenceButtonStyle,
                  onPressed: previousOccurrence == null
                      ? null
                      : () => _selectOccurrence(previousOccurrence),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 18),
                      SizedBox(width: 2),
                      Text('Föregående'),
                    ],
                  ),
                ),
                TextButton(
                  style: occurrenceButtonStyle,
                  onPressed: nextOccurrence == null
                      ? null
                      : () => _selectOccurrence(nextOccurrence),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Nästa'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              calendarDayDistanceLabel(_selectedDay, DateTime.now()),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(_loadError!),
                trailing: IconButton(
                  tooltip: 'Försök igen',
                  onPressed: _loadMonth,
                  icon: const Icon(Icons.refresh),
                ),
              )
            else if (dayEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Inga start/stop-rader den här dagen.'),
              )
            else
              for (final entry in dayEntries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(entry.action == ActivityLogAction.start
                      ? Icons.play_circle_outline
                      : Icons.stop_circle_outlined),
                  title: Text(entry.activity),
                  subtitle: durations.containsKey(entry)
                      ? Text('Tid · ${_formatDuration(durations[entry]!)}')
                      : null,
                  onTap: () => _openNote(entry),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final cells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final day in _weekDays)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(day),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingDays + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(_month.year, _month.month, dayNumber);
            final count = _entries
                .where((entry) =>
                    entry.timestamp.year == date.year &&
                    entry.timestamp.month == date.month &&
                    entry.timestamp.day == date.day &&
                    _matchesActivityFilter(entry))
                .length;
            final selected = date.year == _selectedDay.year &&
                date.month == _selectedDay.month &&
                date.day == _selectedDay.day;
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _selectedDay = date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16.5,
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (count > 0)
                    Container(
                      key: ValueKey(
                          'activity-marker-${date.year}-${date.month}-${date.day}'),
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 13),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
