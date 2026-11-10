import 'package:elara_app/data/medical_content.dart';
import 'package:elara_app/screens/medical/medical_screen.dart';
import 'package:elara_app/screens/medical/medical_topic_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The health-information section: content rules first, then rendering.
///
/// The content tests are the important ones. A medical section can render
/// perfectly and still be wrong, so the assertions below cover what must be
/// true of the text itself: sources for every topic, a red-flag list, no
/// diagnosis, and no suggestion that anything here is personalized.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('content', () {
    test('every topic carries sources with live-looking https URLs', () {
      for (final topic in medicalTopics) {
        expect(topic.sources, isNotEmpty, reason: topic.id);
        for (final source in topic.sources) {
          expect(source.label, isNotEmpty, reason: topic.id);
          expect(
            source.url,
            startsWith('https://'),
            reason: '${topic.id} has a non-https source',
          );
          // Not fabricated-looking: a bare domain with no path is rejected.
          expect(
            source.url.substring('https://'.length),
            contains('/'),
            reason: '${topic.id} source has no path',
          );
        }
      }
    });

    test('every topic says when to seek help', () {
      for (final topic in medicalTopics) {
        expect(topic.whenToSeekHelp, isNotEmpty, reason: topic.id);
        expect(topic.whenToSeekHelp.length, greaterThanOrEqualTo(3),
            reason: topic.id);
      }
    });

    test('every topic has body text and a summary', () {
      for (final topic in medicalTopics) {
        expect(topic.summary.length, greaterThan(40), reason: topic.id);
        expect(topic.sections, isNotEmpty, reason: topic.id);
        for (final section in topic.sections) {
          expect(
            section.paragraphs.isNotEmpty || section.bullets.isNotEmpty,
            isTrue,
            reason: '${topic.id} has an empty section',
          );
        }
      }
    });

    test('ids are unique', () {
      final ids = medicalTopics.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the text never diagnoses the reader', () {
      final forbidden = <RegExp>[
        // An affirmative diagnosis, not a sentence that refuses to give one.
        RegExp(r'\byou have (pcos|pmdd|pms|endometriosis|dysmenorrhoea)\b',
            caseSensitive: false),
        RegExp(r'\byou are suffering\b', caseSensitive: false),
        RegExp(r'\bthis means you\b', caseSensitive: false),
        RegExp(r'\byour (cycle|phase) (shows|indicates|proves)\b',
            caseSensitive: false),
      ];

      for (final topic in medicalTopics) {
        final text = [
          topic.title,
          topic.summary,
          topic.urgentNote ?? '',
          ...topic.whenToSeekHelp,
          for (final section in topic.sections) ...[
            section.heading,
            ...section.paragraphs,
            ...section.bullets,
          ],
        ].join(' ');

        for (final pattern in forbidden) {
          expect(
            pattern.hasMatch(text),
            isFalse,
            reason: '${topic.id} matches ${pattern.pattern}',
          );
        }
      }
    });

    test('the disclaimer says it is general and not a diagnosis', () {
      expect(medicalDisclaimer, contains('not medical advice'));
      expect(medicalDisclaimer, contains('does not'));
      expect(medicalSourcesChecked, isNotEmpty);
    });

    test('the topics the brief names are all present', () {
      final titles = medicalTopics.map((t) => t.title.toLowerCase()).join(' ');
      expect(titles, contains('pms'));
      expect(titles, contains('pmdd'));
      expect(titles, contains('pcos'));
      expect(titles, contains('period pain'));
      expect(titles, contains('irregular'));
      expect(titles, contains('heavy'));
      expect(titles, contains('pain relief'));
    });

    test('pain-relief guidance carries precautions, not a prescription', () {
      final topic = medicalTopics.firstWhere((t) => t.id == 'pain-relief');
      final text = [
        ...topic.sections.expand((s) => [...s.paragraphs, ...s.bullets]),
      ].join(' ').toLowerCase();

      expect(text, contains('pharmacist'));
      expect(text, contains('label'));
      expect(text, contains('pregnan'));
      // It must not tell anyone a dose.
      expect(
        RegExp(r'\d+\s*(mg|milligram|tablet)', caseSensitive: false)
            .hasMatch(text),
        isFalse,
      );
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget screen, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: ElaraTheme.light(), home: screen),
      );
      await tester.pump();
    }

    testWidgets('the index lists every topic and leads with the caveat',
        (tester) async {
      await pump(tester, const MedicalScreen(), const Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(find.text(medicalDisclaimer), findsOneWidget);
      expect(find.text('Period pain (dysmenorrhoea)'), findsOneWidget);
      // It must separate itself from personalized care in words.
      expect(find.textContaining('the same for everyone'), findsOneWidget);
    });

    testWidgets('a topic page shows the red-flag list and its sources',
        (tester) async {
      final topic = medicalTopics.firstWhere((t) => t.id == 'heavy-bleeding');
      await pump(tester, MedicalTopicScreen(topic: topic), const Size(390, 844));

      expect(find.text(medicalDisclaimer), findsOneWidget);

      // The red-flag list sits below the body, so scroll to it rather than
      // assuming the whole page is built at once.
      await tester.scrollUntilVisible(find.text('WHEN TO SEE A CLINICIAN'), 240);
      expect(find.text('WHEN TO SEE A CLINICIAN'), findsOneWidget);
      expect(find.text(topic.whenToSeekHelp.first), findsOneWidget);

      await tester.scrollUntilVisible(find.text('SOURCES'), 240);
      expect(find.text('SOURCES'), findsOneWidget);
      expect(find.text(topic.sources.first.label), findsOneWidget);
    });

    testWidgets('a topic with an urgent note shows it above the body',
        (tester) async {
      final topic = medicalTopics.firstWhere((t) => t.id == 'pmdd');
      await pump(tester, MedicalTopicScreen(topic: topic), const Size(390, 844));

      expect(find.text(topic.urgentNote!), findsOneWidget);
    });

    for (final width in <double>[320, 360, 390, 430]) {
      for (final scale in <double>[1.0, 1.5, 2.0]) {
        testWidgets('reads at ${width.toInt()}dp and ${scale}x text',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: ElaraTheme.light(),
                home: MedicalTopicScreen(topic: medicalTopics.first),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: ElaraTheme.light(),
                home: const MedicalScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
