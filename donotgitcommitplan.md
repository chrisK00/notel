## 4. Automated Tests + Public Repo

**What it is:** Make the codebase trustworthy and shareable.

**Plan — three phases:**

### Phase 1: Unit tests (can do now)
- Parser tests already done (35 passing). ✅
- Add `DateOnly` unit tests in playground CLI: parse, toString, toDateTime, isToday, compareTo, backwards compat with old timestamp strings.
- Add `Note.fromMap` / `toMap` round-trip tests.

### Phase 2: Widget tests
- `HomePageRepository` integration test using in-memory sqflite_common_ffi: seed notes, run `findNotes()` with various queries, assert results.
- Widget test for home page note card: mock provider, verify title/date/preview display correctly.
- Widget test for search bar: type a query, verify debounce fires and list updates.

### Phase 3: Repo cleanup + CI
- `git rebase -i` to squash noisy commits (do this locally, don't automate).
- Add `.github/workflows/test.yml`:
  ```yaml
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: subosito/flutter-action@v2
        - run: flutter test
        - run: dart test
          working-directory: notel_playground_cli
  ```
- Add `.github/workflows/release.yml` triggered on `v*` tags: runs `flutter build apk --split-per-abi`, uploads APKs as GitHub Release assets.

---

## 7. Table Support Investigation (Flutter Quill)

**What it is:** Investigate feasibility, built-in support, and complexity of adding tables to the note editor using our current `flutter_quill` version (^9.5.15).

**Investigation checklist:**
- **Built-in capability:** Check if `flutter_quill` (or `flutter_quill_extensions`) has native table embed blocks or if tables require custom block embed builders (`CustomBlockEmbed`).
- **Delta format & DB compatibility:** Verify how table structures serialize into JSON Deltas and ensure DB persistence and plain-text search preview remain compatible.
- **Mobile UX feasibility:** Assess how easy/hard it is for users to edit table cells, add/delete rows & columns on mobile touch screens.
- **Decision:** If built-in/straightforward, plan toolbar button + embed builder. If overly complex or buggy on mobile touch, consider lightweight ASCII/markdown table helper or skip.

---

## 8. Formatted Copy & Paste Investigation

**What it is:** Investigate preserving text formatting (bold, italic, lists, headings, links, colors) when copying content from external apps/web into Notel and when copying out of Notel to other apps. mainly we just have to bother with copying text inside a notel note to another notel note

**Investigation checklist:**
- **External to Notel (Paste formatted text/HTML):** Check if `flutter_quill` supports HTML-to-Delta conversion on paste from system clipboard, or if an HTML/Markdown converter is needed to retain styles when pasting from browser/docs.
- **Notel to External (Copy formatted text):** Check if copying from the Quill editor can export HTML/MIME rich-text to the system clipboard (e.g. using `super_clipboard` or Quill's clipboard configurations) so pasting into email/Word preserves formatting.
- **In-App Copy/Cut/Paste:** Verify internal selection clipboard behavior across notes in Notel.

---

## 9. insert current time
we want to let users be able to change the insert current time shortcut key incase they use .. for something already.

---
