import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:notel/edit_page/edit_page_repository.dart';
import 'package:notel/infrastructure/note.dart';

class NotesProvider extends ChangeNotifier {
  static const int _noteDisplayTextLength = 36;
  final List<Note> _notes = [];

  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);

  void init(Iterable<Note> notes) {
    _notes.clear();
    _notes.addAll(notes);
    notifyListeners();
  }

  void update(Note noteToUpdate) {
    _trimText(noteToUpdate);
    final index = _notes.indexWhere((note) => note.id == noteToUpdate.id);
    _notes[index].date = noteToUpdate.date;
    _notes[index].text = noteToUpdate.text;

    _sortNotes();
    notifyListeners();
  }

  void add(Note note) {
    _trimText(note);
    _notes.add(note);
    _sortNotes();

    notifyListeners();
  }

  Future remove(int noteId) async {
    await EditPageRepository.deleteNote(noteId);
    _notes.removeWhere((note) => note.id == noteId);
    notifyListeners();
  }

  void _trimText(Note note) {
    final cutOfLength = min(_noteDisplayTextLength, note.text.length);
    note.text = note.text.substring(0, cutOfLength);
  }

  void _sortNotes() {
    _notes.sort((a, b) => b.date.compareTo(a.date));
  }
}
