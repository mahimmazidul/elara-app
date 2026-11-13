import 'dart:io';

import 'package:elara_app/widgets/icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every icon the app draws comes from one vocabulary.
///
/// An icon vocabulary that only covers *some* of the icons in use is worse
/// than none, because the ones left out drift: "add" becomes `Icons.add` in
/// one place and `Icons.add_rounded` in another, and the two are visibly
/// different weights at 16 px. This test fails if a screen reaches for a raw
/// `Icons.` constant instead of a named one.
///
/// The navigation bar is the one exception, and it is a deliberate one: a
/// navigation bar needs a filled icon for the selected tab and an outlined
/// one for the rest, which is a decision about that widget rather than about
/// what the icons mean.
void main() {
  /// The screens that are allowed to name raw Material icons, and why.
  const allowed = <String, String>{
    'lib/screens/root_scaffold.dart':
        'the navigation bar needs a filled icon for the selected tab',
  };

  test('every icon in the app comes from the vocabulary', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final path = entity.path;
      if (path == 'lib/widgets/icons.dart') continue;
      if (allowed.containsKey(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `Icons.` on its own, not `ElaraIcons.` and not `MaterialIcons.`.
        final match = RegExp(r'(?<![A-Za-z_.])Icons\.').firstMatch(line);
        if (match == null) continue;
        violations.add(
          '$path:${i + 1}: ${line.trim()}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These reach for a raw Material icon. Name it in ElaraIcons '
          'instead, so the same meaning is always drawn the same way.\n'
          '${violations.join('\n')}',
    );
  });

  test('the vocabulary is complete: nothing is declared twice', () {
    // Two names for the same glyph would let the drift back in through the
    // back door, so each Material icon may back only one name — with one
    // deliberate exception, listed here and explained.
    //
    // `next` and `disclosure` are the same chevron on purpose: "next month"
    // and "open this row" are different actions, but they are both "there is
    // more this way", and a row of chevrons pointing in two directions reads
    // as an inconsistency rather than as two meanings.
    const deliberate = <String, Set<String>>{
      'Icons.chevron_right_rounded': {'next', 'disclosure'},
    };

    final byGlyph = <String, List<String>>{};
    for (final entry in _vocabulary()) {
      byGlyph.putIfAbsent(entry.glyph, () => <String>[]).add(entry.key);
    }

    final duplicates = <String>[];
    for (final entry in byGlyph.entries) {
      if (entry.value.length <= 1) continue;
      if (deliberate[entry.key]?.containsAll(entry.value) ?? false) continue;
      duplicates.add('${entry.value.join(', ')} -> ${entry.key}');
    }

    expect(
      duplicates,
      isEmpty,
      reason: 'One glyph, one meaning. The only sanctioned duplicate is '
          'next/disclosure, and it has to be listed above.',
    );
  });

  test('the vocabulary names every glyph it declares', () {
    // A name that resolves to a null icon would draw nothing at all.
    for (final entry in _vocabularyNames().entries) {
      expect(
        entry.value,
        isNotNull,
        reason: 'ElaraIcons.${entry.key} does not resolve to an icon',
      );
    }
  });

  group('the icons the app relies on', () {
    test('the disclosure and next chevrons are the same shape', () {
      // "Next month" and "open this row" are different actions, but they are
      // both "there is more this way", and a row of chevrons pointing in two
      // different directions reads as an inconsistency.
      expect(ElaraIcons.next, ElaraIcons.disclosure);
    });

    test('the add glyph is the rounded one everywhere', () {
      expect(ElaraIcons.plus, Icons.add_rounded);
    });

    test('the weather glyph is the outlined one', () {
      // The filled thermometer reads as a live reading; the outlined one
      // reads as a category. The climate strip shows an estimated value, so
      // it must not look like a measurement.
      expect(ElaraIcons.weather, Icons.thermostat_outlined);
    });

    test('the sizes are ordered: button, default, row', () {
      expect(ElaraIcons.buttonSize, lessThan(ElaraIcons.size));
      expect(ElaraIcons.size, lessThan(ElaraIcons.rowSize));
    });
  });
}

/// The vocabulary's names and the icons behind them.
///
/// Read from the source rather than hard-coded here, so the test cannot
/// disagree with the file it is checking.
Map<String, IconData> _vocabularyNames() => {
      for (final entry in _vocabulary()) entry.key: entry.icon,
    };

/// One entry of the vocabulary: the name, the Material glyph it stands for,
/// and the resolved icon.
class _VocabularyEntry {
  const _VocabularyEntry(this.key, this.glyph, this.icon);

  final String key;
  final String glyph;
  final IconData icon;
}

/// The vocabulary as the source declares it.
List<_VocabularyEntry> _vocabulary() {
  final source = File('lib/widgets/icons.dart').readAsStringSync();
  final entries = <_VocabularyEntry>[];

  final pattern = RegExp(
    r'static const IconData (\w+) = (Icons\.[A-Za-z0-9_]+);',
  );
  for (final match in pattern.allMatches(source)) {
    final name = match.group(1)!;
    final glyph = match.group(2)!;
    entries.add(_VocabularyEntry(name, glyph, _resolve(glyph)));
  }
  return entries;
}

/// Resolves a Material icon constant by name.
///
/// The icon set is not exported as a lookup table, so the name is resolved
/// against the known Material icon constants. Only the icons the vocabulary
/// actually uses need to be here; anything else fails loudly rather than
/// silently resolving to the wrong glyph.
IconData _resolve(String name) {
  const known = <String, IconData>{
    'Icons.favorite_border_rounded': Icons.favorite_border_rounded,
    'Icons.chat_bubble_outline_rounded': Icons.chat_bubble_outline_rounded,
    'Icons.restaurant_outlined': Icons.restaurant_outlined,
    'Icons.check_circle_outline_rounded': Icons.check_circle_outline_rounded,
    'Icons.visibility_outlined': Icons.visibility_outlined,
    'Icons.edit_note_outlined': Icons.edit_note_outlined,
    'Icons.visibility_off_outlined': Icons.visibility_off_outlined,
    'Icons.event_outlined': Icons.event_outlined,
    'Icons.calendar_today_outlined': Icons.calendar_today_outlined,
    'Icons.edit_calendar_outlined': Icons.edit_calendar_outlined,
    'Icons.event_available_outlined': Icons.event_available_outlined,
    'Icons.chevron_left_rounded': Icons.chevron_left_rounded,
    'Icons.chevron_right_rounded': Icons.chevron_right_rounded,
    'Icons.healing_outlined': Icons.healing_outlined,
    'Icons.sick_outlined': Icons.sick_outlined,
    'Icons.psychology_outlined': Icons.psychology_outlined,
    'Icons.battery_2_bar_rounded': Icons.battery_2_bar_rounded,
    'Icons.waves_rounded': Icons.waves_rounded,
    'Icons.spa_outlined': Icons.spa_outlined,
    'Icons.water_drop_outlined': Icons.water_drop_outlined,
    'Icons.circle_outlined': Icons.circle_outlined,
    'Icons.timeline_outlined': Icons.timeline_outlined,
    'Icons.straighten': Icons.straighten,
    'Icons.show_chart': Icons.show_chart,
    'Icons.thermostat_outlined': Icons.thermostat_outlined,
    'Icons.thermostat': Icons.thermostat,
    'Icons.cloud_outlined': Icons.cloud_outlined,
    'Icons.menu_book_outlined': Icons.menu_book_outlined,
    'Icons.info_outline_rounded': Icons.info_outline_rounded,
    'Icons.facebook_rounded': Icons.facebook_rounded,
    'Icons.send_rounded': Icons.send_rounded,
    'Icons.priority_high_rounded': Icons.priority_high_rounded,
    'Icons.insights_outlined': Icons.insights_outlined,
    'Icons.lock_outline_rounded': Icons.lock_outline_rounded,
    'Icons.people_outline_rounded': Icons.people_outline_rounded,
    'Icons.undo_rounded': Icons.undo_rounded,
    'Icons.copy_rounded': Icons.copy_rounded,
    'Icons.delete_outline_rounded': Icons.delete_outline_rounded,
    'Icons.notifications_none_rounded': Icons.notifications_none_rounded,
    'Icons.brightness_auto_outlined': Icons.brightness_auto_outlined,
    'Icons.light_mode_outlined': Icons.light_mode_outlined,
    'Icons.dark_mode_outlined': Icons.dark_mode_outlined,
    'Icons.code_outlined': Icons.code_outlined,
    'Icons.code_rounded': Icons.code_rounded,
    'Icons.system_update_alt_rounded': Icons.system_update_alt_rounded,
    'Icons.nightlight_outlined': Icons.nightlight_outlined,
    'Icons.add_rounded': Icons.add_rounded,
    'Icons.more_horiz_rounded': Icons.more_horiz_rounded,
    'Icons.radio_button_unchecked': Icons.radio_button_unchecked,
    'Icons.radio_button_checked_rounded': Icons.radio_button_checked_rounded,
    'Icons.radio_button_unchecked_rounded': Icons.radio_button_unchecked_rounded,
  };
  final icon = known[name];
  if (icon == null) {
    throw StateError('Unknown icon: $name');
  }
  return icon;
}
