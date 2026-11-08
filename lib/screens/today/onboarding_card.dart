import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../providers/cycle_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';

/// Shown full-screen when no cycle has ever been logged.
///
/// One job: ask for the date the last period started, then confirm. Saving the
/// cycle is enough to leave this state — the provider graph reloads history,
/// recomputes the prediction, and the Today screen renders its normal content.
class OnboardingCard extends StatefulWidget {
  const OnboardingCard({super.key});

  @override
  State<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<OnboardingCard> {
  DateTime? _selectedDate;
  bool _saving = false;

  Future<void> _pickDate() async {
    final tokens = context.elara;
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      // A period start cannot be in the future; open ended in the past.
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Last period start',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: tokens.bgCard,
              surfaceTintColor: tokens.transparent,
              headerBackgroundColor: tokens.bgPrimary,
              headerForegroundColor: tokens.textPrimary,
              todayForegroundColor: WidgetStateProperty.all(tokens.accentText),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? tokens.accent
                    : tokens.transparent,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? tokens.onPhase
                    : tokens.textPrimary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = dateOnly(picked));
    }
  }

  Future<void> _confirm() async {
    final date = _selectedDate;
    if (date == null || _saving) return;

    setState(() => _saving = true);
    final provider = context.read<CycleProvider>();
    final stored = await provider.addCycle(startDate: date);
    if (!mounted) return;
    setState(() => _saving = false);

    if (stored == null) {
      final message = provider.lastError ?? 'Could not save that date.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    // On success the Today tab rebuilds with real content; nothing to navigate.
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final canConfirm = _selectedDate != null && !_saving;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ElaraSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ElaraCard(
              padding: const EdgeInsets.all(ElaraSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to Elara',
                    style: type.headline(tokens.textPrimary, size: 26),
                  ),
                  const SizedBox(height: ElaraSpacing.sm),
                  Text(
                    'Everything stays on this phone. No account, no cloud.',
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                  const SizedBox(height: ElaraSpacing.xl),

                  Text(
                    "When did your wife's last period start?",
                    style: type.subtitle(tokens.textPrimary, size: 17),
                  ),
                  const SizedBox(height: ElaraSpacing.xs),
                  Text(
                    'This one date is enough for a first estimate. '
                    'More recorded starts make the prediction steadier.',
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                  const SizedBox(height: ElaraSpacing.lg),

                  InkWell(
                    onTap: _saving ? null : _pickDate,
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ElaraSpacing.lg,
                        vertical: ElaraSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.bgPrimary,
                        borderRadius: BorderRadius.circular(ElaraRadii.chip),
                        border: Border.all(color: tokens.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: tokens.textSecondaryStrong,
                          ),
                          const SizedBox(width: ElaraSpacing.md),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Choose a date'
                                  : _formatDate(_selectedDate!),
                              style: type.subtitle(
                                _selectedDate == null
                                    ? tokens.textSecondaryStrong
                                    : tokens.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ElaraSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canConfirm ? _confirm : null,
                      child: _saving
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.onPhase,
                              ),
                            )
                          : const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(height: ElaraSpacing.md),
                  Text(
                    'Elara is not a contraceptive and cannot confirm ovulation. '
                    'Predictions are calendar estimates.',
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
