import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Who is being spoken to.
///
/// Elara is a record one person keeps about another: the man holding the phone
/// is tracking his wife's cycle, and every screen is written that way - "what
/// she has told you", "3 from her, 2 from you", "Have the grey blanket ready".
/// "You" is the person holding the phone. "She" is the person whose body the
/// record is about.
///
/// That frame is easy to break word by word, because the ordinary phrasing for a
/// period tracker is second person throughout: "when did your period start",
/// "your forecast", "your symptoms". Each one is a sentence written for the
/// wrong app, and the user found the first of them on the add sheet: it offered
/// to log *your* period, on a phone that has never had one.
///
/// So this test is a lint on the frame, not a style preference. It fails when a
/// possessive or a verb points "you" at her body.
void main() {
  // Nouns and verbs that belong to her body and her cycle. Preceded by a
  // second-person possessive, each is a sentence addressed to the wrong person.
  const bodyNouns = [
    'period',
    'cycle',
    'symptoms',
    'bleeding',
    'flow',
    'ovulation',
    'ovulatory',
    'fertile window',
    'cramps',
    'mood',
    'body',
    'hormones',
    'last period',
    'next period',
  ];

  // Constructions where "you" is the subject of something only she does.
  const herVerbs = [
    'you are on hormonal',
    'when you are on hormonal',
    'when you bleed',
    'while you bleed',
    'you are bleeding',
    'if you are pregnant',
    'when you ovulate',
    'when you log a period',
  ];

  /// The paths that talk to the reader. `lib/data` is excluded on purpose: the
  /// health topics are quoted education addressed to whoever reads them, and
  /// rewriting a source's phrasing is a different job.
  Iterable<File> screens() => Directory('lib/screens')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('no screen offers to log, predict or describe her body as yours', () {
    final violations = <String>[];

    for (final file in screens()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Comments and doc comments talk about the code, not to the reader.
        if (trimmed.startsWith('//')) continue;

        final lower = line.toLowerCase();
        for (final verb in herVerbs) {
          if (lower.contains(verb)) {
            violations.add('${file.path}:${i + 1}: "$verb" in ${line.trim()}');
          }
        }
        for (final noun in bodyNouns) {
          if (lower.contains('your $noun') || lower.contains('you $noun')) {
            violations.add('${file.path}:${i + 1}: "your $noun" in '
                '${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These address the reader as the person whose cycle it is. The '
          'reader is the husband; the cycle is hers. Write "her period", '
          '"what she felt", "while she is on hormonal contraception".\n'
          '${violations.join('\n')}',
    );
  });

  test('the add sheet names what she felt, not what you felt', () {
    // The exact sentence the user reported. It is checked by name as well as by
    // the sweep above, so a rewrite that keeps the shape but loses the point
    // still fails.
    final source = File('lib/screens/today/log_sheet.dart').readAsStringSync();
    expect(source, contains('what she felt'));
    expect(source, isNot(contains('what you felt')));
  });

  test('the app still speaks to the reader about her', () {
    // The other half of the frame, and the half that is easy to lose while
    // fixing the first: it is still a second-person app. Today's suggestions
    // say what *you* can do.
    final source = File('lib/screens/today/today_screen.dart').readAsStringSync() +
        File('lib/screens/today/care_suggestions.dart').readAsStringSync();
    expect(source.toLowerCase(), contains('she'));
  });
}
