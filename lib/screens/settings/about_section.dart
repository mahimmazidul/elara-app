import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_info.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/update_service.dart';
import '../../theme/elara_theme.dart';
import '../../utils/open_link.dart';
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
        const SizedBox(height: ElaraSpacing.xs),
        Text(
          'Elara\\u2019s own ensemble, developed from OpenCiclo and Flowlytics.',
          style: type.caption(tokens.textSecondaryStrong, size: 12),
        ),
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
          label: 'Releases',
          icon: ElaraIcons.download,
          url: UpdateService.releasesPageUrl,
        ),
        const SizedBox(height: ElaraSpacing.md),
        // The author's own accounts, not invented ones. The paths are in
        // AppInfo beside the repository URL, so a typo is one edit in one place
        // rather than a broken link on a settings screen.
        const SizedBox(height: ElaraSpacing.sm),
        _LinkRow(
          label: 'Facebook',
          icon: ElaraIcons.facebook,
          url: AppInfo.facebookUrl,
        ),
        const SizedBox(height: ElaraSpacing.sm),
        _LinkRow(
          label: 'Telegram',
          icon: ElaraIcons.telegram,
          url: AppInfo.telegramUrl,
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
    BuildContext context,
    UpdateProvider updates,
  ) async {
    await updates.check();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.elara.bgCard,
      builder: (context) => _UpdateResultSheet(updates: updates),
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

/// A tappable row with an icon, opened in the browser.
///
/// The address itself is not printed. A URL in a settings list is a developer's
/// idea of a label: it is the least readable part of the row, it truncates on a
/// phone, and it tells someone nothing they did not already know from the word
/// above it. The row says what it opens and the arrow says it leaves the app.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.icon, required this.url});

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraPressable(
      onTap: () => openLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.textSecondaryStrong),
            const SizedBox(width: ElaraSpacing.md),
            Expanded(
              child: Text(
                label,
                style: type.body(tokens.textPrimary, size: 14),
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

/// Limitations and privacy claims, stated plainly.
class _LimitationsPanel extends StatelessWidget {
  const _LimitationsPanel();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return ElaraGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentence case, because a lowercase fragment reads as a truncated
          // sentence rather than as a heading.
          //
          // The heading used to be "Not a medical device" followed by three
          // sentences about what the app is not. A reader who came here for
          // reassurance about contraception got a list of denials; the same
          // information now opens with what the estimate is, and puts the
          // clinician in the second sentence where it is an instruction rather
          // than a disclaimer.
          Text(
            'An estimate, and how far to trust it',
            style: type.subtitle(tokens.textPrimary),
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            'Elara reads the dates you record and estimates from them; every '
            'window it shows carries the margin it was calculated with. For '
            'contraception, or a change that worries you, it points you to a '
            'clinician, on the screens where it matters.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Everything it records stays on this phone.',
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
                  Text(
                    'Check for updates',
                    style: type.label(tokens.textSecondaryStrong),
                  ),
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

/// What the update check found, in a sheet rather than a bare dialog.
///
/// The sheet exists because of one sentence: **Elara will not install this for
/// you**. This app is distributed as an APK from GitHub Releases, so the user
/// does the installing, and a button labelled "Download" that silently produced
/// an installer prompt would be the app doing something it did not say it would
/// do. The file name and size are here for the same reason: a man on a metered
/// connection in Khulna is entitled to know what 21 MB is before he spends it.
class _UpdateResultSheet extends StatelessWidget {
  const _UpdateResultSheet({required this.updates});

  final UpdateProvider updates;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final release = updates.release;

    final title = switch (updates.status) {
      UpdateStatus.available => 'Version ${release?.version} is available',
      UpdateStatus.current => 'Up to date',
      UpdateStatus.failed =>
        updates.isOffline ? 'Could not check for updates' : 'Check failed',
      _ => 'Checking…',
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ElaraSpacing.lg,
          ElaraSpacing.sm,
          ElaraSpacing.lg,
          ElaraSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: type.subtitle(tokens.textPrimary)),
            const SizedBox(height: ElaraSpacing.sm),
            ..._body(context, tokens, type),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    ElaraTokens tokens,
    ElaraTypography type,
  ) {
    final release = updates.release;
    final apk = release?.arm64Apk;

    switch (updates.status) {
      case UpdateStatus.available:
        return [
          if ((release?.notes ?? '').trim().isNotEmpty)
            Text(release!.notes.trim(), style: type.body(tokens.textPrimary)),
          if (apk != null) ...[
            const SizedBox(height: ElaraSpacing.md),
            Row(
              children: [
                Icon(
                  ElaraIcons.download,
                  size: 18,
                  color: tokens.textSecondaryStrong,
                ),
                const SizedBox(width: ElaraSpacing.sm),
                Expanded(
                  child: Text(
                    apk.sizeLabel.isEmpty
                        ? apk.name
                        : '${apk.name} · ${apk.sizeLabel}',
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: ElaraSpacing.md),
          Text(
            'Elara will not install this for you. Android asks you to confirm '
            'the install once the file has downloaded.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: apk == null
                      ? null
                      : () => openLink(context, apk.downloadUrl),
                  child: const Text('Download APK'),
                ),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ];
      case UpdateStatus.current:
        return [
          Text(
            'You already have the latest release (${updates.summary}).',
            style: type.body(tokens.textPrimary),
          ),
          const SizedBox(height: ElaraSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ];
      case UpdateStatus.failed:
        return [
          // The reason is the service's own words, not a guess made here.
          // "Offline" has to mean offline: telling a user with four bars that
          // she has no connection is a small lie that costs her trust in every
          // other sentence on the screen.
          Text(
            updates.message ?? 'The update check did not produce an answer.',
            style: type.body(tokens.textPrimary),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Elara works offline: every screen still works without a '
            'connection, so this changes nothing she has recorded.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ];
      default:
        return const [];
    }
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
