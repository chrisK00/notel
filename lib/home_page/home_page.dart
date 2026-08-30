import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/console.dart';
import 'package:notel/dialogs/yes_or_no_dialog.dart';
import 'package:notel/home_page/category_drawer.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/note_page/new_note_page.dart';
import 'package:notel/search/search_query.dart';
import 'package:notel/search/search_query_parser.dart';
import 'package:notel/utils/extensions.dart';
import 'package:provider/provider.dart';
import '../note_page/edit_page.dart';
import '../infrastructure/note.dart';
import '../notes_provider.dart';
import 'home_page_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchTextController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _categoryTitleController = TextEditingController();
  final _settingsRepository = SettingsRepository(Db.instance);
  final _scrollController = ScrollController();
  var _hideNoteTextSettings = BoolSettings(BoolSettings.hideNoteTextKey, true);
  var _showLastModifiedSettings = BoolSettings(BoolSettings.showLastModifiedKey, true);
  double _previewFontSize = 14;
  double _previewTitleFontSize = 17;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  bool _showExportReminder = false;
  SearchQuery? _activeQuery;
  int? _editingCategoryId;

  Future<void> loadNotes() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    await provider.loadCategories();
    final loadedNotes = await HomePageRepository.loadNotes(categoryId: provider.selectedCategory?.id, sort: provider.selectedCategory == null ? NoteSort.created : provider.sort);
    if (!mounted) return;
    provider.init(loadedNotes);
  }

  Future<void> loadSettings() async {
    final settings = await _settingsRepository.getOrNull(BoolSettings.hideNoteTextKey, BoolSettings.fromMap);
    final showModified = await _settingsRepository.getOrNull(BoolSettings.showLastModifiedKey, BoolSettings.fromMap);
    final previewSize = await _settingsRepository.getOrNull(StringSettings.previewFontSizeKey, StringSettings.fromMap);
    final titleSize = await _settingsRepository.getOrNull(StringSettings.previewTitleFontSizeKey, StringSettings.fromMap);
    if (!mounted) return;
    setState(() {
      if (settings != null) _hideNoteTextSettings = settings;
      if (showModified != null) _showLastModifiedSettings = showModified;
      _previewFontSize = double.tryParse(previewSize?.value ?? '') ?? 14;
      _previewTitleFontSize = double.tryParse(titleSize?.value ?? '') ?? 17;
    });
  }

  Future<void> checkExportReminder() async {
    final autoEnabled = await _settingsRepository.getOrNull(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings.fromMap,
    );
    final autoDir = await _settingsRepository.getOrNull(
      StringSettings.autoBackupDirectoryKey,
      StringSettings.fromMap,
    );
    final autoPass = await _settingsRepository.getOrNull(
      StringSettings.autoBackupPasswordKey,
      StringSettings.fromMap,
    );
    final isAutoConfigured = (autoEnabled?.value ?? false) &&
        (autoDir?.value.trim().isNotEmpty ?? false) &&
        (autoPass?.value.isNotEmpty ?? false);

    if (isAutoConfigured) {
      final lastAutoDate = await _settingsRepository.getOrNull(
        StringSettings.autoBackupLastDateKey,
        StringSettings.fromMap,
      );
      if (lastAutoDate != null && lastAutoDate.value.isNotEmpty) {
        final parsed = DateTime.tryParse(lastAutoDate.value);
        if (parsed != null && DateTime.now().difference(parsed).inDays < 30) {
          // Auto-backup working & recent; no reminder needed
          return;
        }
      }
    }

    final reminder = await _settingsRepository.getOrNull(StringSettings.lastExportReminderKey, StringSettings.fromMap);
    if (!mounted) return;
    final bool shouldShow;
    if (reminder == null) {
      // Never exported — show reminder.
      shouldShow = true;
    } else {
      final lastDate = DateTime.tryParse(reminder.value);
      shouldShow = lastDate == null || DateTime.now().difference(lastDate).inDays >= 30;
    }
    if (shouldShow) setState(() => _showExportReminder = true);
  }

  Future<void> _dismissExportReminder() async {
    // Snooze: record today so the reminder won't show again for 30 days.
    await _settingsRepository.insertOrUpdate(
      StringSettings.lastExportReminderKey,
      StringSettings(StringSettings.lastExportReminderKey, DateTime.now().toString()).toMap,
    );
    setState(() => _showExportReminder = false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent - 200) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      if (!provider.isLoadingMore && provider.hasMore) {
        provider.loadNextPage();
      }
    }
  }

  @override
  void initState() {
    loadSettings();
    super.initState();
    loadNotes();
    checkExportReminder();
    AutoBackupService.checkAndRun();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchTextController.dispose();
    _searchFocusNode.dispose();
    _categoryTitleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncCategoryTitle(NotesProvider provider) {
    final currentCat = provider.selectedCategory;
    if (currentCat == null) {
      if (_editingCategoryId != null) {
        _searchTextController.clear();
        _activeQuery = null;
      }
      _editingCategoryId = null;
      _categoryTitleController.text = '';
    } else if (_editingCategoryId != currentCat.id) {
      _searchTextController.clear();
      _activeQuery = null;
      _editingCategoryId = currentCat.id;
      _categoryTitleController.text = currentCat.name;
    }
  }

  Future<void> _saveCategoryTitle(NotesProvider provider, String newName) async {
    final category = provider.selectedCategory;
    if (category == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      _categoryTitleController.text = category.name;
      return;
    }
    if (trimmed != category.name) {
      await provider.updateCategoryName(category.id, trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      _syncCategoryTitle(provider);
      return Scaffold(
        drawer: const CategoryDrawer(),
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(children: [
              if (_showExportReminder)
                MaterialBanner(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  content: const Text('No export in over 30 days. Consider backing up your notes.'),
                  actions: [
                    TextButton(
                      onPressed: _dismissExportReminder,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              if (provider.selectedCategory != null) categoryHeader(provider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: searchBar(provider),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                    key: const PageStorageKey('notesListKey'),
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      if (index == provider.notes.length) {
                        return provider.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : const SizedBox.shrink();
                      }
                      return noteRow(context, provider.notes[index]);
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: provider.notes.length + 1),
              ),
            ]),
          ),
        ),
        floatingActionButton: addNoteButton(context, provider),
      );
    });
  }

  Widget categoryHeader(NotesProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to all notes',
            onPressed: () async {
              _searchTextController.clear();
              _activeQuery = null;
              await provider.clearSelectedCategory();
            },
          ),
          Expanded(
            child: TextField(
              controller: _categoryTitleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Category name',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (value) => _saveCategoryTitle(provider, value),
              onTapOutside: (_) {
                _saveCategoryTitle(provider, _categoryTitleController.text);
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (item) async {
              if (item == 5 || item == 6) {
                await provider.setCategoryHomeVisibility(item == 6);
                return;
              }
              if (item >= 2) {
                await provider.setSort(NoteSort.values[item - 2]);
                return;
              }
              if (item == 1) {
                final categoryToDelete = provider.selectedCategory;
                if (categoryToDelete == null) return;
                final shouldCancel = await showDialog<bool>(
                  context: context,
                  builder: (context) => YesOrNoDialog(
                    title: "Delete category '${categoryToDelete.name}' and all its notes?",
                    dangerBtnText: "Delete",
                    successBtnText: "Cancel",
                  ),
                );
                var confirmed = shouldCancel == false;
                if (confirmed && provider.notes.isNotEmpty) {
                  final secondConfirmation = await showDialog<bool>(
                    context: context,
                    builder: (context) => YesOrNoDialog(
                      title: "This will permanently delete ${provider.notes.length} note${provider.notes.length == 1 ? '' : 's'}. Continue?",
                      dangerBtnText: "Delete all",
                      successBtnText: "Cancel",
                    ),
                  );
                  confirmed = secondConfirmation == false;
                }
                if (confirmed && mounted) {
                  _searchTextController.clear();
                  _activeQuery = null;
                  await provider.deleteCategory(categoryToDelete.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<int>(value: 5, child: Text('Hide all notes from home')),
              const PopupMenuItem<int>(value: 6, child: Text('Show all notes on home')),
              const PopupMenuDivider(),
              PopupMenuItem<int>(value: 2, child: Text('Sort: Created${provider.sort == NoteSort.created ? ' ✓' : ''}')),
              PopupMenuItem<int>(value: 3, child: Text('Sort: Name${provider.sort == NoteSort.name ? ' ✓' : ''}')),
              PopupMenuItem<int>(value: 4, child: Text('Sort: Last modified${provider.sort == NoteSort.modified ? ' ✓' : ''}')),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete category'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget searchBar(NotesProvider provider) {
    return TextField(
      controller: _searchTextController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchTextController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () {
                    clearSearch(provider);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Search filters & syntax',
                onPressed: () => _showSearchFilterAssistant(provider),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.only(left: 10, top: 10)),
      onChanged: (value) => onSearch(value, provider),
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  void _insertSearchTemplate(String template, NotesProvider provider) {
    final text = _searchTextController.text;
    final selection = _searchTextController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final prefix = (start > 0 && !text.substring(0, start).endsWith(' ')) ? ' ' : '';
    final suffix = (end < text.length && !text.substring(end).startsWith(' ')) ? ' ' : '';
    final insertion = '$prefix$template$suffix';

    final newText = text.replaceRange(start, end, insertion);
    _searchTextController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    _searchFocusNode.requestFocus();
    onSearch(newText, provider);
  }

  void _showSearchFilterAssistant(NotesProvider provider) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Text(
                  'Search Filter Assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap an operator template to insert it into the search bar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 16),
                _filterAssistantItem(
                  icon: Icons.all_inclusive,
                  template: 'contains:a && contains:b',
                  title: 'contains:x && contains:y',
                  description: 'Match notes containing all specified terms (AND)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('contains:a && contains:b', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.data_array,
                  template: 'contains(a, b)',
                  title: 'contains(a, b)',
                  description: 'Multi-term required matching (AND)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('contains(a, b)', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.call_split,
                  template: 'contains(a | b)',
                  title: 'contains(a | b)',
                  description: 'Match notes containing either term (OR)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('contains(a | b)', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.calendar_month,
                  template: 'date:2025-01-01..2025-06-30',
                  title: 'date:YYYY-MM-DD..YYYY-MM-DD',
                  description: 'Filter notes in a date range',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('date:2025-01-01..2025-06-30', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.date_range,
                  template: 'date:>2025-01-01',
                  title: 'date:>YYYY-MM-DD',
                  description: 'Notes on or after date (> or <)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('date:>2025-01-01', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.title,
                  template: "title:'my note'",
                  title: "title:'keyword'",
                  description: 'Match notes by title',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate("title:'my title'", provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.history,
                  template: 'modified:2025-08',
                  title: 'modified:YYYY-MM',
                  description: 'Filter by note last edited date',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('modified:2025-08', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.alt_route,
                  template: 'startswith:alpha || startswith:beta',
                  title: 'startswith:a || startswith:b',
                  description: 'Note body starts with either text prefix (OR)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('startswith:alpha || startswith:beta', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.call_split,
                  template: "'term1' || 'term2'",
                  title: 'term1 || term2',
                  description: 'Match notes containing either term (OR)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('term1 || term2', provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.start,
                  template: "startswith:'start text'",
                  title: "startswith:'text'",
                  description: 'Note body starts with phrase',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate("startswith:'start text'", provider);
                  },
                ),
                _filterAssistantItem(
                  icon: Icons.remove_circle_outline,
                  template: '-unwanted',
                  title: "-word or -'phrase'",
                  description: 'Exclude notes containing term',
                  onTap: () {
                    Navigator.pop(ctx);
                    _insertSearchTemplate('-unwanted', provider);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _filterAssistantItem({
    required IconData icon,
    required String template,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.add, size: 18),
      onTap: onTap,
    );
  }

  Future clearSearch(NotesProvider provider) async {
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final loadedNotes = await HomePageRepository.loadNotes(categoryId: provider.selectedCategory?.id, sort: provider.selectedCategory == null ? NoteSort.created : provider.sort);
    if (requestId != _searchRequestId) return;
    provider.init(loadedNotes);
    setState(() {
      _searchTextController.text = '';
      _activeQuery = null;
    });
  }

  Future onSearch(String value, NotesProvider provider) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      await clearSearch(provider);
      return;
    }

    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final query = SearchQueryParser.parse(trimmedValue);
      final foundNotes = await HomePageRepository.findNotes(query, categoryId: provider.selectedCategory?.id, sort: provider.selectedCategory == null ? NoteSort.created : provider.sort);
      if (requestId != _searchRequestId || _searchTextController.text.trim() != trimmedValue) return;
      if (mounted) setState(() => _activeQuery = query);
      provider.init(foundNotes);
    });
  }

  void updateNoteInList(List<Note> notes, int noteId, String newText) {
    final noteIndex = notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      notes[noteIndex].displayText = newText;
    }
  }

  GestureDetector noteRow(BuildContext context, Note n) {
    writeLine("Title ${n.title}");
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          final query = _searchTextController.text.trim().isNotEmpty
              ? (_activeQuery ?? SearchQueryParser.parse(_searchTextController.text))
              : null;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => EditPage(
                noteId: n.id,
                highlightQuery: query,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n.date.isToday() ? 'today' : '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    n.date.day.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Text(
                    DateFormat('MMMM').format(n.date.toDateTime()),
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    DateFormat('yyyy').format(n.date.toDateTime()),
                    style: const TextStyle(fontSize: 12),
                  )
                ],
              ),
              SizedBox(
                width: 270,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    n.title.isNullOrWhitespace()
                        ? _highlightedText(
                            _hideNoteTextSettings.value ? '' : n.displayText,
                            _activeQuery,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                            fontSize: _previewFontSize,
                          )
                        : Text(n.title!,
                            style: TextStyle(fontSize: _previewTitleFontSize),
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                    if (_showLastModifiedSettings.value && n.lastModified != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last edited ${DateFormat('d MMM yyyy, HH:mm').format(n.lastModified!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.70)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  /// Builds a [RichText] widget with all search term occurrences highlighted.
  /// Falls back to a plain [Text] when there is no active query or no matches.
  Widget _highlightedText(
    String text,
    SearchQuery? query, {
    TextOverflow overflow = TextOverflow.clip,
    int? maxLines,
    double? fontSize,
  }) {
    // Collect all terms to highlight: bare text terms + titleTerms + startsWithTerms.
    final terms = <String>[];
    if (query != null) {
      for (final group in query.textOrGroups) {
        terms.addAll(group);
      }
      terms.addAll(query.titleTerms);
      terms.addAll(query.startsWithTerms);
    }

    if (terms.isEmpty || text.isEmpty) {
      return Text(text, overflow: overflow, maxLines: maxLines, style: TextStyle(fontSize: fontSize));
    }

    // Build a combined regex that matches any of the terms (case-insensitive).
    final pattern = terms.map((t) => RegExp.escape(t)).join('|');
    final regex = RegExp(pattern, caseSensitive: false);

    final spans = <TextSpan>[];
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: _previewFontSize, color: Theme.of(context).textTheme.bodyMedium?.color),
        children: spans,
      ),
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  FloatingActionButton addNoteButton(BuildContext context, NotesProvider provider) {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => NewNotePage(categoryId: provider.selectedCategory?.id),
          ),
        );
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}
