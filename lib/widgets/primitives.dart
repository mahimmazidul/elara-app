import 'package:material_ui/material_ui.dart';

import '../theme/elara_theme.dart';
import 'icons.dart';
import 'motion.dart';

/// A surface for content that genuinely belongs together.
///
/// Flat by default, and unbordered: the app's default texture is a neutral page
/// with surfaces that differ from it only by tone. A screen made of twelve
/// shadowed boxes at the same weight has no hierarchy at all, so the shadow is
/// opt-in through [elevated] and is used at most once on a screen, on the thing
/// that matters most.
///
/// For grouping that does not need a surface at all, use [ElaraSection] or a
/// [Hairline] instead. Most content in this app should not be in a card.
class ElaraCard extends StatelessWidget {
  const ElaraCard({
    super.key,
    required this.child,
    this.padding = ElaraSpacing.card,
    this.color,
    this.borderColor,
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// The one allowed shadow. Use sparingly: at most one per screen.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.bgCard,
        borderRadius: BorderRadius.circular(ElaraRadii.card),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: elevated ? ElaraShadows.card : ElaraShadows.none,
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

/// A glass panel: the settings-and-secondary-page surface.
///
/// What makes this read as glass rather than as a card is four things working
/// together, and none of them is a box.
///
/// The panel has **no outline**. A hairline border draws a rectangle, and a
/// rectangle is the thing being got rid of. Its edge is defined by a *sheen*
/// instead: a faint light stroke that is strong at the top-left and fades out
/// before the bottom-right, which is how a real edge catches a light source.
///
/// It sits **on the page rather than in it**. A slight vertical gradient from
/// the card tone to a half-step lighter leaves the top of the panel feeling
/// nearer than the bottom, which is the whole of the depth illusion.
///
/// The fill is **translucent**, so the page behind it is present but not
/// readable through it. This is deliberately not a blur: `BackdropFilter` is the
/// obvious way to make glass in Flutter and it is the wrong one here — it costs
/// a save-layer on every scroll frame, and on the mid-range Android hardware
/// most of these users are holding it is the difference between a smooth list
/// and a stuttering one. Tinting gets the same impression for free.
///
/// And the **interior is inset**: content that floats inside a glass panel has
/// to leave the panel's edge alone, or the illusion collapses into a box again.
///
/// Used on settings and secondary pages. Not on Today, where surfaces have to
/// recede behind the phase dial.
class ElaraGlass extends StatelessWidget {
  const ElaraGlass({
    super.key,
    required this.child,
    this.padding = ElaraSpacing.card,
    this.radius,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;

  /// Override for the panel fill, e.g. a phase wash. Defaults to the card tone.
  final Color? tint;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final r = radius ?? ElaraRadii.glass;

    // Dark mode is flat, and this is the whole of that decision.
    //
    // The pane below is built to imitate glass: a vertical sheen, a pale lip of
    // light along the top, a darker rim underneath, and a wide soft shadow to
    // fall away into. In light it earns all of it, because the page is the
    // darker of the two tones and the panel genuinely looks lit. In dark the
    // panel is *lighter* than the page, so the same treatment has nothing to
    // refract and reads as a rendered object rather than a surface - the report
    // was "dark mode looks ai glassy", which is exactly right.
    //
    // In a dark room a panel is separated by its edge. So dark gets a flat fill,
    // one hairline, and no shadow at all.
    if (tokens.isDark) {
      final flat = DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: tokens.divider),
        ),
        child: Padding(padding: padding, child: child),
      );
      if (onTap == null) return flat;
      return ElaraPressable(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          child: flat,
        ),
      );
    }
    // In light, the page is the darker of the two tones and the panel catches
    // the light. In dark the relationship inverts: the panel is the lighter
    // one, and the sheen stays pale so the edge still reads.
    final base = tint ?? tokens.glassBase;

    // In dark the panel is not "the card tone, lighter": a near-black pane with
    // a white stroke reads as etched plastic, which is what made the first
    // version look generated rather than designed. Real glass in a dark room
    // shows almost nothing at the edge and everything in the falloff, so the
    // dark panel gets a smaller highlight, a *deeper* fill than the page is
    // not possible without losing the shape — instead it stays a shade above
    // the page and buys its separation from a wide, very soft shadow below.
    final top = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.06),
      base,
    );
    final bottom = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.03),
      base,
    );

    // The rim is two lines doing different jobs: a pale one where the light
    // lands, a darker one underneath where the pane shades the page. In light
    // it goes round the whole pane; in dark only the top lip catches anything,
    // and a stroke all the way round is the tell of a fake.
    //
    // They are drawn as two 1px lines inside a clipped panel rather than as a
    // `Border`, because a border cannot hold two colours and a rounded corner at
    // the same time — Flutter rejects it, and the first version of this widget
    // failed its own tests for exactly that reason.
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: ElaraShadows.glass,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
            border: Border.all(color: tokens.glassSheen, width: 1),
          ),
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: IgnorePointer(
                  child: ColoredBox(color: tokens.glassTopEdge),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 1,
                child: IgnorePointer(child: ColoredBox(color: tokens.glassRim)),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return panel;
    return ElaraPressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: panel,
      ),
    );
  }
}

/// A group of rows inside one glass panel, with hairlines between them.
///
/// Rows in a settings list used to be separate full-width blocks, each with its
/// own gutters. Treated as one panel with dividers, the list reads as a single
/// object — which is what it is: one set of related choices.
class ElaraGlassGroup extends StatelessWidget {
  const ElaraGlassGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    const rowInset = EdgeInsets.symmetric(horizontal: ElaraSpacing.lg);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: rowInset,
            child: Divider(height: 1, thickness: 1, color: tokens.divider),
          ),
        );
      }
      rows.add(Padding(padding: rowInset, child: children[i]));
    }

    return ElaraGlass(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
      child: Column(children: rows),
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

/// The one saturated panel on a screen.
///
/// Every other surface in Elara is paper: a page, a card a shade off it, rows
/// separated by hairlines. That is a good system for reading and a bad one for
/// finding, because with nothing saturated on the page the eye has no anchor and
/// the screen reads as a form. This is the anchor: one panel per screen, filled
/// with the phase's deep colour, carrying cream ink and the one thing the screen
/// is about.
///
/// It is deliberately not a card with a tinted background. The fill comes from
/// [ElaraTokens.heroFill], which is a value down from the decorative phase
/// colour, because a panel this size in the decorative tone reads as a wash and
/// cannot hold white text without it going grey.
class ElaraHeroCard extends StatelessWidget {
  const ElaraHeroCard({
    super.key,
    required this.phaseKey,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      ElaraSpacing.lg,
      ElaraSpacing.lg,
      ElaraSpacing.lg,
      ElaraSpacing.lg,
    ),
  });

  /// Which phase's colour to fill with. An unclassified day falls back to ink,
  /// which keeps the panel honest: there is no colour for a day nobody knows.
  final String phaseKey;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.heroFill(phaseKey),
        borderRadius: BorderRadius.circular(ElaraRadii.hero),
      ),
      child: child,
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
    final base =
        style ?? context.type.number(color ?? tokens.textPrimary, size: size);
    return Text.rich(
      TextSpan(
        text: value,
        children: [
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: context.type.label(
                base.color ?? tokens.textSecondaryStrong,
              ),
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
    this.icon = ElaraIcons.insights,
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

/// A titled group with no box around it.
///
/// This is the app's default way of grouping content. A heading, its children,
/// and a hairline is enough to read as one section, and it costs no border, no
/// fill and no shadow — so a screen can have six of them without looking like a
/// dashboard.
class ElaraSection extends StatelessWidget {
  const ElaraSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
    this.padding,
    this.separator = true,
  });

  final String title;
  final List<Widget> children;

  /// Optional leading glyph from [ElaraIcons].
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  /// Whether to draw a hairline above subsequent [ElaraSection]s in a list.
  final bool separator;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: ElaraIcons.size,
                  color: tokens.textSecondaryStrong,
                ),
                const SizedBox(width: ElaraSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: type.title(tokens.textPrimary, size: 17),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: ElaraSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// A one-pixel separator, with the vertical rhythm baked in.
///
/// Used instead of cards and borders to divide content. The generous default
/// margin is what makes the app feel unhurried without adding empty surfaces.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.margin = ElaraSpacing.xl});

  final double margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: margin),
      color: context.elara.divider,
    );
  }
}

/// Icon, label and value on one line, with no box.
///
/// The workhorse of the Today screen: climate, moon, countdown detail and cycle
/// facts all use this rather than a card each, which is what removes most of the
/// visual clutter.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailingIcon,
    this.valueColor,
    this.numeric = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? valueColor;

  /// Renders the value with tabular figures.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final colour = valueColor ?? tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: ElaraIcons.size,
                color: tokens.textSecondaryStrong,
              ),
            ),
            const SizedBox(width: ElaraSpacing.md),
          ],
          Expanded(
            child: Text(label, style: type.body(tokens.textSecondaryStrong)),
          ),
          const SizedBox(width: ElaraSpacing.md),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingIcon != null) ...[
                  Icon(
                    trailingIcon,
                    size: 15,
                    color: valueColor ?? tokens.textSecondaryStrong,
                  ),
                  const SizedBox(width: ElaraSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: numeric
                        ? type.number(colour, size: 15)
                        : type.subtitle(colour, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row: icon, title, optional subtitle, optional trailing text.
///
/// Used for Settings and About, where a list of plain rows reads far calmer than
/// a stack of cards.
class ElaraListRow extends StatelessWidget {
  const ElaraListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final titleColour = destructive ? tokens.dangerText : tokens.textPrimary;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: ElaraIcons.rowSize,
                color: destructive
                    ? tokens.dangerText
                    : tokens.textSecondaryStrong,
              ),
            ),
            const SizedBox(width: ElaraSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: type.subtitle(titleColour, size: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: ElaraSpacing.md),
            Text(trailingText!, style: type.label(tokens.textSecondaryStrong)),
          ],
          if (trailing != null) ...[
            const SizedBox(width: ElaraSpacing.sm),
            trailing!,
          ],
          if (onTap != null && trailing == null && trailingText == null)
            Padding(
              padding: const EdgeInsets.only(left: ElaraSpacing.xs),
              child: Icon(
                ElaraIcons.disclosure,
                size: 18,
                color: tokens.textSecondaryStrong,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    // The pressable gives the small scale-down that says "this is a thing you
    // can press" while the finger is still on it. The InkWell inside it
    // gives the ripple that shows where the touch landed; the tap itself is
    // handled once, by the InkWell, so the gesture is not fired twice.
    //
    // The scale is skipped when the platform has asked for animations to be
    // removed, but the ripple is not: a ripple is not motion.
    return ElaraPressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ElaraRadii.chip),
        child: row,
      ),
    );
  }
}

/// A short label naming where a piece of information came from.
///
/// The distinction this draws is the point of the whole care system: something
/// she told you is not the same as something the calendar implies, and a
/// suggestion has to say which it is.
class BasisTag extends StatelessWidget {
  const BasisTag({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final tint = color ?? tokens.textSecondaryStrong;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: ElaraSpacing.xs),
        ],
        Flexible(
          child: Text(label, style: context.type.caption(tint, size: 12)),
        ),
      ],
    );
  }
}
