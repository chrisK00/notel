import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/category_repository.dart';
import 'package:notel/main.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/home_page/home_page_repository.dart';
import 'package:notel/infrastructure/note.dart';

class NotesProvider extends ChangeNotifier {
  final List<Note> _notes = [];
  final List<Category> _categories = [];
  Category? _selectedCategory;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);
  UnmodifiableListView<Category> get categories => UnmodifiableListView(_categories);
  Category? get selectedCategory => _selectedCategory;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

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
    final loadedNotes = await HomePageRepository.loadNotes(categoryId: category?.id);
    init(loadedNotes);
  }

  Future<void> clearSelectedCategory() async {
    if (_selectedCategory == null) return;
    _selectedCategory = null;
    final loadedNotes = await HomePageRepository.loadNotes();
    init(loadedNotes);
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
      }
      await loadCategories();
      final loadedNotes = await HomePageRepository.loadNotes(categoryId: _selectedCategory?.id);
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
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      if (a.lastModified != null && b.lastModified != null) {
        final modComp = b.lastModified!.compareTo(a.lastModified!);
        if (modComp != 0) return modComp;
      } else if (a.lastModified != null) {
        return -1;
      } else if (b.lastModified != null) {
        return 1;
      }
      return b.id.compareTo(a.id);
    });
  }
}
