import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The claims this app is not allowed to make, enforced rather than promised.
///
/// Elara estimates a next period and draws a fertile window from calendar
/// arithmetic. It cannot confirm ovulation, it cannot tell anyone they are safe,
/// and it is not a contraceptive. None of that is a hard thing to state once; it
/// is a hard thing to keep true across a hundred strings written over two years
/// by someone tired at midnight.
///
/// So the rule lives here. A string added later that says "safe day", or that
/// turns an estimate into a confirmation, fails the build with the file and
/// line, and the failure names the claim rather than the phrase.
///
/// This is deliberately a small, blunt list. It is a net for the sentences that
/// would do harm, not a style guide: false positives would teach the next
/// contributor to delete the test.
void main() {
  /// Phrases that turn an estimate into a promise.
  ///
  /// Each entry is (pattern, why it is forbidden). Matching is
  /// case-insensitive and on the raw source, so a string split across lines is
  /// still caught when the phrase itself is on one line — which is how these
  /// get written.
  const forbidden = <(String, String)>[
    (
      'safe day',
      'there is no safe day in a calendar estimate; only a lower chance',
    ),
    (
      'safe period',
      'a period is not a contraceptive state',
    ),
    (
      'cannot get pregnant',
      'the app cannot make a fertility claim of any kind',
    ),
    (
      "can't get pregnant",
      'the app cannot make a fertility claim of any kind',
    ),
    (
      'will not get pregnant',
      'the app cannot make a fertility claim of any kind',
    ),
    (
      'ovulation confirmed',
      'ovulation is not observed, only modelled from a past date',
    ),
    (
      'confirmed ovulation',
      'ovulation is not observed, only modelled from a past date',
    ),
    (
      'you are ovulating',
      'the app can place a day in a modelled window, not confirm ovulation',
    ),
    (
      'guarantee',
      'the engine reports a heuristic score and a window, never a guarantee',
    ),
    (
      'diagnose',
      'Elara is not a medical device and does not diagnose anything',
    ),
    (
      'treatment for',
      'the app offers general information, never treatment',
    ),
  ];

  /// Files that may legitimately discuss these words, and why.
  const exempt = <String, String>{
    // The claims matrix and the disclaimer have to be able to name the thing
    // they are refusing to do.
    'lib/data/medical_content.dart':
        'health information, written with clinical sources and reviewed copy; '
            'it describes conditions and when to see a doctor',
  };

  /// Words that turn a forbidden phrase into a refusal to make it.
  const denials = <String>[
    'does not ',
    'do not ',
    'is not ',
    'are not ',
    'never ',
    'not a ',
    'no ',
    'without ',
  ];

  test('no user-facing string promises what the engine cannot deliver', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (exempt.containsKey(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments explain the rule to the next reader; they are not shipped
        // to a user's screen.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;

        final lower = line.toLowerCase();
        for (final (phrase, reason) in forbidden) {
          final at = lower.indexOf(phrase);
          if (at == -1) continue;
          // A denial is not a claim. "Elara does not diagnose anything" is the
          // sentence this test exists to protect, so the words immediately
          // before the match decide whether it is one.
          final before = lower.substring(at > 24 ? at - 24 : 0, at);
          final denied = denials.any(before.contains);
          if (denied) continue;
          violations.add(
            '${entity.path}:${i + 1}: "$phrase" — $reason\n'
            '    ${line.trim()}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These strings make a claim Elara cannot support:\n'
          '${violations.join('\n')}',
    );
  });

  test('the Today screen still carries the standing disclaimer', () {
    // The sentence that keeps the whole screen honest, checked because it is
    // the kind of line that gets shortened away during a layout tidy-up.
    final source = File('lib/screens/today/today_screen.dart').readAsStringSync();
    expect(source, contains('estimates from recorded history, not a'));
    expect(source, contains('medical measurement'));
  });

  test('the quiet screen never claims a phase it has switched off', () {
    // In a mode that is not predicting, the guidance must say where it comes
    // from. Without this sentence the screen implies a cycle state that the app
    // has just said it cannot see.
    final source = File('lib/screens/today/quiet_today.dart').readAsStringSync();
    expect(source, contains('not from a predicted phase'));
  });

  test('the consent gate still states the three things it promises', () {
    // Not a substitute for reading the screen: a proxy for the three props a
    // copy pass can quietly remove — where the data lives, that it is hers, and
    // that it can be withdrawn.
    final source =
        File('lib/screens/consent/consent_screen.dart').readAsStringSync();
    expect(source, contains('no account and no server'));
    expect(source, contains('shared decision'));
    expect(source, contains('withdraw this at any time'));
  });
}
