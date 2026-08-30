import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/category_repository.dart';
import 'package:notel/main.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/home_page/home_page_repository.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';

class NotesProvider extends ChangeNotifier {
  final List<Note> _notes = [];
  final List<Category> _categories = [];
  Category? _selectedCategory;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  NoteSort _sort = NoteSort.created;

  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);
  UnmodifiableListView<Category> get categories => UnmodifiableListView(_categories);
  Category? get selectedCategory => _selectedCategory;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  NoteSort get sort => _sort;

  void init(Iterable<Note> notes) {
    final noteList = notes.toList();
    _notes.clear();
    _notes.addAll(noteList);
    _hasMore = noteList.length >= HomePageRepository.pageSize;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      final list = await CategoryRepository.getAll();
      _categories.clear();
      _categories.addAll(list);
      // Sync selectedCategory instance if it was updated or deleted
      if (_selectedCategory != null) {
        final match = _categories.where((c) => c.id == _selectedCategory!.id).firstOrNull;
        _selectedCategory = match;
      }
      notifyListeners();
    } catch (e) {
      AppErrors.showError('Failed to load categories.');
    }
  }

  Future<void> setSelectedCategory(Category? category) async {
    _selectedCategory = category;
    final key = 'noteSort:${category?.id ?? 'all'}';
    final saved = await SettingsRepository(Db.instance).getOrNull(key, StringSettings.fromMap);
    _sort = NoteSort.values.firstWhere((s) => s.name == saved?.value, orElse: () => NoteSort.created);
    final loadedNotes = await HomePageRepository.loadNotes(categoryId: category?.id, sort: _sort);
    init(loadedNotes);
  }

  Future<void> clearSelectedCategory() async {
    if (_selectedCategory == null) return;
    _selectedCategory = null;
    _sort = NoteSort.created;
    final loadedNotes = await HomePageRepository.loadNotes(sort: NoteSort.created);
    init(loadedNotes);
  }

  Future<void> setSort(NoteSort sort) async {
    _sort = sort;
    await SettingsRepository(Db.instance).insertOrUpdate(
      'noteSort:${_selectedCategory?.id ?? 'all'}',
      () => StringSettings('noteSort:${_selectedCategory?.id ?? 'all'}', sort.name).toMap(),
    );
    final loadedNotes = await HomePageRepository.loadNotes(categoryId: _selectedCategory?.id, sort: sort);
    init(loadedNotes);
  }

  Future<void> setCategoryHomeVisibility(bool shown) async {
    final category = _selectedCategory;
    if (category == null) return;
    await NotePageRepository.setCategoryNotesHidden(category.id, !shown);
    final key = StringSettings.categoryHiddenDefaultKey(category.id);
    await SettingsRepository(Db.instance).insertOrUpdate(
      key, () => StringSettings(key, (!shown).toString()).toMap());
    init(await HomePageRepository.loadNotes(categoryId: category.id, sort: _sort));
  }

  Future<Category?> createCategory(String name) async {
    try {
      final category = await CategoryRepository.create(name);
      await loadCategories();
      return category;
    } catch (e) {
      AppErrors.showError('Failed to create category.');
      return null;
    }
  }

  Future<void> updateCategoryName(int id, String name) async {
    try {
      await CategoryRepository.updateName(id, name);
      if (_selectedCategory != null && _selectedCategory!.id == id) {
        _selectedCategory!.name = name.trim();
      }
      await loadCategories();
    } catch (e) {
      AppErrors.showError('Failed to update category name.');
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await CategoryRepository.delete(id);
      if (_selectedCategory != null && _selectedCategory!.id == id) {
        _selectedCategory = null;
        _sort = NoteSort.created;
      }
      await loadCategories();
      final loadedNotes = await HomePageRepository.loadNotes(categoryId: _selectedCategory?.id, sort: _selectedCategory == null ? NoteSort.created : _sort);
      init(loadedNotes);
    } catch (e) {
      AppErrors.showError('Failed to delete category.');
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = (await HomePageRepository.loadNotes(
        offset: _notes.length,
        categoryId: _selectedCategory?.id,
        sort: _sort,
      )).toList();
      _notes.addAll(nextPage);
      _hasMore = nextPage.length >= HomePageRepository.pageSize;
    } catch (e) {
      AppErrors.showError('Failed to load more notes.');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future update(int noteId) async {
    final note = await HomePageRepository.loadNote(noteId);
    if (note == null) {
      return;
    }

    final index = _notes.indexWhere((n) => n.id == noteId);

    // If currently filtered by category and note no longer in category, remove from list
    if (_selectedCategory != null && note.categoryId != _selectedCategory!.id) {
      if (index != -1) {
        _notes.removeAt(index);
        notifyListeners();
      }
      return;
    }

    if (index != -1) {
      _notes[index].date = note.date;
      _notes[index].displayText = note.displayText;
      _notes[index].title = note.title;
      _notes[index].lastModified = note.lastModified;
      _notes[index].categoryId = note.categoryId;
    } else if (_selectedCategory == null || note.categoryId == _selectedCategory!.id) {
      _notes.add(note);
    }

    _sortNotes();
    notifyListeners();
  }

  void add(Note note) {
    if (_selectedCategory == null || note.categoryId == _selectedCategory!.id) {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
      } else {
        _notes.add(note);
      }
      _sortNotes();
      notifyListeners();
    }
  }

  Future remove(int noteId) async {
    try {
      await NotePageRepository.deleteNote(noteId);
      _notes.removeWhere((note) => note.id == noteId);
      notifyListeners();
    } catch (e) {
      AppErrors.showError('Failed to delete note.');
    }
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (_sort == NoteSort.name) {
        final nameComp = (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase());
        if (nameComp != 0) return nameComp;
        return b.id.compareTo(a.id);
      } else if (_sort == NoteSort.modified) {
        final aModified = a.lastModified;
        final bModified = b.lastModified;
        if (aModified != null || bModified != null) {
          if (aModified == null) return 1;
          if (bModified == null) return -1;
          final modifiedComp = bModified.compareTo(aModified);
          if (modifiedComp != 0) return modifiedComp;
          return b.id.compareTo(a.id);
        }
        return b.id.compareTo(a.id);
      }
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return b.id.compareTo(a.id);
    });
  }
}
