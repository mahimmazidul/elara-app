import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/phase_chip.dart';
import '../../widgets/primitives.dart';
import '../../widgets/score_bar.dart';

/// Bottom sheet for a tapped calendar day: phase, action scores and food.
///
/// The scores are recomputed for that specific day by running elara-core's
/// [core.ActionEngine] against the day's phase and today's environmental
/// severity. Severity is not available per future day (no forecast is cached
/// that far ahead), so today's conditions are used and the sheet says so.
class DayDetailSheet extends StatelessWidget {
  const DayDetailSheet({
    super.key,
    required this.day,
    required this.severity,
  });

  final PhaseDay day;
  final core.SeverityResult? severity;

  /// Shows the sheet for [day].
  static Future<void> show(
    BuildContext context, {
    required PhaseDay day,
    core.SeverityResult? severity,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DayDetailSheet(day: day, severity: severity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    // A day before the first recorded start has no phase to act on.
    final result = _actionFor(context);
    final phaseKey = day.key;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ElaraSpacing.lg,
          0,
          ElaraSpacing.lg,
          ElaraSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(day.date),
                        style: type.title(tokens.textPrimary, size: 20),
                      ),
                      const SizedBox(height: ElaraSpacing.xxs),
                      Text(
                        day.isRecorded ? 'Recorded cycle' : 'Projected',
                        style: type.caption(tokens.textSecondaryStrong),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ElaraSpacing.md),
            PhaseChip(
              label: day.label,
              phaseKey: phaseKey,
              compact: true,
            ),
            const SizedBox(height: ElaraSpacing.lg),

            if (result == null)
              Text(
                'This day falls before the first recorded period, so Elara '
                'cannot say which phase it was in.',
                style: type.body(tokens.textSecondaryStrong),
              )
            else ...[
              ScoreBar(
                label: 'Conversation',
                score: result.conversationScore,
                phaseKey: phaseKey,
              ),
              const SizedBox(height: ElaraSpacing.md),
              ScoreBar(
                label: 'Romance',
                score: result.romanceScore,
                phaseKey: phaseKey,
              ),
              const SizedBox(height: ElaraSpacing.lg),
              const ElaraOverline('Food'),
              const SizedBox(height: ElaraSpacing.sm),
              FoodChipRow(
                foods: result.foodSuggestions,
                phaseKey: phaseKey,
              ),
              const SizedBox(height: ElaraSpacing.md),
              Text(
                'Scores use today\u2019s climate; they are conversation prompts, '
                'not predictions about anyone\u2019s mood.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Runs the action engine for this day, or returns null when the day has no
  /// classified phase or no severity was supplied.
  ///
  /// Uses the day's real [core.PhaseResult] from the classifier — including its
  /// genuine fertile window and ovulation day — so nothing here is
  /// reconstructed or approximated.
  core.ActionResult? _actionFor(BuildContext context) {
    final sever = severity;
    final phaseResult = day.phaseResult;
    if (sever == null || phaseResult == null) return null;
    if (phaseResult.phase == core.CyclePhase.unknown) return null;

    try {
      return core.ActionEngine().recommend(
        phase: phaseResult,
        severity: sever,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
