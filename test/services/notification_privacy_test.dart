import 'package:elara_app/services/notification_privacy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The privacy rule for reminder text, tested as the pure function it is.
///
/// These assertions are the ones that matter if this app is ever reviewed for
/// how it treats health data: what, exactly, appears on a locked screen.
void main() {
  group('redaction', () {
    const specific = (
      title: 'Luteal \u00b7 day 23',
      body: 'A quiet evening might land well. Warm food could be a kind idea.',
    );

    test('withholds everything by default', () {
      const privacy = NotificationPrivacy(previewDetails: false);
      final shown = privacy.apply(title: specific.title, body: specific.body);

      expect(shown.title, 'Elara');
      expect(shown.body, contains('Open Elara'));
      // Cycle vocabulary, not the word "day": "today" is not a disclosure.
      for (final term in [
        'luteal',
        'follicular',
        'ovulat',
        'fertile',
        'period',
        'cycle',
        'menstrual',
        'pms',
        'symptom',
        'phase',
      ]) {
        expect(
          shown.body.toLowerCase(),
          isNot(contains(term)),
          reason: 'redacted body leaked "$term"',
        );
      }
    });

    test('shows the full text only when asked', () {
      const privacy = NotificationPrivacy(previewDetails: true);
      final shown = privacy.apply(title: specific.title, body: specific.body);
      expect(shown.title, specific.title);
      expect(shown.body, specific.body);
    });

    test('redacts the most sensitive titles specifically', () {
      const privacy = NotificationPrivacy(previewDetails: false);
      for (final title in [
        'Period expected today',
        'Ovulatory phase begins',
        'The late luteal phase is starting',
        'Heat index above 40\u00b0C',
      ]) {
        final shown = privacy.apply(title: title, body: title);
        expect(shown.title, 'Elara', reason: 'leaked: $title');
        expect(shown.body, isNot(contains('period')));
        expect(shown.body, isNot(contains('luteal')));
      }
    });
  });

  group('android payload', () {
    test('is private on the lock screen', () {
      final details = androidDetailsFor(
        channelId: 'elara_dailyBriefing',
        channelName: 'Daily briefing',
      );
      expect(details.visibility, NotificationVisibility.private);
      expect(details.channelId, 'elara_dailyBriefing');
      expect(details.importance, Importance.defaultImportance);
    });

    test('every channel id gets its own private payload', () {
      final a = androidDetailsFor(channelId: 'a', channelName: 'A');
      final b = androidDetailsFor(channelId: 'b', channelName: 'B');
      expect(a.visibility, NotificationVisibility.private);
      expect(b.visibility, NotificationVisibility.private);
      expect(a.channelId, isNot(b.channelId));
    });
  });
}
