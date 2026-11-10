import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/medical_content.dart';
import '../../providers/consent_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../medical/medical_screen.dart';
import '../preferences/preferences_screen.dart';
import '../reminders/reminders_screen.dart';
import '../symptoms/symptoms_screen.dart';
import 'about_section.dart';
import 'appearance_page.dart';
import 'cycle_mode_section.dart';
import 'location_page.dart';
import 'notifications_page.dart';
import 'privacy_data_section.dart';
import '../../widgets/sub_page.dart';

/// The settings hub.
///
/// This screen used to be the settings: one scroll holding location, her cycle,
/// preferences, symptoms, reminders, health information, appearance, six
/// notification switches, privacy, backup and about. Nine subjects, one column,
/// no way to jump to any of them. It was, fairly, described as too much
/// information together.
///
/// It is now a list. Each row is one subject, carries the one line that tells
/// you whether you need to open it, and opens a page holding only that subject.
/// Nothing was removed: every control that lived here still exists, one tap
/// deeper, on a page whose title says where it is.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final settings = context.watch<SettingsProvider>();
    final consent = context.watch<ConsentProvider>();
    final preferences = context.watch<PreferencesProvider>();
    final symptoms = context.watch<SymptomsProvider>();
    final reminders = context.watch<RemindersProvider>();

    return ListView(
      padding: ElaraSpacing.pageInsets(context),
      children: [
        Text('Settings', style: type.headline(tokens.textPrimary, size: 28)),
        const SizedBox(height: ElaraSpacing.xs),
        Text(
          'Everything Elara does, and nothing it does not.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.lg),

        // ---- her cycle, first: it decides what the app is willing to say
        const _GroupLabel('Her cycle'),
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Cycle mode',
              subtitle: settings.cycleMode.summary,
              icon: ElaraIcons.timeline,
              onTap: () =>
                  Navigator.of(context).push(CycleModePage.route(context)),
            ),
            ElaraListRow(
              title: 'Preferences',
              subtitle: preferences.summary,
              icon: ElaraIcons.care,
              onTap: () =>
                  Navigator.of(context).push(PreferencesScreen.route(context)),
            ),
            ElaraListRow(
              title: 'Symptoms',
              subtitle: symptoms.summary,
              icon: ElaraIcons.symptom,
              onTap: () =>
                  Navigator.of(context).push(SymptomsScreen.route(context)),
            ),
            ElaraListRow(
              title: 'Care reminders',
              subtitle: reminders.summary,
              icon: ElaraIcons.notification,
              onTap: () =>
                  Navigator.of(context).push(RemindersScreen.route(context)),
            ),
          ],
        ),

        // ---- the app itself
        const SizedBox(height: ElaraSpacing.xl),
        const _GroupLabel('The app'),
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Notifications',
              subtitle: settings.notificationsEnabled
                  ? 'On · ${settings.enabledReminderCount} of 5 reminders'
                  : 'Off',
              icon: ElaraIcons.notification,
              onTap: () =>
                  Navigator.of(context).push(NotificationsPage.route(context)),
            ),
            ElaraListRow(
              title: 'Location',
              subtitle:
                  '${settings.latitude.toStringAsFixed(3)}, '
                  '${settings.longitude.toStringAsFixed(3)} · typed in',
              icon: ElaraIcons.weather,
              onTap: () =>
                  Navigator.of(context).push(LocationPage.route(context)),
            ),
            ElaraListRow(
              title: 'Appearance',
              subtitle: switch (settings.themeMode) {
                ThemeMode.system => 'Follows the phone',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              icon: ElaraIcons.themeSystem,
              onTap: () =>
                  Navigator.of(context).push(AppearancePage.route(context)),
            ),
            ElaraListRow(
              title: 'Health information',
              subtitle:
                  '${medicalTopics.length} topics · not personalised · '
                  'sources dated',
              icon: ElaraIcons.medical,
              onTap: () =>
                  Navigator.of(context).push(MedicalScreen.route(context)),
            ),
          ],
        ),

        // ---- what is stored, and how to get rid of it
        const SizedBox(height: ElaraSpacing.xl),
        const _GroupLabel('Data'),
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Privacy and data',
              subtitle: consent.hasConsent
                  ? 'Consent recorded · export, restore, delete everything'
                  : 'Consent not recorded',
              icon: ElaraIcons.privacy,
              onTap: () =>
                  Navigator.of(context).push(PrivacyPage.route(context)),
            ),
            ElaraListRow(
              title: 'About',
              subtitle: 'Version, licences, source, update check',
              icon: ElaraIcons.info,
              onTap: () => Navigator.of(context).push(AboutPage.route(context)),
            ),
          ],
        ),

        const SizedBox(height: ElaraSpacing.xl),
        Text(
          'Elara keeps one cycle history on this phone. There is no account, no '
          'sync and nothing to sign in to, so exporting a backup is the only way '
          'data leaves it — under a passphrase you choose.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }
}

/// A small heading above a group of rows.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Padding(
      padding: const EdgeInsets.only(
        left: ElaraSpacing.xxs,
        bottom: ElaraSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.type
            .caption(tokens.textSecondaryStrong, size: 11)
            .copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The cycle-mode choice, on its own page.
class CycleModePage extends StatelessWidget {
  const CycleModePage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const CycleModePage());
  }

  @override
  Widget build(BuildContext context) {
    return const ElaraSubPage(
      title: 'Cycle mode',
      subtitle:
          'Elara estimates a next period from recorded history. Sometimes that '
          'estimate is not meaningful, and it is better for the app to say so '
          'than to keep counting.',
      children: [CycleModeSection()],
    );
  }
}

/// Privacy, consent, backup and deletion, on its own page.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const PrivacyPage());
  }

  @override
  Widget build(BuildContext context) {
    return const ElaraSubPage(
      title: 'Privacy and data',
      subtitle: 'What is stored, what protects it, and how to remove it.',
      children: [PrivacyDataSection()],
    );
  }
}

/// About, on its own page.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const AboutPage());
  }

  @override
  Widget build(BuildContext context) {
    return const ElaraSubPage(
      title: 'About',
      subtitle: 'Version, licences and the source this is built from.',
      children: [AboutSection()],
    );
  }
}
