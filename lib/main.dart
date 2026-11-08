import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_info.dart';
import 'data/database_helper.dart';
import 'providers/climate_provider.dart';
import 'providers/cycle_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/root_scaffold.dart';
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

class _ElaraRoot extends StatelessWidget {
  const _ElaraRoot();

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the theme setting actually changes.
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (settings) => settings.themeMode,
    );

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ElaraTheme.light(),
      darkTheme: ElaraTheme.dark(),
      home: const RootScaffold(),
    );
  }
}
