import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_info.dart';
import 'data/database_helper.dart';
import 'providers/climate_provider.dart';
import 'providers/cycle_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/root_scaffold.dart';
import 'services/notification_service.dart';
import 'utils/phase_timeline.dart';
import 'theme/elara_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElaraApp());
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
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
        ),
        ChangeNotifierProvider<CycleProvider>(
          create: (_) => CycleProvider()..load(),
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

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ElaraTheme.light(phaseKey: phaseKey),
      darkTheme: ElaraTheme.dark(phaseKey: phaseKey),
      home: const RootScaffold(),
    );
  }
}
