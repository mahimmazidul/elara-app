import 'package:elara_app/utils/history_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saying out loud what the numbers already imply.
///
/// The failure this prevents is a confident date on top of a history with a
/// two-month hole in it. The app cannot know a period went unlogged, so it says
/// what it can see — this gap is about twice her usual one — and leaves the
/// conclusion to her.
void main() {
  DateTime day(int month, int day) => DateTime(2026, month, day);

  List<DateTime> starts(List<int> gaps, {DateTime? from}) {
    var cursor = from ?? day(1, 1);
    final out = <DateTime>[cursor];
    for (final gap in gaps) {
      cursor = cursor.add(Duration(days: gap));
      out.add(cursor);
    }
    return out;
  }

  test('nothing is said about a short, steady history', () {
    final notes = HistoryQuality.notesFor(
      starts: starts([28, 28, 29, 28]),
      windowDays: 2,
    );
    expect(notes, isEmpty);
  });

  test('a wide window is named, because a range is the estimate', () {
    final notes = HistoryQuality.notesFor(
      starts: starts([24, 33, 27, 36]),
      windowDays: 9,
    );
    expect(notes, hasLength(1));
    expect(notes.single.kind, HistoryNoteKind.spread);
    expect(notes.single.message, contains('range rather than a day'));
  });

  test('a gap of about twice her usual interval is called a gap', () {
    final notes = HistoryQuality.notesFor(
      // The gap is the most recent interval: a period that was never logged.
      starts: starts([28, 29, 28, 59]),
      windowDays: 4,
    );
    expect(notes, hasLength(1));
    expect(notes.single.kind, HistoryNoteKind.recordingGap);
    expect(notes.single.message, contains('59 days'));
    // It does not diagnose anything, and it does not delete the observation.
    expect(notes.single.message, contains('went unrecorded'));
  });

  test('a genuinely long but steady cycle is left alone', () {
    // 45-day cycles are hers. Compared with herself, the latest interval is
    // unremarkable, and the app must not keep telling her she is a gap.
    final notes = HistoryQuality.notesFor(
      starts: starts([45, 44, 46, 45]),
      windowDays: 3,
    );
    expect(notes, isEmpty);
  });

  test('a long cycle that is new is flagged once, then stops being flagged', () {
    final first = HistoryQuality.notesFor(
      starts: starts([28, 28, 58]),
      windowDays: 3,
    );
    expect(first.map((n) => n.kind), contains(HistoryNoteKind.recordingGap));

    // After a second 58-day cycle, the median has moved: this is her pattern
    // now, and the note goes away rather than nagging forever.
    final second = HistoryQuality.notesFor(
      starts: starts([28, 28, 58, 58]),
      windowDays: 3,
    );
    expect(
      second.map((n) => n.kind),
      isNot(contains(HistoryNoteKind.recordingGap)),
    );
  });

  test('two intervals are not enough to describe a spread', () {
    final notes = HistoryQuality.notesFor(
      starts: starts([20, 40]),
      windowDays: 12,
    );
    expect(notes.map((n) => n.kind), isNot(contains(HistoryNoteKind.spread)));
  });

  test('an empty or single-entry history says nothing at all', () {
    expect(HistoryQuality.notesFor(starts: const [], windowDays: 0), isEmpty);
    expect(
      HistoryQuality.notesFor(starts: [day(1, 1)], windowDays: 3),
      isEmpty,
    );
  });

  test('both notes can appear together, spread first', () {
    final notes = HistoryQuality.notesFor(
      starts: starts([20, 34, 21, 61]),
      windowDays: 15,
    );
    expect(notes.map((n) => n.kind), [
      HistoryNoteKind.spread,
      HistoryNoteKind.recordingGap,
    ]);
  });
}
