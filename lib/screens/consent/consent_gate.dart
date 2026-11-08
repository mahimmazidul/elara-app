import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/consent_provider.dart';
import '../../theme/elara_theme.dart';
import '../root_scaffold.dart';
import 'consent_screen.dart';

/// Decides between the app and the consent screen.
///
/// The gate is deliberately strict: only [ConsentState.granted] renders the
/// tabs. Everything else — never asked, revoked, or an upgrade waiting for an
/// acknowledgement — shows the consent screen, so there is no path into the app
/// that skips the question. The one exception is [ConsentState.unknown], which
/// means the database has not answered yet and is shown as a brief neutral
/// frame rather than as a decision.
class ConsentGate extends StatelessWidget {
  const ConsentGate({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` rather than `select`: the provider notifies only on a real
    // decision, so there is nothing to filter, and a missed rebuild here would
    // leave someone stuck on the gate with the decision already recorded.
    final consent = context.watch<ConsentProvider>();
    final state = consent.state;

    switch (state) {
      case ConsentState.granted:
        return const RootScaffold();
      case ConsentState.unknown:
        // Two different situations wear this state. While the first read is
        // still in flight there is nothing to say, so the frame stays empty
        // rather than flashing a spinner. Once the read has failed, the user
        // is told, because a blank screen with no explanation is the worst
        // possible way to report a storage problem.
        if (!consent.hasFailed) return const Scaffold(body: SizedBox.shrink());
        return _StorageProblem(
          message: consent.lastError ?? 'Elara could not read its data.',
          onRetry: consent.load,
        );
      case ConsentState.notAsked:
      case ConsentState.revoked:
      case ConsentState.legacyAcknowledgementDue:
        return ConsentScreen(state: state);
    }
  }
}

/// Shown when the consent state could not be read at all.
///
/// Deliberately not a way into the app: if the database cannot be opened, the
/// gate cannot know whether consent was given, and guessing in either direction
/// would be wrong.
class _StorageProblem extends StatelessWidget {
  const _StorageProblem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ElaraSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elara could not open its data',
                    style: type.title(tokens.textPrimary, size: 18),
                  ),
                  const SizedBox(height: ElaraSpacing.sm),
                  Text(message, style: type.body(tokens.textSecondaryStrong)),
                  const SizedBox(height: ElaraSpacing.lg),
                  FilledButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
