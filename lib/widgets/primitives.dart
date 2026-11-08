import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';

/// The app's single card surface: flat fill, 14px radius, the one allowed
/// shadow. Material elevation is deliberately never used, so nothing in Elara
/// can accidentally acquire a heavier shadow.
class ElaraCard extends StatelessWidget {
  const ElaraCard({
    super.key,
    required this.child,
    this.padding = ElaraSpacing.card,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.bgCard,
        borderRadius: BorderRadius.circular(ElaraRadii.card),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: ElaraShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElaraRadii.card),
      child: card,
    );
  }
}

/// Small all-caps label above a value.
class ElaraOverline extends StatelessWidget {
  const ElaraOverline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Text(
      text.toUpperCase(),
      style: context.type.overline(color ?? tokens.textSecondaryStrong),
    );
  }
}

/// Section heading on a page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Padding(
      padding: const EdgeInsets.only(bottom: ElaraSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.type.title(tokens.textPrimary, size: 17),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A labelled numeral with tabular figures, so digits do not shift width.
class NumberText extends StatelessWidget {
  const NumberText(
    this.value, {
    super.key,
    this.style,
    this.color,
    this.size = 18,
    this.suffix,
  });

  final String value;
  final TextStyle? style;
  final Color? color;
  final double size;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final base = style ?? context.type.number(color ?? tokens.textPrimary, size: size);
    return Text.rich(
      TextSpan(
        text: value,
        children: [
          if (suffix != null)
            TextSpan(
              text: suffix,
              style:
                  context.type.label(base.color ?? tokens.textSecondaryStrong),
            ),
        ],
      ),
      style: base,
    );
  }
}

/// Muted placeholder used instead of an empty or fake chart.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.insights_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return ElaraCard(
      child: Column(
        children: [
          Icon(icon, size: 28, color: tokens.textSecondaryStrong),
          const SizedBox(height: ElaraSpacing.sm),
          Text(title, style: context.type.subtitle(tokens.textPrimary)),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}

/// Centres page content and caps its width.
///
/// A phone-width layout stretched to a tablet or a landscape window reads badly:
/// lines get too long and cards float in space. Screens wrap their list in this,
/// so the content stays a comfortable column and the extra width becomes margin.
class ElaraContentWidth extends StatelessWidget {
  const ElaraContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.isFinite ? maxWidth : double.infinity,
        ),
        child: child,
      ),
    );
  }
}
