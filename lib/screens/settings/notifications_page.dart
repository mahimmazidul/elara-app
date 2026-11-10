import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import 'settings_page.dart';

/// Every reminder Elara can send, on one page.
///
/// The master switch gates the five below it. They keep their stored values
/// while it is off, so turning it back on restores the choices rather than
/// resetting them — which is what a switch that looked disabled used to do in
/// practice, because a user who turns the master off and on again has not asked
/// to lose their settings.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const NotificationsPage());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final type = context.type;
    final tokens = context.elara;

    Future<void> apply(Future<bool> Function(bool) setter, bool value) async {
      await setter(value);
      if (!context.mounted) return;
      // A reminder switched off here keeps its queued alarms until the app is
      // next resumed, which for a privacy switch is the difference between
      // "off" and "off tomorrow".
      await context.read<NotificationRescheduler>().reschedule();
    }

    return ElaraSettingsPage(
      title: 'Notifications',
      subtitle:
          'Scheduled on this device by the Android alarm manager. Nothing is '
          'sent to a server.',
      children: [
        _ToggleRow(
          label: 'Enable notifications',
          subtitle: 'Master switch for all reminders.',
          value: settings.notificationsEnabled,
          onChanged: (value) => apply(settings.setNotificationsEnabled, value),
        ),
        const Hairline(),
        _ToggleRow(
          label: 'Daily briefing',
          subtitle: 'A short morning summary of the current phase.',
          value: settings.notifyDailyBriefing,
          onChanged: (value) => apply(settings.setNotifyDailyBriefing, value),
          enabled: settings.notificationsEnabled,
        ),
        _ToggleRow(
          label: 'PMS warning',
          subtitle: 'Heads-up before the late luteal phase.',
          value: settings.notifyPmsWarning,
          onChanged: (value) => apply(settings.setNotifyPmsWarning, value),
          enabled: settings.notificationsEnabled,
        ),
        _ToggleRow(
          label: 'Ovulation window',
          subtitle: 'When the estimated fertile window opens.',
          value: settings.notifyOvulationWindow,
          onChanged: (value) => apply(settings.setNotifyOvulationWindow, value),
          enabled: settings.notificationsEnabled,
        ),
        _ToggleRow(
          label: 'Period start',
          subtitle: 'On the day a period is expected.',
          value: settings.notifyPeriodStart,
          onChanged: (value) => apply(settings.setNotifyPeriodStart, value),
          enabled: settings.notificationsEnabled,
        ),
        _ToggleRow(
          label: 'Climate spike',
          subtitle: 'When heat index or PM2.5 rises sharply.',
          value: settings.notifyClimateSpike,
          onChanged: (value) => apply(settings.setNotifyClimateSpike, value),
          enabled: settings.notificationsEnabled,
        ),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'With prediction switched off, the phase, period and fertile-window '
          'reminders are not scheduled at all rather than left queued.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final isOn = enabled && value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: type.subtitle(
                    enabled ? tokens.textPrimary : tokens.textSecondaryStrong,
                    size: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: type.caption(tokens.textSecondaryStrong)),
              ],
            ),
          ),
          const SizedBox(width: ElaraSpacing.md),
          Switch.adaptive(
            value: isOn,
            onChanged: enabled ? (v) => onChanged(v) : null,
            activeTrackColor: tokens.accent,
            activeThumbColor: tokens.bgCard,
            inactiveTrackColor: tokens.track,
            inactiveThumbColor: tokens.textSecondary,
          ),
        ],
      ),
    );
  }
}
