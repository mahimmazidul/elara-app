import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/cycle_mode.dart';
import '../../providers/settings_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/motion.dart';
import '../../widgets/primitives.dart';

/// Settings > "Her cycle", where the app is told whether it may predict.
///
/// The question is asked in her terms, not in clinical ones, and every option
/// says what will stop happening, because "turn off predictions" is not a thing
/// anyone can picture. The default is untouched: an install that has never
/// opened this screen behaves exactly as it did before.
class CycleModeSection extends StatelessWidget {
  const CycleModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final settings = context.watch<SettingsProvider>();
    final mode = settings.cycleMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Her cycle'),
        Text(
          'Elara estimates a next period from recorded history. Sometimes that '
          'estimate is not meaningful, and it is better for the app to say so '
          'than to keep counting.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.sm),
        _ModeChoice(
          label: 'Estimate my cycle',
          detail: 'Phase, next period and the uncertainty window.',
          selected: mode == CycleMode.predicting,
          onTap: () => _set(context, CycleMode.predicting),
        ),
        const Hairline(margin: 0),
        _ModeChoice(
          label: 'She uses hormonal contraception',
          detail:
              'Pills, implant, injection or a hormonal IUD. No phase, no '
              'countdown, no fertile window. Bleeding and symptoms can still '
              'be logged.',
          selected: mode == CycleMode.hormonalContraception,
          onTap: () => _set(context, CycleMode.hormonalContraception),
        ),
        const Hairline(margin: 0),
        _ModeChoice(
          label: 'Pause prediction',
          detail:
              'For a pregnancy, a loss, after a birth, or simply because '
              'she would rather not be given a date.',
          selected: mode == CycleMode.paused,
          onTap: () => _set(context, CycleMode.paused),
        ),
        if (mode == CycleMode.paused) ...[
          const SizedBox(height: ElaraSpacing.md),
          Text(
            'Saying why is optional. It changes the wording on Today, and it '
            'stays on this phone.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Wrap(
            spacing: ElaraSpacing.sm,
            runSpacing: ElaraSpacing.xs,
            children: [
              for (final reason in PauseReason.values)
                ChoiceChip(
                  label: Text(_reasonLabel(reason)),
                  selected: settings.pauseReason == reason,
                  onSelected: (_) => _set(
                    context,
                    CycleMode.paused,
                    reason: settings.pauseReason == reason ? null : reason,
                  ),
                ),
            ],
          ),
        ],
        if (!mode.predicts) ...[
          const SizedBox(height: ElaraSpacing.md),
          Row(
            children: [
              Icon(
                ElaraIcons.info,
                size: 16,
                color: tokens.textSecondaryStrong,
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  'Reminders about a period, a fertile window or PMS are off '
                  'while this is set. Nothing already logged is deleted.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _set(
    BuildContext context,
    CycleMode mode, {
    PauseReason? reason,
    bool keepReason = false,
  }) async {
    final settings = context.read<SettingsProvider>();
    if (keepReason) {
      // Selecting a reason chip while paused: keep the existing pause start.
      final ok = await settings.setCycleMode(
        mode,
        reason: reason,
        since: settings.pauseSince,
      );
      if (!context.mounted) return;
      _reportFailure(context, settings, ok);
      return;
    }
    final ok = await settings.setCycleMode(mode, reason: reason);
    if (!context.mounted) return;
    _reportFailure(context, settings, ok);
  }

  void _reportFailure(
    BuildContext context,
    SettingsProvider settings,
    bool ok,
  ) {
    if (ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(settings.lastError ?? 'Could not save that setting.'),
      ),
    );
  }

  static String _reasonLabel(PauseReason reason) {
    switch (reason) {
      case PauseReason.pregnancy:
        return 'Pregnancy';
      case PauseReason.loss:
        return 'After a loss';
      case PauseReason.postpartum:
        return 'After a birth';
      case PauseReason.other:
        return 'Rather not say';
    }
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? ElaraIcons.selected : ElaraIcons.unselected,
              size: 20,
              color: selected ? tokens.accentText : tokens.textSecondaryStrong,
            ),
            const SizedBox(width: ElaraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: type.bodyStrong(tokens.textPrimary)),
                  const SizedBox(height: 2),
                  Text(detail, style: type.caption(tokens.textSecondaryStrong)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
