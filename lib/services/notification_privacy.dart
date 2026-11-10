import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// Decides what a reminder is allowed to say on screen.
///
/// Kept separate from [NotificationService] because it is pure policy: given a
/// title, a body and one preference it returns the text to post. That makes the
/// privacy rule testable without an Android plugin, which matters because the
/// rule is the sort of thing that is only ever noticed when it has already
/// failed.
class NotificationPrivacy {
  const NotificationPrivacy({required this.previewDetails});

  /// True only when the user has asked for specific reminder text.
  final bool previewDetails;

  /// Title used when the content is being withheld. The app name alone, matched
  /// against every other Elara notification, so the shade reveals nothing that
  /// the launcher icon does not.
  static const String redactedTitle = 'Elara';

  /// Body used when the content is being withheld.
  ///
  /// It has to be useful without being informative: the point of the reminder
  /// is still to bring someone back to the app, so it invites an unlock rather
  /// than summarising the day.
  static const String redactedBody = 'Open Elara for today\u2019s note.';

  /// Applies the rule. Returns the title and body to actually post.
  ({String title, String body}) apply({
    required String title,
    required String body,
  }) {
    if (previewDetails) return (title: title, body: body);
    return (title: redactedTitle, body: redactedBody);
  }
}

/// Builds the Android payload for one reminder.
///
/// Extracted so a test can assert the lock-screen visibility flag and the
/// importance without scheduling anything: `zonedSchedule` needs a live plugin,
/// but this is plain data.
AndroidNotificationDetails androidDetailsFor({
  required String channelId,
  required String channelName,
}) {
  return AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Elara reminders: ${channelName.toLowerCase()}',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    // A monochrome drawable, not a mipmap launcher icon: see
    // NotificationService.notificationIconName for why the old value could
    // never render. Kept as a bare name so the plugin's
    // getIdentifier(name, "drawable", package) resolution succeeds.
    icon: NotificationService.notificationIconName,
    // Health information. Android treats "private" as: show the notification,
    // hide the content unless the device's own lock-screen setting says
    // otherwise, and never show it in full on the lock screen.
    visibility: NotificationVisibility.private,
  );
}
