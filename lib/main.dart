import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_info.dart';
import 'data/database_helper.dart';
import 'providers/climate_provider.dart';
import 'providers/consent_provider.dart';
import 'providers/cycle_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/reminders_provider.dart';
import 'providers/symptoms_provider.dart';
import 'providers/update_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/consent/consent_gate.dart';
import 'services/backup_service.dart';
import 'services/care_recommender.dart';
import 'services/notification_service.dart';
import 'utils/phase_timeline.dart';
import 'theme/elara_theme.dart';
import 'theme/system_overlay_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerVerificationChannel();
  runApp(const ElaraApp());
}

/// The channel the Android verification uses to make the app post a
/// notification.
///
/// The notification's small icon is drawn by the system, from the alpha
/// channel of a drawable, in the status bar. Nothing inside the app shows
/// it, so the only way to know that it draws is to post a notification and
/// look at the status bar.
///
/// It has to be posted **by the app**. The system's own `cmd notification
/// post` command resolves a drawable from its own package, not another
/// app's, so it cannot carry Elara's icon - and a notification carrying the
/// system's default icon would look plausible and prove nothing.
///
/// The handler exists only in a debug build. A release build has no channel
/// to call, so there is no way to make the app post a notification on
/// demand, and nothing here can be reached by anything but a test.
void _registerVerificationChannel() {
  if (!kDebugMode) return;

  const channel = MethodChannel('elara/verification');
  channel.setMethodCallHandler((call) async {
    // The native side sends one method and the action as its argument.
    if (call.method != verificationMethod) {
      throw MissingPluginException('Unknown method ${call.method}');
    }
    final action = call.arguments as String? ?? '';
    debugPrint('Elara: the verification action "$action" was asked for');
    try {
      await handleVerificationCall(action);
      debugPrint('Elara: the verification action "$action" was carried out');
    } catch (error, stack) {
      // An exception here would be swallowed by the platform channel and the
      // verification would time out with nothing to show for it. Printing it
      // puts it in logcat, where the verification can read it.
      debugPrint('Elara: the verification action "$action" failed: $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
    return true;
  });
}

/// The method the native side calls when an intent asks for a verification
/// action.
///
/// The native side cannot post the notification itself - only the app can,
/// because only the app's own package holds the icon drawable - so the
/// request has to cross into Dart.
const String verificationMethod = 'handleVerification';

Future<void> handleVerificationCall(String action) async {
  if (action == 'showTestNotification') {
    // A separate instance from the one in the provider graph. The plugin
    // registers its channels on the native side once per process, so
    // initialising it again is harmless, but there is no reason to do it:
    // the app's own service is already initialised by the time a request
    // can arrive.
    await NotificationService().showNow();
  }
}

/// Root of the app: owns the provider graph and the [MaterialApp].
///
/// Dependency order matters. [DatabaseHelper] is exposed first so every provider
/// below shares one connection, and [PredictionProvider] is last because it
/// refreshes when the cycle list or the settings change.
class ElaraApp extends StatelessWidget {
  const ElaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseHelper>.value(value: DatabaseHelper.instance),
        // One scheduler for the process. Created here rather than per screen so
        // the schedule is rebuilt once, not once per widget that needs it.
        Provider<NotificationService>(create: (_) => NotificationService()),
        // The same instance behind the one-method interface the UI uses, so a
        // widget test can rebuild the schedule without an Android plugin.
        Provider<NotificationRescheduler>(
          create: (context) => context.read<NotificationService>(),
        ),
        Provider<BackupService>(create: (_) => BackupService()),
        Provider<CareRecommender>(create: (_) => const CareRecommender()),
        // Consent loads first: the gate below decides whether the rest of the
        // app is allowed to render at all.
        ChangeNotifierProvider<ConsentProvider>(
          create: (_) => ConsentProvider()..load(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
        ),
        ChangeNotifierProvider<CycleProvider>(
          create: (_) => CycleProvider()..load(),
        ),
        ChangeNotifierProvider<PreferencesProvider>(
          create: (_) => PreferencesProvider()..load(),
        ),
        ChangeNotifierProvider<SymptomsProvider>(
          create: (_) => SymptomsProvider()..load(),
        ),
        ChangeNotifierProvider<RemindersProvider>(
          create: (_) => RemindersProvider()..load(),
        ),
        ChangeNotifierProvider<UpdateProvider>(
          create: (_) => UpdateProvider(),
        ),
        ChangeNotifierProvider<ClimateProvider>(
          create: (_) => ClimateProvider()..load(),
        ),
        // Depends on both, so proxy it: when either is written the prediction is
        // recomputed (deferred to after the frame; see syncDependencies).
        ChangeNotifierProxyProvider2<CycleProvider, SettingsProvider,
            PredictionProvider>(
          create: (_) => PredictionProvider(),
          update: (_, cycles, settings, prediction) {
            prediction!.syncDependencies(
              cycleRevision: cycles.revision,
              settingsRevision: settings.revision,
            );
            return prediction;
          },
        ),
      ],
      child: const _ElaraRoot(),
    );
  }
}

/// Owns the [MaterialApp] and keeps the reminder schedule current.
///
/// Reminders are rebuilt whenever the app comes to the foreground: the phase, the
/// predicted date and the user's switches can all have changed while it was in
/// the background. Boot-time restoration is handled on the native side by the
/// plugin's boot receiver plus the AlarmManager periodic callback, so nothing
/// here needs to run before the first frame.
class _ElaraRoot extends StatefulWidget {
  const _ElaraRoot();

  @override
  State<_ElaraRoot> createState() => _ElaraRootState();
}

class _ElaraRootState extends State<_ElaraRoot> with WidgetsBindingObserver {
  late final NotificationService _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifications = context.read<NotificationService>();
    // Deferred so the first frame is not blocked by plugin channels.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSchedule());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSchedule();
    }
  }

  Future<void> _refreshSchedule() async {
    try {
      await _notifications.requestPermission();
      await _notifications.rescheduleAll();
    } catch (error) {
      // A scheduling problem must never take the app down.
      debugPrint('Elara: reminder refresh failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the theme setting actually changes.
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (settings) => settings.themeMode,
    );

    // The accent follows the current phase. This is read from the prediction,
    // which is recomputed whenever cycle data or settings change, so logging a
    // period moves the theme in the same frame the rest of the UI updates —
    // no restart, nothing to refresh by hand. With no phase available the
    // neutral accent is used.
    final phaseKey = context.select<PredictionProvider, String?>(
      (prediction) => phaseKeyOfResult(prediction.result),
    );

    final lightTheme = ElaraTheme.light(phaseKey: phaseKey);
    final darkTheme = ElaraTheme.dark(phaseKey: phaseKey);

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      // The system bars are drawn behind the app's page background, so their
      // style has to follow the theme that is actually in use. Inside
      // `builder` the `Theme` is the resolved one — `ThemeMode.system` has
      // already been resolved against the platform brightness — so
      // `Theme.of(context).brightness` is the brightness of the page behind
      // the bars, which is exactly what the overlay style needs.
      builder: (context, child) => ElaraSystemUiRegion(
        brightness: Theme.of(context).brightness,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ConsentGate(),
    );
  }
}
