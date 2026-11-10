import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';

/// One settings group, as its own page.
///
/// Settings used to be a single scroll: location, her cycle, preferences,
/// symptoms, reminders, health information, appearance, six notification
/// switches, privacy, data, about. Every one of those was worth having; none of
/// them was worth reading at the same time as the other nine. The list is now a
/// hub of rows, and each row opens a page holding exactly one subject.
///
/// The page carries a plain back arrow rather than a title bar with a large
/// heading, because the row the reader tapped already said the name and the
/// screen below them repeats it once, in the body.
class ElaraSettingsPage extends StatelessWidget {
  const ElaraSettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;

  /// One line under the title: what this page is for.
  final String? subtitle;

  /// An optional control on the title row, e.g. a status pill.
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ElaraSpacing.md,
                ElaraSpacing.xs,
                ElaraSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(ElaraIcons.previous),
                    color: tokens.textPrimary,
                    tooltip: 'Back to settings',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: ElaraSpacing.pageInsets(context, top: ElaraSpacing.sm),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: type.headline(tokens.textPrimary, size: 26),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: ElaraSpacing.md),
                        trailing!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: ElaraSpacing.xs),
                    Text(
                      subtitle!,
                      style: type.caption(tokens.textSecondaryStrong),
                    ),
                  ],
                  const SizedBox(height: ElaraSpacing.lg),
                  ...children,
                  const SizedBox(height: ElaraSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
