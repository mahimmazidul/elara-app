import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_info.dart';
import '../../providers/settings_keys.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import 'privacy_data_section.dart';

/// Settings tab: location, theme, notifications and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  String? _locationError;
  bool _savingLocation = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _latController =
        TextEditingController(text: _trim(settings.latitude.toString()));
    _lonController =
        TextEditingController(text: _trim(settings.longitude.toString()));
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  static String _trim(String value) {
    // 23.8103 rather than 23.810300000000001.
    return value.length > 9 ? value.substring(0, 9) : value;
  }

  Future<void> _saveLocation() async {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());

    if (lat == null || lon == null) {
      setState(() => _locationError = 'Enter both coordinates as numbers.');
      return;
    }

    setState(() {
      _savingLocation = true;
      _locationError = null;
    });

    final settings = context.read<SettingsProvider>();
    final ok = await settings.setLocation(latitude: lat, longitude: lon);

    if (!mounted) return;
    setState(() {
      _savingLocation = false;
      _locationError = ok ? null : settings.lastError;
    });

    if (ok) {
      _latController.text = _trim(lat.toString());
      _lonController.text = _trim(lon.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location saved.')),
      );
    }
  }

  Future<void> _useDhaka() async {
    final settings = context.read<SettingsProvider>();
    final ok = await settings.setLocation(
      latitude: SettingsKeys.defaultLatitude,
      longitude: SettingsKeys.defaultLongitude,
    );
    if (!mounted) return;
    if (ok) {
      _latController.text = _trim(SettingsKeys.defaultLatitude.toString());
      _lonController.text = _trim(SettingsKeys.defaultLongitude.toString());
      setState(() => _locationError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set to Dhaka.')),
      );
    } else {
      setState(() => _locationError = settings.lastError);
    }
  }

  /// Persists a reminder switch, then rebuilds the schedule.
  ///
  /// Without the second step a reminder switched off here keeps its queued
  /// alarms until the app is next resumed, which for a privacy switch is the
  /// difference between "off" and "off tomorrow".
  Future<bool> _applyNotificationChange(
    Future<bool> Function(bool) setter,
    bool value,
  ) async {
    final ok = await setter(value);
    if (!mounted) return ok;
    if (ok) {
      try {
        await context.read<NotificationRescheduler>().reschedule();
      } catch (_) {
        // A scheduling problem must not surface as a failed toggle.
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final settings = context.watch<SettingsProvider>();

    return ListView(
      padding: ElaraSpacing.pageInsets(context),
      children: [
        Text('Settings', style: type.headline(tokens.textPrimary, size: 28)),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- location
        const SectionTitle('Location'),
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Used for heat index and air quality. Stored on this device only.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _CoordinateField(
                      label: 'Latitude',
                      controller: _latController,
                      hint: '23.8103',
                    ),
                  ),
                  const SizedBox(width: ElaraSpacing.md),
                  Expanded(
                    child: _CoordinateField(
                      label: 'Longitude',
                      controller: _lonController,
                      hint: '90.4125',
                    ),
                  ),
                ],
              ),
              if (_locationError != null) ...[
                const SizedBox(height: ElaraSpacing.sm),
                Text(
                  _locationError!,
                  style: type.caption(tokens.dangerText),
                ),
              ],
              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _useDhaka,
                    child: const Text('Dhaka default'),
                  ),
                  const SizedBox(width: ElaraSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _savingLocation ? null : _saveLocation,
                      child: _savingLocation
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.onPhase,
                              ),
                            )
                          : const Text('Save location'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- theme
        const SectionTitle('Appearance'),
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElaraOverline('Theme'),
              const SizedBox(height: ElaraSpacing.md),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    settings.setThemeMode(selection.first);
                  },
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- notifications
        const SectionTitle('Notifications'),
        ElaraCard(
          child: Column(
            children: [
              _ToggleRow(
                label: 'Enable notifications',
                subtitle: 'Master switch for all reminders.',
                value: settings.notificationsEnabled,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotificationsEnabled,
                  value,
                ),
              ),
              const _Hairline(),
              _ToggleRow(
                label: 'Daily briefing',
                subtitle: 'A short morning summary of the current phase.',
                value: settings.notifyDailyBriefing,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotifyDailyBriefing,
                  value,
                ),
                enabled: settings.notificationsEnabled,
              ),
              _ToggleRow(
                label: 'PMS warning',
                subtitle: 'Heads-up before the late luteal phase.',
                value: settings.notifyPmsWarning,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotifyPmsWarning,
                  value,
                ),
                enabled: settings.notificationsEnabled,
              ),
              _ToggleRow(
                label: 'Ovulation window',
                subtitle: 'When the estimated fertile window opens.',
                value: settings.notifyOvulationWindow,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotifyOvulationWindow,
                  value,
                ),
                enabled: settings.notificationsEnabled,
              ),
              _ToggleRow(
                label: 'Period start',
                subtitle: 'On the day a period is expected.',
                value: settings.notifyPeriodStart,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotifyPeriodStart,
                  value,
                ),
                enabled: settings.notificationsEnabled,
              ),
              _ToggleRow(
                label: 'Climate spike',
                subtitle: 'When heat index or PM2.5 rises sharply.',
                value: settings.notifyClimateSpike,
                onChanged: (value) => _applyNotificationChange(
                  settings.setNotifyClimateSpike,
                  value,
                ),
                enabled: settings.notificationsEnabled,
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'Reminders are scheduled on this device. Nothing is sent '
                'to a server.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- privacy and data
        const SectionTitle('Privacy and data'),
        const PrivacyDataSection(),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- about
        const SectionTitle('About'),
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppInfo.name,
                      style: type.title(tokens.textPrimary, size: 18),
                    ),
                  ),
                  NumberText(AppInfo.version, size: 13,
                      color: tokens.textSecondaryStrong),
                ],
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(AppInfo.tagline,
                  style: type.body(tokens.textSecondaryStrong)),
              const SizedBox(height: ElaraSpacing.md),
              const _Hairline(),
              const SizedBox(height: ElaraSpacing.md),
              _AboutRow(label: 'Licence', value: AppInfo.license),
              const SizedBox(height: ElaraSpacing.sm),
              _AboutRow(label: 'Prediction engine', value: 'elara-core'),
              const SizedBox(height: ElaraSpacing.md),
              _LinkRow(
                label: 'Source code',
                url: AppInfo.repositoryUrl,
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'Elara is not a medical device and not a contraceptive. '
                'Predictions are calendar estimates.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ],
      style: context.type.number(tokens.textPrimary, size: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: context.type.label(tokens.textSecondaryStrong),
        hintStyle: context.type.number(tokens.textSecondary, size: 15),
        filled: true,
        fillColor: tokens.bgPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ElaraSpacing.md,
          vertical: ElaraSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
          borderSide: BorderSide(color: tokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
          borderSide: BorderSide(color: tokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
          borderSide: BorderSide(color: tokens.accent),
        ),
      ),
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
  final Future<bool> Function(bool value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    // A sub-toggle with the master switch off keeps its stored value but is not
    // interactive, so turning the master back on restores the prior choices.
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
                Text(
                  subtitle,
                  style: type.caption(tokens.textSecondaryStrong),
                ),
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

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: ElaraSpacing.md),
      color: context.elara.divider,
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Row(
      children: [
        Text(label, style: context.type.label(tokens.textSecondaryStrong)),
        const Spacer(),
        Text(value, style: context.type.bodyStrong(tokens.textPrimary, size: 14)),
      ],
    );
  }
}

/// Repository link. Copies to the clipboard rather than launching a browser,
/// because `url_launcher` is not a declared dependency and the dependency list
/// for this app is fixed.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return InkWell(
      borderRadius: BorderRadius.circular(ElaraRadii.chip),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository URL copied.')),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: type.label(tokens.textSecondaryStrong)),
                const SizedBox(height: 2),
                Text(url,
                    style: type.bodyStrong(tokens.accentText, size: 13)),
              ],
            ),
          ),
          Icon(Icons.copy_rounded, size: 16, color: tokens.textSecondaryStrong),
        ],
      ),
    );
  }
}
