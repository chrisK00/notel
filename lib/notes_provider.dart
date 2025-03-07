import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/home_page/home_page_repository.dart';
import 'package:notel/infrastructure/note.dart';

class NotesProvider extends ChangeNotifier {
  final List<Note> _notes = [];

  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);

  void init(Iterable<Note> notes) {
    _notes.clear();
    _notes.addAll(notes);
    notifyListeners();
  }

  Future update(int noteId) async {
    final note = await HomePageRepository.loadNote(noteId);
    if (note == null) {
      return;
    }

    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index != -1) {
      _notes[index].date = note.date;
      _notes[index].displayText = note.displayText;
      _notes[index].title = note.title;
    }

    _sortNotes();
    notifyListeners();
  }

  void add(Note note) {
    _notes.add(note);
    _sortNotes();
    notifyListeners();
  }

  Future remove(int noteId) async {
    await NotePageRepository.deleteNote(noteId);
    _notes.removeWhere((note) => note.id == noteId);
    notifyListeners();
  }

  void _sortNotes() {
    _notes.sort((a, b) => b.date.compareTo(a.date));
  }
}
