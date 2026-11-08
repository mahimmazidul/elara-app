import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database_helper.dart';
import 'providers/climate_provider.dart';
import 'providers/cycle_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElaraApp());
}

/// Root of the app: owns the provider graph and the [MaterialApp].
///
/// Data-layer dependency order matters here. [DatabaseHelper] is exposed first
/// so every provider below can be constructed against the same connection, and
/// [PredictionProvider] is last because it refreshes when the cycle list or the
/// settings change.
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
        // Depends on both, so proxy it: when either is written, the prediction
        // is recomputed (deferred to after the frame; see syncDependencies).
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

/// Temporary shell until the UI parts are built.
///
/// It reads from the providers only so that the graph is exercised on launch;
/// it deliberately contains no product UI.
class _ElaraRoot extends StatelessWidget {
  const _ElaraRoot();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Elara',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A4E7E)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A4E7E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Elara')),
      ),
    );
  }
}
