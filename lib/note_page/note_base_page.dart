import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:notel/console.dart';
import 'package:notel/dialogs/yes_or_no_dialog.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/main.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/note_text_toolbar.dart';
import 'package:notel/notes_provider.dart';
import 'package:notel/search/search_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

abstract class NoteBasePage<T extends StatefulWidget> extends State<T> {
  final controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  Note note = Note(id: 0);
  var hasUnsavedChanges = false;
  String timeShortcut = "..";
  final TextEditingController textEditingController = TextEditingController();
  StreamSubscription<DocChange>? _docChangeSub;

  List<({int offset, int length})> searchMatches = [];
  int searchMatchIndex = 0;
  bool showSearchNavigator = false;
  String searchTermsSummary = '';

  void attachDocListener() {
    _docChangeSub?.cancel();
    _docChangeSub = controller.document.changes.listen(onTextChanged);
  }

  void detachDocListener() {
    _docChangeSub?.cancel();
    _docChangeSub = null;
  }

  @override
  void initState() {
    super.initState();
    _loadTimeShortcut();
    initNote().then((_) {
      if (mounted) {
        if (searchMatches.isEmpty) setCaretToEnd();
        attachDocListener();
        setState(() => hasUnsavedChanges = false);
      }
    });
  }

  Future<void> _loadTimeShortcut() async {
    try {
      final setting = await SettingsRepository(Db.instance).getOrNull(
        StringSettings.timeShortcutKey,
        StringSettings.fromMap,
      );
      if (setting != null) {
        timeShortcut = setting.value;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    detachDocListener();
    controller.dispose();
    _focusNode.dispose();
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
    terms.addAll(query.titleTerms.map((t) => t.trim()).where((t) => t.isNotEmpty));
    terms.addAll(query.startsWithTerms.map((t) => t.trim()).where((t) => t.isNotEmpty));

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
      TextSelection(baseOffset: match.offset, extentOffset: match.offset + match.length),
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
      searchMatchIndex = (searchMatchIndex - 1 + searchMatches.length) % searchMatches.length;
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
      final changesMade = await NotePageRepository.updateNoteText(note.id, json);

      // Keep JSON on displayText so initNote() can decode it when re-entering the page.
      // The home list preview is built from the DB query, not this field.
      note.displayText = json;
      writeLine('Updated rows $changesMade');

      note.title = textEditingController.text;
      final changesMadeForTitle = await NotePageRepository.updateNoteTitle(note.id, note.title);
      writeLine('Updated titles $changesMadeForTitle');
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

    final typedSegment = plainText.substring(start, start + timeShortcut.length);
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

  void onTextChanged(DocChange event) {
    writeLine('Text changed: $event');
    setState(() => hasUnsavedChanges = true);

    _insertTimeShortcut(event);
  }

// TODO move this to edit page?
  void setCaretToEnd() => controller.moveCursorToPosition(controller.document.length);

  Future _showSaveDialog(NotesProvider notesProvider) async {
    if (hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) =>
              const YesOrNoDialog(title: "Save changes?", dangerBtnText: "ignore", successBtnText: "Save"));

      if (shouldSave == true) {
        await _onSave(notesProvider);
      }
    }
  }

  Future<void> _handleBackNavigation(NotesProvider notesProvider) async {
    await _showSaveDialog(notesProvider);
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
            if (showSearchNavigator && searchMatches.isNotEmpty) searchNavigatorBanner(),
            Expanded(
                child: QuillEditor.basic(
                    focusNode: _focusNode,
                    configurations: QuillEditorConfigurations(
                        autoFocus: true,
                        controller: controller,
                        padding: const EdgeInsets.only(left: 25, right: 25, top: 20),
                        expands: true))),
          ],
        ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: NoteTextToolbar(controller: controller),
            )),
      );
    });
  }

  Widget actions(BuildContext context, NotesProvider notesProvider) {
    return SafeArea(
      bottom: false,
      top: true,
      child: Padding(
        padding: const EdgeInsets.only(right: 5, left: 5),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              PopupMenuButton<int>(
                  offset: Offset.fromDirection(3, 10),
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
                                title: "Delete Note?", dangerBtnText: "Delete", successBtnText: "Cancel"));

                        if (shouldCancel == null || shouldCancel) {
                          return;
                        }

                        await notesProvider.remove(note.id);
                        note.displayText = "";
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        break;
                      default:
                    }
                  },
                  iconColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                  itemBuilder: (context) => [
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
                            children: [Icon(Icons.folder_outlined), Text("category")],
                          ),
                        ),
                        const PopupMenuItem<int>(
                          value: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [Icon(Icons.delete), Text("delete")],
                          ),
                        )
                      ])
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      iconSize: 30,
                      onPressed: () async => _handleBackNavigation(notesProvider),
                      icon: const Icon(Icons.arrow_back)),
                  Column(
                    children: [
                      TextButton(
                          onPressed: () async => await updateDate(notesProvider),
                          child: Text(
                            DateFormat('d MMMM yyyy').format(note.date.toDateTime()),
                          )),
                      SizedBox(
                        width: 250,
                        height: 40,
                        child: Opacity(
                            opacity: 0.9,
                            child: TextField(
                              controller: textEditingController,
                              onChanged: (_) => setState(() => hasUnsavedChanges = true),
                            )),
                      )
                    ],
                  ),
                  saveButton(notesProvider)
                ],
              ),
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
                      trailing: note.categoryId == null ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () async {
                        await NotePageRepository.updateNoteCategory(note.id, null);
                        setState(() => note.categoryId = null);
                        await notesProvider.update(note.id);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    ),
                    const Divider(),
                    if (notesProvider.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No categories created yet', style: TextStyle(color: Colors.grey)),
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
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(category.name),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                              onTap: () async {
                                await NotePageRepository.updateNoteCategory(note.id, category.id);
                                setState(() => note.categoryId = category.id);
                                await notesProvider.update(note.id);
                                if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                    final newCategory = await showDialog<Category?>(
                      context: context,
                      builder: (newCatCtx) => AlertDialog(
                        title: const Text('New Category'),
                        content: Form(
                          key: formKey,
                          child: TextFormField(
                            controller: textController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Category name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
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
                                final created = await notesProvider.createCategory(textController.text.trim());
                                if (newCatCtx.mounted) Navigator.pop(newCatCtx, created);
                              }
                            },
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    );
                    if (newCategory != null) {
                      await NotePageRepository.updateNoteCategory(note.id, newCategory.id);
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
          Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.primary),
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
