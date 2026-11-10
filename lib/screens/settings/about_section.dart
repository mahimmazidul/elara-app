import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/update_service.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/motion.dart';
import '../../widgets/primitives.dart';

/// What this build is, who made it, what it is licensed under, and how to find
/// out whether a newer release exists.
///
/// The version shown comes from the app's own metadata ([AppInfo.version],
/// which the version-bump test keeps in step with `pubspec.yaml`), not from a
/// number typed into this file.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final settings = context.watch<SettingsProvider>();
    final updates = context.watch<UpdateProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A Wrap rather than a Row: at 320 dp with a 1.5x text scale the name
        // and the version could not share the line, and the row overflowed by
        // 60 px. Wrapping puts the version on its own line instead.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ElaraSpacing.sm,
          runSpacing: ElaraSpacing.xxs,
          children: [
            Text(AppInfo.name, style: type.title(tokens.textPrimary, size: 18)),
            NumberText(
              updates.displayVersion,
              size: 13,
              color: tokens.textSecondaryStrong,
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xs),
        Text(AppInfo.tagline, style: type.body(tokens.textSecondaryStrong)),
        const SizedBox(height: ElaraSpacing.md),
        const Hairline(margin: 0),
        const SizedBox(height: ElaraSpacing.md),
        _AboutRow(
          label: 'Version',
          value: updates.buildNumber == null
              ? updates.displayVersion
              : '${updates.displayVersion} '
                    '(build ${updates.buildNumber})',
        ),
        const SizedBox(height: ElaraSpacing.sm),
        const _AboutRow(label: 'Licence', value: AppInfo.license),
        const SizedBox(height: ElaraSpacing.sm),
        const _AboutRow(label: 'Developer', value: 'Md. Mazidul Islam Mahim'),
        const SizedBox(height: ElaraSpacing.sm),
        const _AboutRow(label: 'Prediction engine', value: 'elara-core'),
        const SizedBox(height: ElaraSpacing.md),
        // Social links are offered as recognisable icons with accessible
        // labels, never as raw URLs.
        _LinkRow(
          label: 'Source code',
          icon: ElaraIcons.github,
          url: AppInfo.repositoryUrl,
        ),
        const SizedBox(height: ElaraSpacing.sm),
        _LinkRow(
          label: 'Prediction engine',
          icon: ElaraIcons.github,
          url: AppInfo.engineUrl,
        ),
        const SizedBox(height: ElaraSpacing.sm),
        _LinkRow(
          label: 'Releases',
          icon: ElaraIcons.download,
          url: UpdateService.releasesPageUrl,
        ),
        const SizedBox(height: ElaraSpacing.md),
        // Elara has no social-media presence: say so directly rather than
        // fabricating profile links.
        Text(
          'Elara publishes no social accounts.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.md),
        // Limitations and privacy claims, stated plainly.
        const _LimitationsPanel(),
        const SizedBox(height: ElaraSpacing.md),
        // Update row: status + check button.
        _UpdateRow(
          status: updates.status,
          summary: updates.summary,
          isOffline: updates.isOffline,
          onCheck: () => _checkForUpdates(context, updates),
        ),
        const SizedBox(height: ElaraSpacing.md),
        _AutoCheckSwitch(
          value: settings.updatesAutoCheck,
          onChanged: (v) => settings.setUpdatesAutoCheck(v),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(
      BuildContext context, UpdateProvider updates) async {
    await updates.check();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => _UpdateResultDialog(updates: updates),
    );
  }
}

/// A simple label/value row for static about facts.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: type.label(tokens.textSecondaryStrong)),
          const SizedBox(height: 2),
          Text(value, style: type.bodyStrong(tokens.textPrimary, size: 13)),
        ],
      ),
    );
  }
}

/// A tappable row with an icon and a URL, opened in the browser.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraPressable(
      onTap: () => _launchUrl(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.textSecondaryStrong),
            const SizedBox(width: ElaraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: type.label(tokens.textSecondaryStrong)),
                  const SizedBox(height: 2),
                  Text(
                    _shortUrl(url),
                    style: type.bodyStrong(tokens.accentText, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ElaraSpacing.sm),
            Icon(ElaraIcons.disclosure, size: 16, color: tokens.accentText),
          ],
        ),
      ),
    );
  }

  static String _shortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url.')),
      );
    }
  }
}

/// Limitations and privacy claims, stated plainly.
class _LimitationsPanel extends StatelessWidget {
  const _LimitationsPanel();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not a medical device.',
            style: type.subtitle(tokens.textPrimary),
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            'Elara estimates from recorded history. It does not diagnose, and '
            'it is not a substitute for professional medical advice.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'No accounts, no analytics. Nothing leaves this phone.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}

/// Update status row: summary text plus a check button.
class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.status,
    required this.summary,
    required this.isOffline,
    required this.onCheck,
  });

  final UpdateStatus status;
  final String summary;
  final bool isOffline;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraPressable(
      onTap: onCheck,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
        child: Row(
          children: [
            Icon(
              status == UpdateStatus.available
                  ? ElaraIcons.download
                  : ElaraIcons.undo,
              size: 20,
              color: tokens.textSecondaryStrong,
            ),
            const SizedBox(width: ElaraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Check for updates',
                      style: type.label(tokens.textSecondaryStrong)),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: type.bodyStrong(tokens.accentText, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ElaraSpacing.sm),
            Icon(ElaraIcons.disclosure, size: 16, color: tokens.accentText),
          ],
        ),
      ),
    );
  }
}

/// Result dialog shown after an update check.
class _UpdateResultDialog extends StatelessWidget {
  const _UpdateResultDialog({required this.updates});

  final UpdateProvider updates;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final title = switch (updates.status) {
      UpdateStatus.available => 'Version ${updates.release?.version} is available',
      UpdateStatus.current => 'Up to date',
      UpdateStatus.failed =>
          updates.isOffline ? 'Could not check for updates' : 'Check failed',
      _ => 'Checking…',
    };

    final body = switch (updates.status) {
      UpdateStatus.available => updates.release?.notes ??
          'A newer release of Elara is available.',
      UpdateStatus.current =>
          'You already have the latest release (${updates.summary}).',
      UpdateStatus.failed =>
          updates.isOffline
              ? 'Elara works the same offline. Try again when you are back '
                  'online.'
              : 'The update check did not produce an answer.',
      _ => '',
    };

    return AlertDialog(
      title: Text(title, style: type.subtitle(tokens.textPrimary)),
      content: Text(body, style: type.body(tokens.textPrimary)),
      actions: [
        if (updates.status == UpdateStatus.available)
          TextButton(
            onPressed: () {
              final apk = updates.release?.arm64Apk;
              if (apk != null) _LinkRow._launchUrl(context, apk.downloadUrl);
            },
            child: const Text('Download APK'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// The start-up update switch, laid out like the other switches in the app.
class _AutoCheckSwitch extends StatelessWidget {
  const _AutoCheckSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(ElaraRadii.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check on start-up',
                      style: type.subtitle(tokens.textPrimary, size: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Off by default. When on, Elara makes the same single '
                      'request each time it opens.',
                      style: type.caption(tokens.textSecondaryStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ElaraSpacing.md),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
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
