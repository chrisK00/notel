import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/console.dart';
import 'package:notel/dialogs/yes_or_no_dialog.dart';
import 'package:notel/home_page/category_icon_picker.dart';
import 'package:notel/home_page/category_drawer.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/category_icons.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/note_page/new_note_page.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/search/search_query.dart';
import 'package:notel/search/search_query_parser.dart';
import 'package:notel/utils/extensions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../note_page/edit_page.dart';
import '../infrastructure/note.dart';
import '../notes_provider.dart';
import 'home_page_repository.dart';
import '../note_page/image_embed.dart';

enum _NoteAction { move, share, details, duplicate, delete }

enum _CreateAction { blank, inFolder, fromTemplate }

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
  var _showLastModifiedSettings =
      BoolSettings(BoolSettings.showLastModifiedKey, true);
  var _shortMonthOnHomeSettings =
      BoolSettings(BoolSettings.shortMonthOnHomeKey, false);
  double _previewFontSize = 14;
  double _previewTitleFontSize = 17;
  double _lastEditedOpacity = .85;
  Timer? _searchDebounce;
  Timer? _noteLoadingTimer;
  int _searchRequestId = 0;
  int _noteRippleGeneration = 0;
  bool _isOpeningNote = false;
  bool _showNoteLoading = false;
  bool _showExportReminder = false;
  SearchQuery? _activeQuery;
  int? _editingCategoryId;

  Future<void> loadNotes() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    await provider.loadCategories();
    final loadedNotes = await HomePageRepository.loadNotes(
        categoryId: provider.selectedCategory?.id,
        sort: provider.selectedCategory == null
            ? NoteSort.created
            : provider.sort);
    if (!mounted) return;
    provider.init(loadedNotes);
  }

  Future<void> loadSettings() async {
    final settings = await _settingsRepository.getOrNull(
        BoolSettings.hideNoteTextKey, BoolSettings.fromMap);
    final showModified = await _settingsRepository.getOrNull(
        BoolSettings.showLastModifiedKey, BoolSettings.fromMap);
    final shortMonth = await _settingsRepository.getOrNull(
        BoolSettings.shortMonthOnHomeKey, BoolSettings.fromMap);
    final previewSize = await _settingsRepository.getOrNull(
        StringSettings.previewFontSizeKey, StringSettings.fromMap);
    final titleSize = await _settingsRepository.getOrNull(
        StringSettings.previewTitleFontSizeKey, StringSettings.fromMap);
    final lastEditedOpacity = await _settingsRepository.getOrNull(
        StringSettings.lastEditedOpacityKey, StringSettings.fromMap);
    if (!mounted) return;
    setState(() {
      if (settings != null) _hideNoteTextSettings = settings;
      if (showModified != null) _showLastModifiedSettings = showModified;
      if (shortMonth != null) _shortMonthOnHomeSettings = shortMonth;
      _previewFontSize = double.tryParse(previewSize?.value ?? '') ?? 14;
      _previewTitleFontSize = double.tryParse(titleSize?.value ?? '') ?? 17;
      _lastEditedOpacity = (double.tryParse(lastEditedOpacity?.value ?? '') ?? .85)
          .clamp(0.0, 1.0)
          .toDouble();
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

    final reminder = await _settingsRepository.getOrNull(
        StringSettings.lastExportReminderKey, StringSettings.fromMap);
    if (!mounted) return;
    final bool shouldShow;
    if (reminder == null) {
      // Never exported — show reminder.
      shouldShow = true;
    } else {
      final lastDate = DateTime.tryParse(reminder.value);
      shouldShow =
          lastDate == null || DateTime.now().difference(lastDate).inDays >= 30;
    }
    if (shouldShow) setState(() => _showExportReminder = true);
  }

  Future<void> _dismissExportReminder() async {
    // Snooze: record today so the reminder won't show again for 30 days.
    await _settingsRepository.insertOrUpdate(
      StringSettings.lastExportReminderKey,
      StringSettings(
              StringSettings.lastExportReminderKey, DateTime.now().toString())
          .toMap,
    );
    setState(() => _showExportReminder = false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 200) {
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
    _noteLoadingTimer?.cancel();
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

  Future<void> _saveCategoryTitle(
      NotesProvider provider, String newName) async {
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

  Future<void> _showCategoryAppearanceDialog(NotesProvider provider) async {
    final category = provider.selectedCategory;
    if (category == null) return;

    var selectedIconKey = category.iconKey;
    var selectedIconColor = category.iconColor;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryIconPicker(
                selectedKey: selectedIconKey,
                onSelected: (key) =>
                    setDialogState(() => selectedIconKey = key),
              ),
              CategoryColorPicker(
                selectedColor: selectedIconColor,
                onSelected: (color) =>
                    setDialogState(() => selectedIconColor = color),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await provider.updateCategoryAppearance(
        category.id,
        iconKey: selectedIconKey,
        iconColor: selectedIconColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      _syncCategoryTitle(provider);
      return Scaffold(
        drawer: const CategoryDrawer(),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(children: [
                  if (_showExportReminder)
                    MaterialBanner(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      content: const Text(
                          'No export in over 30 days. Consider backing up your notes.'),
                      actions: [
                        TextButton(
                          onPressed: _dismissExportReminder,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  if (provider.selectedCategory != null)
                    categoryHeader(provider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: searchBar(provider),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                        controller: _scrollController,
                        itemBuilder: (context, index) {
                          if (index == provider.notes.length) {
                            return provider.isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
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
            if (_showNoteLoading) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        floatingActionButton: IgnorePointer(
          ignoring: _isOpeningNote,
          child: addNoteButton(context, provider),
        ),
      );
    });
  }

  PopupMenuItem<int> _categoryMenuItem({
    required int value,
    required String text,
    bool? checked,
    IconData? icon,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<int>(
      value: value,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (checked != null) ...[
            SizedBox(
              width: 20,
              child: checked ? const Icon(Icons.check, size: 18) : null,
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: isDestructive ? Colors.red : null),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: isDestructive ? Colors.red : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<int> _categoryMenuHeader(BuildContext context, String title) {
    return PopupMenuItem<int>(
      enabled: false,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
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
          IconButton(
            tooltip: 'Edit category icon',
            onPressed: () => _showCategoryAppearanceDialog(provider),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: Icon(
              CategoryIcons.forKey(provider.selectedCategory!.iconKey),
              color:
                  CategoryIcons.colorFor(provider.selectedCategory!.iconColor),
              size: 24,
            ),
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
              final category = provider.selectedCategory;
              if (category == null) return;
              if (item == 7 || item == 8 || item == 9 || item == 10) {
                await provider.updateCategoryDisplaySettings(
                  category.id,
                  showNoteDate: item == 7
                      ? !category.showNoteDate
                      : category.showNoteDate,
                  showLastModified: switch (item) {
                    8 => null,
                    9 => true,
                    10 => false,
                    _ => category.showLastModified,
                  },
                );
                return;
              }
              if (item == 11 || item == 12 || item == 13) {
                await provider.setSort(NoteSort.values[item - 11]);
                return;
              }
              if (item == 1) {
                final categoryToDelete = provider.selectedCategory;
                if (categoryToDelete == null) return;
                final shouldCancel = await showDialog<bool>(
                  context: context,
                  builder: (context) => YesOrNoDialog(
                    title:
                        "Delete category '${categoryToDelete.name}' and all its notes?",
                    dangerBtnText: "Delete",
                    successBtnText: "Cancel",
                  ),
                );
                var confirmed = shouldCancel == false;
                if (confirmed && provider.notes.isNotEmpty) {
                  final secondConfirmation = await showDialog<bool>(
                    context: context,
                    builder: (context) => YesOrNoDialog(
                      title:
                          "This will permanently delete ${provider.notes.length} note${provider.notes.length == 1 ? '' : 's'}. Continue?",
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
            itemBuilder: (context) {
              final category = provider.selectedCategory!;
              return [
                _categoryMenuItem(
                  value: 7,
                  text: 'Show note date',
                  checked: category.showNoteDate,
                ),
                const PopupMenuDivider(height: 1),
                _categoryMenuHeader(context, 'Last edited date'),
                _categoryMenuItem(
                  value: 8,
                  text: 'Use global setting',
                  checked: category.showLastModified == null,
                ),
                _categoryMenuItem(
                  value: 9,
                  text: 'Show',
                  checked: category.showLastModified == true,
                ),
                _categoryMenuItem(
                  value: 10,
                  text: 'Hide',
                  checked: category.showLastModified == false,
                ),
                const PopupMenuDivider(height: 1),
                _categoryMenuHeader(context, 'Sort options'),
                _categoryMenuItem(
                  value: 11,
                  text: 'Created',
                  checked: provider.sort == NoteSort.created,
                ),
                _categoryMenuItem(
                  value: 12,
                  text: 'Name',
                  checked: provider.sort == NoteSort.name,
                ),
                _categoryMenuItem(
                  value: 13,
                  text: 'Last modified',
                  checked: provider.sort == NoteSort.modified,
                ),
                const PopupMenuDivider(height: 1),
                _categoryMenuItem(
                  value: 5,
                  text: 'Hide all notes from home',
                ),
                _categoryMenuItem(
                  value: 6,
                  text: 'Show all notes on home',
                ),
                const PopupMenuDivider(height: 1),
                _categoryMenuItem(
                  value: 1,
                  text: 'Delete category',
                  icon: Icons.delete,
                  isDestructive: true,
                ),
              ];
            },
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

    final prefix =
        (start > 0 && !text.substring(0, start).endsWith(' ')) ? ' ' : '';
    final suffix =
        (end < text.length && !text.substring(end).startsWith(' ')) ? ' ' : '';
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
                  description:
                      'Match notes containing all specified terms (AND)',
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
                    _insertSearchTemplate(
                        'date:2025-01-01..2025-06-30', provider);
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
                    _insertSearchTemplate(
                        'startswith:alpha || startswith:beta', provider);
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
        child: Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.add, size: 18),
      onTap: onTap,
    );
  }

  Future clearSearch(NotesProvider provider) async {
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final loadedNotes = await HomePageRepository.loadNotes(
        categoryId: provider.selectedCategory?.id,
        sort: provider.selectedCategory == null
            ? NoteSort.created
            : provider.sort);
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
      final foundNotes = await HomePageRepository.findNotes(query,
          categoryId: provider.selectedCategory?.id,
          sort: provider.selectedCategory == null
              ? NoteSort.created
              : provider.sort);
      if (requestId != _searchRequestId ||
          _searchTextController.text.trim() != trimmedValue) return;
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

  Future<void> _openNote(BuildContext context, Note preview) async {
    if (_isOpeningNote) return;
    var notePageWasOpened = false;
    setState(() => _isOpeningNote = true);
    _noteLoadingTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _isOpeningNote) {
        setState(() => _showNoteLoading = true);
      }
    });

    try {
      final fullNote = await NotePageRepository.getNoteById(preview.id);
      _noteLoadingTimer?.cancel();
      if (!mounted || !context.mounted) return;
      setState(() => _showNoteLoading = false);

      final query = _searchTextController.text.trim().isNotEmpty
          ? (_activeQuery ??
              SearchQueryParser.parse(_searchTextController.text))
          : null;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => EditPage(
            noteId: fullNote.id,
            initialNote: fullNote,
            highlightQuery: query,
          ),
        ),
      );
      notePageWasOpened = true;
    } catch (error) {
      writeLine('Failed to open note ${preview.id}: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open note. Please try again.')),
        );
      }
    } finally {
      _noteLoadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isOpeningNote = false;
          _showNoteLoading = false;
          if (notePageWasOpened) _noteRippleGeneration++;
        });
      }
    }
  }

  Future<void> _showNoteActions(
    BuildContext context,
    NotesProvider provider,
    Note note,
  ) async {
    final action = await showModalBottomSheet<_NoteAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to folder'),
              onTap: () => Navigator.pop(context, _NoteAction.move),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context, _NoteAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () => Navigator.pop(context, _NoteAction.duplicate),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () => Navigator.pop(context, _NoteAction.details),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, _NoteAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || !context.mounted || action == null) return;

    switch (action) {
      case _NoteAction.move:
        await _moveNoteToFolder(provider, note);
      case _NoteAction.share:
        await _shareNote(note);
      case _NoteAction.details:
        _showNoteDetails(provider, note);
      case _NoteAction.duplicate:
        final copy = await provider.duplicateNote(note);
        if (copy != null && mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note duplicated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      case _NoteAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => YesOrNoDialog(
            title:
                "Delete '${note.title?.trim().isNotEmpty == true ? note.title : 'this note'}'?",
            dangerBtnText: 'Delete',
            successBtnText: 'Cancel',
          ),
        );
        if (confirmed == false) await provider.remove(note.id);
    }
  }

  Future<void> _moveNoteToFolder(NotesProvider provider, Note note) async {
    final targetId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to folder'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('No folder'),
                trailing:
                    note.categoryId == null ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, -1),
              ),
              for (final category in provider.categories)
                ListTile(
                  leading: Icon(
                    CategoryIcons.forKey(category.iconKey),
                    color: CategoryIcons.colorFor(category.iconColor),
                  ),
                  title: Text(category.name),
                  trailing: note.categoryId == category.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, category.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || targetId == null) return;
    final categoryId = targetId == -1 ? null : targetId;
    if (categoryId == note.categoryId) return;

    try {
      final changed =
          await NotePageRepository.updateNoteCategory(note.id, categoryId);
      if (changed == 0) throw StateError('Note no longer exists.');
      await provider.update(note.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move note: $error')),
      );
    }
  }

  Future<void> _shareNote(Note preview) async {
    try {
      final note = await NotePageRepository.getNoteById(preview.id);
      final title = note.title?.trim();
      final shareTitle = title?.isNotEmpty == true ? title! : 'Notel note';
      final body = _plainTextForSharing(note.displayText);
      final text =
          [shareTitle, body].where((part) => part.isNotEmpty).join('\n\n');
      await Share.share(text, subject: shareTitle);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share note: $error')),
      );
    }
  }

  String _plainTextForSharing(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((operation) => operation['insert'])
            .whereType<String>()
            .join()
            .trim();
      }
    } on FormatException {
      return content.trim();
    }
    return content.trim();
  }

  void _showNoteDetails(NotesProvider provider, Note note) {
    final category = provider.categories
        .where((category) => category.id == note.categoryId)
        .firstOrNull;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Created: ${DateFormat('d MMM yyyy').format(note.date.toDateTime())}'),
            const SizedBox(height: 8),
            Text(
              'Last edited: ${note.lastModified == null ? 'Not available' : DateFormat('d MMM yyyy, HH:mm').format(note.lastModified!)}',
            ),
            const SizedBox(height: 8),
            Text('Folder: ${category?.name ?? 'None'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget noteRow(BuildContext context, Note n) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final category = provider.selectedCategory;
    final showNoteDate = category?.showNoteDate ?? true;
    final categoryWithoutNoteDate = category != null && !showNoteDate;
    final showLastModified =
        category?.showLastModified ?? _showLastModifiedSettings.value;
    writeLine("Title ${n.title}");

    // When dates are hidden, show the first image from the note in that slot.
    final imagePath =
        categoryWithoutNoteDate ? firstImagePath(n.displayText) : null;

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: categoryWithoutNoteDate ? 77 : 72),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: showNoteDate ? 16 : (imagePath != null ? 12 : 20),
          vertical: showNoteDate ? 8 : (imagePath != null ? 10 : 20),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showNoteDate) ...[
                SizedBox(
                  // Same width as before so titles keep their space; FittedBox
                  // scales long month names down instead of wrapping or stealing width.
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.date.isToday() ? 'today' : '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      Text(
                        n.date.day.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          DateFormat(_shortMonthOnHomeSettings.value
                                  ? 'MMM'
                                  : 'MMMM')
                              .format(n.date.toDateTime()),
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy').format(n.date.toDateTime()),
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (imagePath != null) ...[
                buildNoteImageThumbnail(imagePath, size: 56),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: n.title.isNullOrWhitespace()
                            ? _highlightedText(
                                _hideNoteTextSettings.value
                                    ? ''
                                    : n.displayText,
                                _activeQuery,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                fontSize: _previewFontSize,
                              )
                            : Text(
                                n.title!,
                                style: TextStyle(
                                  fontSize: _previewTitleFontSize,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                      ),
                    ),
                    if (showLastModified && n.lastModified != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Last edited ${DateFormat('d MMM yyyy, HH:mm').format(n.lastModified!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(_lastEditedOpacity),
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('note-${n.id}-$_noteRippleGeneration'),
        splashColor: onSurface.withOpacity(0.04),
        highlightColor: onSurface.withOpacity(0.03),
        onTap: () => _openNote(context, n),
        onLongPress: () => _showNoteActions(context, provider, n),
        child: row,
      ),
    );
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
      return Text(text,
          overflow: overflow,
          maxLines: maxLines,
          style: TextStyle(fontSize: fontSize));
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
        style: TextStyle(
            fontSize: _previewFontSize,
            color: Theme.of(context).textTheme.bodyMedium?.color),
        children: spans,
      ),
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  Widget addNoteButton(
      BuildContext context, NotesProvider provider) {
    return GestureDetector(
      onLongPress: () => _showCreateNoteMenu(context, provider),
      child: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) =>
                  NewNotePage(categoryId: provider.selectedCategory?.id),
            ),
          );
        },
        child: const Icon(
          Icons.add,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _showCreateNoteMenu(
      BuildContext context, NotesProvider provider) async {
    // Build a list of notes that can act as templates (all notes with a title or content).
    final templates = provider.notes
        .where((n) =>
            n.title?.trim().isNotEmpty == true ||
            n.displayText.trim().isNotEmpty)
        .toList();

    final action = await showModalBottomSheet<_CreateAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Create note',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('New note'),
              onTap: () => Navigator.pop(context, _CreateAction.blank),
            ),
            if (provider.categories.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('New note in folder'),
                onTap: () => Navigator.pop(context, _CreateAction.inFolder),
              ),
            if (templates.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.file_copy_outlined),
                title: const Text('New from template'),
                onTap: () => Navigator.pop(context, _CreateAction.fromTemplate),
              ),
          ],
        ),
      ),
    );

    if (!mounted || !context.mounted || action == null) return;

    switch (action) {
      case _CreateAction.blank:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) =>
                NewNotePage(categoryId: provider.selectedCategory?.id),
          ),
        );
      case _CreateAction.inFolder:
        await _createNoteInFolder(context, provider);
      case _CreateAction.fromTemplate:
        await _createNoteFromTemplate(context, provider, templates);
    }
  }

  Future<void> _createNoteInFolder(
      BuildContext context, NotesProvider provider) async {
    final targetId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose folder'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('No folder'),
                trailing: provider.selectedCategory == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, -1),
              ),
              for (final category in provider.categories)
                ListTile(
                  leading: Icon(
                    CategoryIcons.forKey(category.iconKey),
                    color: CategoryIcons.colorFor(category.iconColor),
                  ),
                  title: Text(category.name),
                  trailing: provider.selectedCategory?.id == category.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, category.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !context.mounted || targetId == null) return;
    final categoryId = targetId == -1 ? null : targetId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => NewNotePage(categoryId: categoryId),
      ),
    );
  }

  Future<void> _createNoteFromTemplate(BuildContext context,
      NotesProvider provider, List<Note> templates) async {
    final template = await showModalBottomSheet<Note>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Choose template',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  final label = t.title?.trim().isNotEmpty == true
                      ? t.title!
                      : t.displayText.trim();
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || !context.mounted || template == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => NewNotePage(
          categoryId: provider.selectedCategory?.id,
          templateNote: template,
        ),
      ),
    );
  }
}
