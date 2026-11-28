import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:notel/console.dart';
import 'package:notel/dialogs/yes_or_no_dialog.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/category_icons.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/editor_shortcut.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/main.dart';
import 'package:notel/home_page/category_icon_picker.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/section_divider.dart';
import 'package:notel/note_page/exercise_embed.dart';
import 'package:notel/note_page/note_attachments_sheet.dart';
import 'package:notel/note_page/image_embed.dart';
import 'package:notel/note_page/note_text_toolbar.dart';
import 'package:notel/notes_provider.dart';
import 'package:notel/search/search_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class _FastCaretScrollController extends ScrollController {
  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) {
    return super.animateTo(
      offset,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
  }
}

abstract class NoteBasePage<T extends StatefulWidget> extends State<T> {
  final controller = QuillController(
    document: Document(),
    selection: const TextSelection.collapsed(offset: 0),
    keepStyleOnNewLine: false,
  );
  final FocusNode _focusNode = FocusNode();
  // Shared with Quill (scrollable: false) so its caret-follow scrolls this view
  // only when the caret would otherwise be off-screen.
  final ScrollController _scrollController = _FastCaretScrollController();
  Note note = Note(id: 0);
  var hasUnsavedChanges = false;
  String timeShortcut = "..";
  List<EditorShortcut> editorShortcuts = [];
  bool get isNewNote => false;
  bool _autoEditExistingNotes = false;
  bool _isDocEmpty = false;
  bool get shouldAutoFocus =>
      isNewNote || _isDocEmpty || _autoEditExistingNotes;
  final TextEditingController textEditingController = TextEditingController();
  StreamSubscription<DocChange>? _docChangeSub;
  bool _isExpandingShortcut = false;

  List<({int offset, int length})> searchMatches = [];
  int searchMatchIndex = 0;
  bool showSearchNavigator = false;
  String searchTermsSummary = '';
  bool _keepScreenOn = false;

  void attachDocListener() {
    _docChangeSub?.cancel();
    _docChangeSub = controller.document.changes.listen(onTextChanged);
  }

  void detachDocListener() {
    _docChangeSub?.cancel();
    _docChangeSub = null;
  }

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _focusNode.canRequestFocus = isNewNote;
    _lifecycleListener = AppLifecycleListener(
      onInactive: _saveOnAppBackground,
      onPause: _saveOnAppBackground,
      onHide: _saveOnAppBackground,
      onDetach: _saveOnAppBackground,
    );
    _initAll();
  }

  Future<void> _initAll() async {
    await Future.wait([
      _loadSettings(),
      initNote(),
    ]);
    if (mounted) {
      _isDocEmpty = controller.document.toPlainText().trim().isEmpty;
      if (shouldAutoFocus) {
        _focusNode.canRequestFocus = true;
        if (searchMatches.isEmpty) {
          setCaretToEnd();
        }
        _focusNode.requestFocus();
      } else {
        _focusNode.canRequestFocus = false;
        _focusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
      attachDocListener();
      setState(() => hasUnsavedChanges = false);
      await _recordActiveNote();
    }
  }

  void _saveOnAppBackground() {
    if (hasUnsavedChanges && mounted) {
      try {
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        _onSave(notesProvider);
      } catch (_) {}
    }
  }

  Future<void> _recordActiveNote() async {
    if (note.id > 0) {
      try {
        await SettingsRepository(Db.instance).insertOrUpdate(
          StringSettings.activeNoteIdKey,
          () => StringSettings(
            StringSettings.activeNoteIdKey,
            note.id.toString(),
          ).toMap(),
        );
      } catch (_) {}
    }
  }

  Future<void> _clearActiveNote() async {
    try {
      await SettingsRepository(Db.instance).insertOrUpdate(
        StringSettings.activeNoteIdKey,
        () => StringSettings(StringSettings.activeNoteIdKey, '').toMap(),
      );
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final repository = SettingsRepository(Db.instance);
      final rows = await repository.db.query(
        Db.settingsTable,
        where: 'id IN (?, ?, ?)',
        whereArgs: [
          StringSettings.timeShortcutKey,
          StringSettings.editorShortcutsKey,
          BoolSettings.autoEditExistingNotesKey,
        ],
      );
      if (!mounted) return;
      for (final row in rows) {
        final id = row['id'] as String?;
        final value = row['value'] as String?;
        if (id == StringSettings.timeShortcutKey && value != null) {
          timeShortcut = value;
        } else if (id == StringSettings.editorShortcutsKey && value != null) {
          editorShortcuts = EditorShortcut.decodeList(value);
        } else if (id == BoolSettings.autoEditExistingNotesKey && value != null) {
          _autoEditExistingNotes = bool.tryParse(value) ?? false;
        }
      }
    } catch (_) {}
  }

  void handleBottomTap() {
    _focusNode.canRequestFocus = true;
    final plainText = controller.document.toPlainText();
    if (plainText.trim().isEmpty) {
      controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
    } else if (plainText.endsWith('\n\n')) {
      controller.updateSelection(
        TextSelection.collapsed(offset: controller.document.length - 1),
        ChangeSource.local,
      );
    } else {
      final insertPos = controller.document.length - 1;
      detachDocListener();
      try {
        controller.replaceText(
          insertPos,
          0,
          '\n',
          TextSelection.collapsed(offset: insertPos + 1),
        );
      } finally {
        attachDocListener();
      }
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    detachDocListener();
    controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    // Always release the wakelock when leaving the note.
    if (_keepScreenOn) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  Future initNote();
  Future navigateToPreviousPage(BuildContext context, NotesProvider provider);

  void highlightSearchTerms(SearchQuery? query) {
    if (query == null || query.isEmpty) return;

    final terms = <String>{};
    for (final group in query.textOrGroups) {
      terms.addAll(group.map((t) => t.trim()).where((t) => t.isNotEmpty));
    }
    terms.addAll(
        query.titleTerms.map((t) => t.trim()).where((t) => t.isNotEmpty));
    terms.addAll(
        query.startsWithTerms.map((t) => t.trim()).where((t) => t.isNotEmpty));

    if (terms.isEmpty) return;

    final plainText = controller.document.toPlainText();
    if (plainText.isEmpty) return;

    final matches = <({int offset, int length})>[];
    for (final term in terms) {
      final regex = RegExp(RegExp.escape(term), caseSensitive: false);
      for (final match in regex.allMatches(plainText)) {
        matches.add((offset: match.start, length: match.end - match.start));
      }
    }

    if (matches.isEmpty) return;

    matches.sort((a, b) => a.offset.compareTo(b.offset));

    final wasUnsaved = hasUnsavedChanges;
    detachDocListener();
    const bgAttr = BackgroundAttribute('#6750A4');
    const colorAttr = ColorAttribute('#FFFFFF');
    for (final m in matches) {
      controller.formatText(m.offset, m.length, bgAttr);
      controller.formatText(m.offset, m.length, colorAttr);
    }
    attachDocListener();

    setState(() {
      hasUnsavedChanges = wasUnsaved;
      searchMatches = matches;
      searchMatchIndex = 0;
      showSearchNavigator = true;
      searchTermsSummary = terms.join(', ');
    });

    _jumpToSearchMatch(0);
  }

  void _jumpToSearchMatch(int index) {
    if (index < 0 || index >= searchMatches.length) return;
    final match = searchMatches[index];
    controller.updateSelection(
      TextSelection(
          baseOffset: match.offset, extentOffset: match.offset + match.length),
      ChangeSource.local,
    );
  }

  void nextSearchMatch() {
    if (searchMatches.isEmpty) return;
    setState(() {
      searchMatchIndex = (searchMatchIndex + 1) % searchMatches.length;
    });
    _jumpToSearchMatch(searchMatchIndex);
  }

  void previousSearchMatch() {
    if (searchMatches.isEmpty) return;
    setState(() {
      searchMatchIndex =
          (searchMatchIndex - 1 + searchMatches.length) % searchMatches.length;
    });
    _jumpToSearchMatch(searchMatchIndex);
  }

  void clearSearchHighlights() {
    if (searchMatches.isNotEmpty) {
      final wasUnsaved = hasUnsavedChanges;
      detachDocListener();
      final clearBg = Attribute.clone(Attribute.background, null);
      final clearColor = Attribute.clone(Attribute.color, null);
      for (final m in searchMatches) {
        controller.formatText(m.offset, m.length, clearBg);
        controller.formatText(m.offset, m.length, clearColor);
      }
      attachDocListener();
      setState(() {
        hasUnsavedChanges = wasUnsaved;
        searchMatches = [];
        showSearchNavigator = false;
      });
    } else {
      setState(() {
        showSearchNavigator = false;
      });
    }
  }

  Future _onSave(NotesProvider notesProvider) async {
    setState(() => hasUnsavedChanges = false);
    clearSearchHighlights();
    final json = jsonEncode(controller.document.toDelta().toJson());
    try {
      final changesMade =
          await NotePageRepository.updateNoteText(note.id, json);

      // Keep JSON on displayText so initNote() can decode it when re-entering the page.
      // The home list preview is built from the DB query, not this field.
      note.displayText = json;
      writeLine('Updated rows $changesMade');

      note.title = textEditingController.text;
      final changesMadeForTitle =
          await NotePageRepository.updateNoteTitle(note.id, note.title);
      writeLine('Updated titles $changesMadeForTitle');
      if (mounted) {
        setState(() => note.lastModified = DateTime.now());
      }
      await notesProvider.update(note.id);
      AutoBackupService.checkAndRun();
    } catch (e) {
      setState(() => hasUnsavedChanges = true);
      AppErrors.showError('Failed to save note. Please try again.');
      writeLine('Update failed, error: $e');
    }
  }

  void _insertTimeShortcut(DocChange event) {
    if (timeShortcut.isEmpty) return;

    final operations = event.change.operations;
    if (operations.isEmpty || !operations.last.isInsert) return;

    final data = operations.last.data;
    if (data is! String) return;

    final baseOffset = controller.selection.baseOffset;
    if (baseOffset < timeShortcut.length) return;

    final plainText = controller.document.toPlainText();
    final start = baseOffset - timeShortcut.length;
    if (start < 0 || start + timeShortcut.length > plainText.length) return;

    final typedSegment =
        plainText.substring(start, start + timeShortcut.length);
    if (typedSegment != timeShortcut) return;

    final hour = DateTime.now().hour.toString().padLeft(2, '0');
    final minute = DateTime.now().minute.toString().padLeft(2, '0');
    final replacementText = "$hour.$minute ";

    controller.replaceText(
      start,
      timeShortcut.length,
      replacementText,
      TextSelection.collapsed(offset: start + replacementText.length),
    );

    controller.formatText(
      start,
      replacementText.length,
      Attribute.bold,
    );

    controller.formatSelection(Attribute.clone(Attribute.bold, null));
  }

  void _insertEditorShortcut(DocChange event) {
    final operations = event.change.operations;
    if (operations.isEmpty || !operations.last.isInsert) return;
    if (operations.last.data is! String) return;

    final baseOffset = controller.selection.baseOffset;
    final plainText = controller.document.toPlainText();
    // Prefer the longest trigger when one shortcut is the suffix of another.
    final shortcuts = [...editorShortcuts]
      ..sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
    for (final shortcut in shortcuts) {
      if (baseOffset < shortcut.trigger.length) continue;
      final start = baseOffset - shortcut.trigger.length;
      if (start + shortcut.trigger.length > plainText.length ||
          plainText.substring(start, start + shortcut.trigger.length) !=
              shortcut.trigger) {
        continue;
      }

      _isExpandingShortcut = true;
      try {
        controller.replaceText(
          start,
          shortcut.trigger.length,
          shortcut.replacement,
          TextSelection.collapsed(offset: start + shortcut.replacement.length),
        );
        if (shortcut.bold) {
          controller.formatText(
              start, shortcut.replacement.length, Attribute.bold);
          controller.formatSelection(Attribute.clone(Attribute.bold, null));
        }
      } finally {
        _isExpandingShortcut = false;
      }
      return;
    }
  }

  void onTextChanged(DocChange event) {
    writeLine('Text changed: $event');
    setState(() => hasUnsavedChanges = true);

    if (!_isExpandingShortcut) {
      _insertTimeShortcut(event);
      _insertEditorShortcut(event);
    }
  }

// TODO move this to edit page?
  void setCaretToEnd() {
    final pos =
        controller.document.length > 0 ? controller.document.length - 1 : 0;
    controller.updateSelection(
      TextSelection.collapsed(offset: pos),
      ChangeSource.local,
    );
  }

  Future _showSaveDialog(NotesProvider notesProvider) async {
    if (hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => const YesOrNoDialog(
              title: "Save changes?",
              dangerBtnText: "ignore",
              successBtnText: "Save"));

      if (shouldSave == true) {
        await _onSave(notesProvider);
      }
    }
  }

  Future<void> _handleBackNavigation(NotesProvider notesProvider) async {
    await _showSaveDialog(notesProvider);
    await _clearActiveNote();
    if (!mounted) return;
    await navigateToPreviousPage(context, notesProvider);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _shareNote() async {
    final plainText = controller.document.toPlainText().trim();
    final title = textEditingController.text.trim();
    final shareTitle = title.isEmpty ? 'Notel note' : title;
    final body = StringBuffer()
      ..writeln(shareTitle)
      ..writeln(DateFormat('d MMMM yyyy').format(note.date.toDateTime()));

    if (plainText.isNotEmpty) {
      body.writeln();
      body.writeln(plainText);
    }

    await Share.share(
      body.toString().trim(),
      subject: shareTitle,
    );
  }

  Future<void> _showAttachments() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteAttachmentsSheet(document: controller.document),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleBackNavigation(provider);
        },
        child: Scaffold(
            body: Column(
          children: [
            actions(context, provider),
            if (showSearchNavigator && searchMatches.isNotEmpty)
              searchNavigatorBanner(),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Title scrolls away with the note body and follows the action row.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Opacity(
                        opacity: 0.9,
                        child: TextField(
                          key: const ValueKey('note-title'),
                          controller: textEditingController,
                          onChanged: (_) =>
                              setState(() => hasUnsavedChanges = true),
                          maxLines: null,
                          minLines: 1,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Note body; CustomScrollView owns all scrolling
                  SliverToBoxAdapter(
                    child: QuillEditor(
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      configurations: QuillEditorConfigurations(
                        autoFocus: shouldAutoFocus,
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        expands: false,
                        scrollable: false,
                        embedBuilders: const [
                          SectionDividerEmbedBuilder(),
                          ExerciseEmbedBuilder(),
                          ImageEmbedBuilder(),
                        ],
                        onTapDown: (details, getPositionForOffset) {
                          _focusNode.canRequestFocus = true;
                          return false;
                        },
                        onTapUp: (details, getPositionForOffset) {
                          _focusNode.canRequestFocus = true;
                          return false;
                        },
                      ),
                    ),
                  ),
                  // Bottom tap area to create newline / focus like Google Keep
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: handleBottomTap,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 120),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: NoteTextToolbar(controller: controller, noteId: note.id),
            ),
          ],
        )),
      );
    });
  }

  // Spacing before the button row moves the buttons and title below together.
  static const double _backSaveDownShift = 18;

  static final _backSaveIconStyle = IconButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    minimumSize: const Size(48, 40),
  );

  /// Date above title when the note is visible on home with dates enabled;
  /// otherwise it lives in the ⋮ details menu (less distracting).
  bool _showDateAboveTitle(NotesProvider notesProvider) {
    if (note.hidden) return false;
    final category = note.categoryId == null
        ? null
        : notesProvider.categories
            .where((c) => c.id == note.categoryId)
            .firstOrNull;
    return category?.showNoteDate ?? true;
  }

  /// A compact button shown in the action bar when date is hidden.
  /// Tapping it inserts an image at the beginning of the note (cover image).
  /// If the note already starts with an image it shows a thumbnail instead.
  Widget _coverImageButton() {
    final firstPath = firstImagePath(
        jsonEncode(controller.document.toDelta().toJson()));
    if (firstPath != null) {
      return GestureDetector(
        onTap: () => pickAndInsertImage(context, controller),
        child: buildNoteImageThumbnail(firstPath, size: 36),
      );
    }
    return IconButton(
      tooltip: 'Add cover image',
      icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      onPressed: () => pickAndInsertImage(context, controller),
    );
  }

  Widget actions(BuildContext context, NotesProvider notesProvider) {    final showDateAboveTitle = _showDateAboveTitle(notesProvider);
    return SafeArea(
      bottom: false,
      top: true,
      child: Padding(
        padding: const EdgeInsets.only(right: 5, left: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⋮ stays tight at the top.
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Attachments',
                icon: const Icon(Icons.attach_file),
                onPressed: _showAttachments,
              ),
              PopupMenuButton<int>(
                  offset: Offset.fromDirection(3, 10),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 28),
                  ),
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (selected) async {
                    switch (selected) {
                      case 1:
                        await _shareNote();
                        break;
                      case 2:
                        await _selectCategory(notesProvider);
                        break;
                      case 3:
                        final shouldCancel = await showDialog<bool>(
                            context: context,
                            builder: (context) => const YesOrNoDialog(
                                title: "Delete Note?",
                                dangerBtnText: "Delete",
                                successBtnText: "Cancel"));

                        if (shouldCancel == null || shouldCancel) {
                          return;
                        }

                        await notesProvider.remove(note.id);
                        note.displayText = "";
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        break;
                      case 4:
                        if (note.categoryId == null) break;
                        await NotePageRepository.setHiddenFromHome(
                            note.id, !note.hidden);
                        setState(() => note.hidden = !note.hidden);
                        break;
                      case 5:
                        await updateDate(notesProvider);
                        break;
                      case 6:
                        final next = !_keepScreenOn;
                        setState(() => _keepScreenOn = next);
                        if (next) {
                          await WakelockPlus.enable();
                        } else {
                          await WakelockPlus.disable();
                        }
                        break;
                      default:
                    }
                  },
                  iconColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                  itemBuilder: (context) => [
                        if (note.lastModified != null)
                          PopupMenuItem<int>(
                            enabled: false,
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Edited ${DateFormat('d MMM, HH:mm').format(note.lastModified!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (!showDateAboveTitle)
                          PopupMenuItem<int>(
                            value: 5,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Created ${DateFormat('d MMMM yyyy').format(note.date.toDateTime())}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [Icon(Icons.share), Text("share")],
                          ),
                        ),
                        const PopupMenuItem<int>(
                          value: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(Icons.folder_outlined),
                              Text("category")
                            ],
                          ),
                        ),
                        if (note.categoryId != null)
                          PopupMenuItem<int>(
                            value: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(note.hidden
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                Text(note.hidden
                                    ? 'unhide from home'
                                    : 'hide from home'),
                              ],
                            ),
                          ),
                        const PopupMenuItem<int>(
                          value: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [Icon(Icons.delete), Text("delete")],
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: 6,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(_keepScreenOn
                                  ? Icons.screen_lock_portrait
                                  : Icons.stay_current_portrait),
                              Text(_keepScreenOn
                                  ? 'allow sleep'
                                  : 'keep screen on'),
                            ],
                          ),
                        ),
                      ])
            ]),
            // Moves the buttons and title below together.
            const SizedBox(height: _backSaveDownShift),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    iconSize: 30,
                    style: _backSaveIconStyle,
                    onPressed: () async => _handleBackNavigation(notesProvider),
                    icon: const Icon(Icons.arrow_back)),
                if (showDateAboveTitle)
                  TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      onPressed: () async => await updateDate(notesProvider),
                      child: Text(
                        DateFormat('d MMMM yyyy')
                            .format(note.date.toDateTime()),
                      ))
                else
                  _coverImageButton(),
                saveButton(notesProvider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future updateDate(NotesProvider notesProvider) async {
    final today = DateTime.now();
    final newDate = await showDatePicker(
        initialDate: note.date.toDateTime(),
        currentDate: note.date.toDateTime(),
        context: context,
        firstDate: DateTime(today.year - 1, 1, 1),
        lastDate: today);
    if (newDate != null) {
      await NotePageRepository.updateNoteDate(note.id, newDate);
      setState(() {
        note.date = DateOnly.fromDateTime(newDate);
      });
      notesProvider.update(note.id);
    }
  }

  Future<void> _selectCategory(NotesProvider notesProvider) async {
    await notesProvider.loadCategories();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('None'),
                      trailing: note.categoryId == null
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () async {
                        await NotePageRepository.updateNoteCategory(
                            note.id, null);
                        setState(() => note.categoryId = null);
                        await notesProvider.update(note.id);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    ),
                    const Divider(),
                    if (notesProvider.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No categories created yet',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: notesProvider.categories.length,
                          itemBuilder: (context, index) {
                            final category = notesProvider.categories[index];
                            final isSelected = note.categoryId == category.id;
                            return ListTile(
                              minTileHeight: 60,
                              leading: Icon(
                                CategoryIcons.forKey(category.iconKey),
                                color:
                                    CategoryIcons.colorFor(category.iconColor),
                                size: 24,
                              ),
                              title: Text(category.name),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () async {
                                await NotePageRepository.updateNoteCategory(
                                    note.id, category.id);
                                setState(() => note.categoryId = category.id);
                                await notesProvider.update(note.id);
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Category'),
                  onPressed: () async {
                    final textController = TextEditingController();
                    final formKey = GlobalKey<FormState>();
                    var selectedIconKey = 'folder_outlined';
                    int? selectedIconColor;
                    final newCategory = await showDialog<Category?>(
                      context: context,
                      builder: (newCatCtx) => StatefulBuilder(
                        builder: (context, setDialogState) => AlertDialog(
                          scrollable: true,
                          title: const Text('New Category'),
                          content: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: textController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Category name',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Name required'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('Icon'),
                                    const SizedBox(width: 8),
                                    Icon(
                                      CategoryIcons.forKey(selectedIconKey),
                                      color: CategoryIcons.colorFor(
                                          selectedIconColor),
                                    ),
                                  ],
                                ),
                                CategoryIconPicker(
                                  selectedKey: selectedIconKey,
                                  onSelected: (key) => setDialogState(
                                      () => selectedIconKey = key),
                                ),
                                CategoryColorPicker(
                                  selectedColor: selectedIconColor,
                                  onSelected: (color) => setDialogState(
                                      () => selectedIconColor = color),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(newCatCtx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  final created =
                                      await notesProvider.createCategory(
                                    textController.text.trim(),
                                    iconKey: selectedIconKey,
                                    iconColor: selectedIconColor,
                                  );
                                  if (newCatCtx.mounted)
                                    Navigator.pop(newCatCtx, created);
                                }
                              },
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (newCategory != null) {
                      await NotePageRepository.updateNoteCategory(
                          note.id, newCategory.id);
                      setState(() => note.categoryId = newCategory.id);
                      await notesProvider.update(note.id);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget saveButton(notesProvider) {
    return Opacity(
      opacity: hasUnsavedChanges ? 1 : 0,
      child: IconButton(
          iconSize: 30,
          style: _backSaveIconStyle,
          onPressed: () async => _onSave(notesProvider),
          icon: Icon(Icons.save, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget searchNavigatorBanner() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${searchMatchIndex + 1}/${searchMatches.length} for "$searchTermsSummary"',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
            onPressed: previousSearchMatch,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
            onPressed: nextSearchMatch,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close search highlights',
            visualDensity: VisualDensity.compact,
            onPressed: clearSearchHighlights,
          ),
        ],
      ),
    );
  }
}
