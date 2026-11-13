import 'package:material_ui/material_ui.dart';

import '../theme/elara_theme.dart';
import 'icons.dart';

/// One subject, as its own page.
///
/// The pattern the settings hub established, and which Insights and the
/// context rows on Today now follow: a screen holds a short list of subjects,
/// each row carries the one line that says whether it needs opening, and the
/// page behind it holds only that subject.
///
/// It began as the fix for a settings screen carrying nine subjects in one
/// column. It turned out to be the right shape for the rest of the app too, so
/// it lives here in widgets rather than in the settings folder where it was
/// born.
///
/// The page carries a plain back arrow rather than a title bar with a large
/// heading, because the row the reader tapped already said the name and the
/// screen below them repeats it once, in the body.
class ElaraSubPage extends StatelessWidget {
  const ElaraSubPage({
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
                    tooltip: 'Back',
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
