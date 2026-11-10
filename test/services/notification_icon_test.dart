import 'dart:io';

import 'package:elara_app/services/notification_privacy.dart';
import 'package:elara_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notification icon has to satisfy three separate rules at once, and it
/// has failed before by satisfying none of them. These assertions encode the
/// rules so a future edit cannot quietly reintroduce a blank status bar:
///
///  1. the plugin resolves the name as a *drawable*, so the resource must live
///     in a `drawable*` directory and be referenced by its bare name;
///  2. the art must be a monochrome silhouette, because Android keeps only the
///     alpha channel of a small icon and tints it;
///  3. the resource must exist in the packaged app as a vector, so it is exact
///     at every density (and is kept by the shrinker, see res/raw/keep.xml).
void main() {
  const resRoot = 'android/app/src/main/res';
  const iconName = NotificationService.notificationIconName;

  group('notification small icon', () {
    test('is a bare drawable name, not a mipmap reference', () {
      // getIdentifier('@mipmap/ic_launcher', "drawable", pkg) returns 0, which
      // is how this bug got shipped in the first place.
      expect(iconName, isNot(startsWith('@')));
      expect(iconName, isNot(contains('/')));
      expect(iconName, isNot(contains('mipmap')));
      expect(iconName, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
    });

    test('resolves to a drawable resource file', () {
      final file = File('$resRoot/drawable/$iconName.xml');
      expect(
        file.existsSync(),
        isTrue,
        reason: '${file.path} is missing; the plugin would resolve it to 0',
      );

      final xml = file.readAsStringSync();
      expect(xml, contains('<vector'));
      expect(xml, contains('android:width="24dp"'));
      expect(xml, contains('android:height="24dp"'));
    });

    test('is drawn white on transparency with no opaque background', () {
      final xml = File('$resRoot/drawable/$iconName.xml').readAsStringSync();

      // Android tints the alpha mask with the system colour, so the fill has
      // to be a plain white with a fully opaque alpha channel.
      expect(xml, contains('android:fillColor="#FFFFFFFF"'));
      expect(
        xml,
        isNot(contains('<solid')),
        reason: 'a solid background would fill the 24dp box and read as a block',
      );
      expect(
        xml.toLowerCase(),
        isNot(contains('paintcolor')),
        reason: 'a painted colour other than the mask is discarded anyway',
      );
    });

    test('the resource is kept from the resource shrinker', () {
      // The shrinker cannot see a name resolved at runtime.
      final keep = File('$resRoot/raw/keep.xml').readAsStringSync();
      expect(keep, contains('@drawable/$iconName'));
    });

    test('the launcher icon is untouched', () {
      // The fix is to the status-bar icon only; the launcher keeps its
      // presented icon (crescent, gold dot, four phase colours).
      for (final file in [
        '$resRoot/mipmap-anydpi-v26/ic_launcher.xml',
        '$resRoot/mipmap-xxxhdpi/ic_launcher.png',
        '$resRoot/mipmap-xxxhdpi/ic_launcher_monochrome.png',
      ]) {
        expect(File(file).existsSync(), isTrue, reason: '$file is missing');
      }
    });

    test('every notification payload uses the same icon name', () {
      final details = androidDetailsFor(
        channelId: 'elara_dailyBriefing',
        channelName: 'Daily briefing',
      );
      expect(details.icon, iconName);
    });
  });

  group('the verification channel', () {
    // The channel exists so that the Android verification can make the app
    // post a notification, and look at the small icon in the status bar. It
    // has to be unreachable in a release build, or the app would be able to
    // post notifications on demand with no user action behind it.
    test('the native side only reads the intent in a debug build', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/mahimmazidul/elara/MainActivity.kt',
      ).readAsStringSync();

      expect(
        kotlin,
        contains('if (!BuildConfig.DEBUG) return'),
        reason: 'the intent extra must be ignored outside a debug build',
      );
      expect(
        kotlin,
        contains('if (BuildConfig.DEBUG)'),
        reason: 'the channel must only be registered in a debug build',
      );
    });

    test('the Dart side only registers the channel in a debug build', () {
      final dart = File('lib/main.dart').readAsStringSync();
      expect(dart, contains('if (!kDebugMode) return;'));
    });

    test('the build generates BuildConfig', () {
      // AGP 8 stopped generating BuildConfig by default, so without this the
      // Kotlin above would not compile at all.
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('buildConfig = true'));
    });

    test('the check posts to a channel that exists', () {
      // Android fixes a channel's settings when it is created, and posting
      // to a channel that was never created fails quietly: the notification
      // does not appear, and there is nothing in the log to say why. That
      // is what the first attempt did - it used a channel id of its own,
      // 'elara_icon_check', which no code ever created.
      final service = File('lib/services/notification_service.dart')
          .readAsStringSync();
      expect(
        service,
        isNot(contains("'elara_icon_check'")),
        reason: 'a channel that is never created cannot receive a notification',
      );
      expect(
        service,
        contains('ElaraNotificationType.dailyBriefing.channelId'),
        reason: 'the check must use a channel that _createChannels makes',
      );
    });

    test('every channel a notification uses is one the app creates', () {
      // The ids are derived from the enum's names, and _createChannels makes
      // one per enum value. A notification that names a channel any other
      // way has to create it first.
      final service = File('lib/services/notification_service.dart')
          .readAsStringSync();
      final created = RegExp(r"'elara_\$\{?name|channelId => 'elara_")
          .allMatches(service)
          .length;
      expect(created, greaterThan(0));
      expect(
        service,
        contains('for (final type in ElaraNotificationType.values)'),
        reason: 'the channels are created for the enum, one per value',
      );
    });

    test('the activity is singleTop, so the intent reaches it', () {
      // Without singleTop a second `am start` would start a second activity
      // rather than delivering the intent to the running one, and the
      // request would never arrive.
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:launchMode="singleTop"'));
    });
  });
}
