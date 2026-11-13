import 'package:elara_app/data/partner_phases.dart';
import 'package:flutter_test/flutter_test.dart';

/// The guide is content, so the tests are about the content: that all four
/// phases are present, that each one has something to do and something to skip,
/// that the food is local rather than imported, and that no line has drifted into
/// a medical claim.
///
/// The claims test in `claims_test.dart` already scans `lib/` for the banned
/// phrases. This file covers what that sweep cannot see: a phase with an empty
/// Do, or a food list that quietly turned back into cacao nibs.
void main() {
  test('there are four phases, one per phase key', () {
    expect(partnerPhases.length, 4);
    expect(
      partnerPhases.map((p) => p.phaseKey).toList(),
      ['menstrual', 'follicular', 'ovulatory', 'luteal'],
    );
  });

  test('every phase has something to do and something to skip', () {
    for (final phase in partnerPhases) {
      expect(phase.doThis, isNotEmpty, reason: phase.name);
      expect(phase.skip, isNotEmpty, reason: phase.name);
      // Two is the floor the slides set: one action is a tip, two is a plan.
      expect(phase.foods.length, greaterThanOrEqualTo(2), reason: phase.name);
      expect(phase.whatHappens.length, greaterThan(80), reason: phase.name);
      expect(phase.aka, isNotEmpty, reason: phase.name);
    }
  });

  test('the food is the local version, not the imported one', () {
    final names = partnerPhases
        .expand((p) => p.foods)
        .map((f) => f.name.toLowerCase())
        .toList();

    // The Bangladeshi pantry the guide is built on.
    for (final local in ['chhola', 'palong shak', 'doi', 'ilish', 'shak']) {
      expect(
        names.any((n) => n.contains(local)),
        isTrue,
        reason: 'no entry mentions $local',
      );
    }

    // The originals named these; they are not what a household here buys.
    for (final imported in ['cacao', 'greek yoghurt', 'kimchi', 'matcha', 'bilton']) {
      expect(
        names.any((n) => n.contains(imported)),
        isFalse,
        reason: '$imported is still in the list',
      );
    }
  });

  test('nothing claims to measure, confirm or guarantee', () {
    final text = partnerPhases
        .expand(
          (p) => [
            p.whatHappens,
            p.aka,
            ...p.doThis,
            ...p.skip,
            ...p.foods.map((f) => '${f.name} ${f.why}'),
          ],
        )
        .join(' ')
        .toLowerCase();

    for (final banned in [
      'guarantee',
      'safe day',
      'diagnose',
      'confirmed ovulation',
      'will cure',
      'treats ',
    ]) {
      expect(text.contains(banned), isFalse, reason: 'guide says "$banned"');
    }
  });

  test('the guide rejects using hormones to dismiss what she says', () {
    final menstrual = partnerPhases.first;
    expect(
      menstrual.skip.any((line) => line.toLowerCase().contains('hormones')),
      isTrue,
    );
    expect(
      menstrual.skip.any(
        (line) => line.toLowerCase().contains('are you on your period'),
      ),
      isTrue,
    );
  });

  test('timing labels do not turn a 28-day cycle into a schedule', () {
    for (final phase in partnerPhases) {
      expect(phase.timing.toLowerCase(), isNot(contains('days')));
      expect(phase.timing, isNotEmpty);
    }
  });
}
