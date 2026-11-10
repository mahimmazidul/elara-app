import 'package:elara_app/data/generic_guidance.dart';
import 'package:elara_app/services/care_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

/// The general layer of Today's advice.
///
/// Two things have to be true of it and are checked here. It must never outrank
/// something she actually said, and it must never make a claim about her — it
/// is written about a phase, for everybody, and the app has no basis for
/// anything more specific when it has nothing recorded.
void main() {
  const recommender = CareRecommender();

  group('the table', () {
    test('every phase has its own guidance', () {
      for (final phase in const [
        'menstrual',
        'follicular',
        'ovulatory',
        'luteal',
      ]) {
        expect(
          GenericGuidanceTable.byPhase[phase],
          isNotEmpty,
          reason: '$phase has no general guidance',
        );
      }
    });

    test('every item names a source and a citation', () {
      final all = [
        ...GenericGuidanceTable.anyPhase,
        for (final list in GenericGuidanceTable.byPhase.values) ...list,
      ];
      for (final item in all) {
        expect(item.source, isNotEmpty, reason: item.title);
        expect(item.citation, isNotEmpty, reason: item.title);
        expect(item.body, isNotEmpty, reason: item.title);
      }
    });

    test('an unknown phase still gets the general set', () {
      final items = GenericGuidanceTable.forPhase('unknown');
      expect(items, isNotEmpty);
      expect(items.length, GenericGuidanceTable.anyPhase.length);
    });

    test('the phase items come before the ones that hold in any phase', () {
      final luteal = GenericGuidanceTable.forPhase('luteal');
      expect(luteal.first, GenericGuidanceTable.byPhase['luteal']!.first);
      expect(luteal.last, GenericGuidanceTable.anyPhase.last);
    });
  });

  group('as suggestions', () {
    test('they carry the source line and the general basis', () {
      final suggestions = recommender.generalFor('menstrual');
      expect(suggestions, isNotEmpty);
      for (final suggestion in suggestions) {
        expect(suggestion.basis, CareBasis.general);
        expect(suggestion.source, isNotNull);
        expect(suggestion.source, isNotEmpty);
      }

      // The publisher is named once, not twice: citations that already begin
      // with it are not prefixed with it again.
      for (final suggestion in recommender.generalFor('ovulatory')) {
        expect(
          suggestion.source!.startsWith('NICE · NICE'),
          isFalse,
          reason: suggestion.source,
        );
      }
    });

    test('they are limited to what the screen can carry', () {
      expect(recommender.generalFor('luteal').length, lessThanOrEqualTo(2));
    });

    test('none of them writes a claim about her', () {
      // The forbidden phrasings the claims lint checks, plus the two that
      // matter specifically here: a promise about mood, and a promise about
      // fertility from a calendar estimate.
      const forbidden = [
        'you will feel',
        'she will feel',
        'safe day',
        'safe period',
        'cannot get pregnant',
        'guarantee',
        'diagnose',
        'treatment for',
        'ovulation confirmed',
      ];
      final all = [
        ...GenericGuidanceTable.anyPhase,
        for (final list in GenericGuidanceTable.byPhase.values) ...list,
      ];
      for (final item in all) {
        final text = '${item.title} ${item.body}'.toLowerCase();
        for (final phrase in forbidden) {
          expect(
            text,
            isNot(contains(phrase)),
            reason: '"${item.title}" contains "$phrase"',
          );
        }
      }
    });
  });
}
