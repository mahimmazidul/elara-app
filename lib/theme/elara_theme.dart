import 'package:flutter/material.dart';

/// Elara's design system.
///
/// This file is the ONLY place in the app where a colour literal may appear.
/// Screens and widgets must read colours from [ElaraTokens] via
/// `context.elara` (see the extension at the bottom of this file), so that
/// light and dark modes stay in step and a palette change is a one-file edit.
///
/// Rules encoded here:
///   * flat surfaces, no gradients, no glassmorphism, no neumorphism;
///   * a single shadow, [ElaraShadows.card] (0 1px 3px rgba(0,0,0,0.08));
///   * DM Sans throughout, bundled with the app: weight 400 for secondary copy
///     and captions, 500 for body, 700 for headings. The bundled files carry a
///     real `tnum` feature (see tool/fonts/build_fonts.py), and every numeral
///     asks for it, so values do not jitter as they change.
///
/// Contrast: the tokens marked `*Text` are darkened (light mode) or lightened
/// (dark mode) variants of their decorative counterpart, chosen so that text
/// using them clears WCAG AA 4.5:1 on both card and page surfaces. The values
/// are not eyeballed; the measured ratios are noted next to each group.
class ElaraPalette {
  const ElaraPalette({
    required this.bgPrimary,
    required this.bgCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSecondaryStrong,
    required this.phaseMenstrual,
    required this.phaseFollicular,
    required this.phaseOvulatory,
    required this.phaseLuteal,
    required this.phaseMenstrualText,
    required this.phaseFollicularText,
    required this.phaseOvulatoryText,
    required this.phaseLutealText,
    required this.accent,
    required this.accentText,
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.dangerText,
    required this.moonGlow,
    required this.onPhase,
    required this.divider,
    required this.track,
    required this.unknownPhase,
    required this.unknownPhaseText,
  });

  /// Page background.
  final Color bgPrimary;

  /// Raised surfaces: cards, sheets, chips.
  final Color bgCard;

  /// Primary copy. 12.27:1 on [bgPrimary], 12.50:1 on [bgCard] (light).
  final Color textPrimary;

  /// Secondary copy, as specified (#8B7D7B). Measures 3.69:1 on [bgPrimary],
  /// which is below AA for small text — so it is reserved for text at 16px+ or
  /// medium weight, and for non-essential labels. Use [textSecondaryStrong]
  /// for small captions. Dark mode's value clears AA directly (5.42:1).
  final Color textSecondary;

  /// Small-text-safe secondary copy. 4.54:1 on [bgPrimary], 4.62:1 on [bgCard].
  final Color textSecondaryStrong;

  // Decorative phase colours, used for fills, bars, dots, borders and chips.
  final Color phaseMenstrual;
  final Color phaseFollicular;
  final Color phaseOvulatory;
  final Color phaseLuteal;

  // Text-safe phase colours: same hue, adjusted lightness for AA on surfaces.
  // Light: 4.52-4.61:1 on bgCard. Dark: 4.51-6.73:1.
  final Color phaseMenstrualText;
  final Color phaseFollicularText;
  final Color phaseOvulatoryText;
  final Color phaseLutealText;

  final Color accent;
  final Color accentText;
  final Color success;
  final Color successText;
  final Color warning;
  final Color warningText;
  final Color danger;
  final Color dangerText;

  /// Warm moonlit tint behind the moon/nakshatra strip.
  final Color moonGlow;

  /// Ink drawn on top of a filled phase chip. Light #241C1E clears 5.24-9.13:1
  /// against all four phase fills; dark #1A1416 clears 5.71-9.96:1.
  final Color onPhase;

  /// Hairline separators and chart grid lines.
  final Color divider;

  /// Unfilled portion of a score bar.
  final Color track;

  /// Fallback for an unclassifiable phase.
  final Color unknownPhase;
  final Color unknownPhaseText;

  /// The specified light theme.
  static const ElaraPalette light = ElaraPalette(
    bgPrimary: Color(0xFFFDF6F0),
    bgCard: Color(0xFFFFF8F3),
    textPrimary: Color(0xFF3D2C2E),
    textSecondary: Color(0xFF8B7D7B),
    textSecondaryStrong: Color(0xFF7D6E6D),
    phaseMenstrual: Color(0xFFC97B7B),
    phaseFollicular: Color(0xFF7DB8A5),
    phaseOvulatory: Color(0xFFE8B86D),
    phaseLuteal: Color(0xFF9B8EC4),
    phaseMenstrualText: Color(0xFF9F6263),
    phaseFollicularText: Color(0xFF577A6F),
    phaseOvulatoryText: Color(0xFF896D45),
    phaseLutealText: Color(0xFF776C93),
    accent: Color(0xFFD4956A),
    accentText: Color(0xFF95694D),
    success: Color(0xFF7DB88B),
    successText: Color(0xFF577A5F),
    warning: Color(0xFFD4A96A),
    warningText: Color(0xFF8A6D48),
    danger: Color(0xFFC97B7B),
    dangerText: Color(0xFF9F6263),
    moonGlow: Color(0xFFF5ECD7),
    onPhase: Color(0xFF241C1E),
    divider: Color(0xFFEFE2D8),
    track: Color(0xFFF2E7DE),
    unknownPhase: Color(0xFFB9AEA9),
    unknownPhaseText: Color(0xFF776C68),
  );

  /// Dark theme, derived from the specified surface #2C2426.
  ///
  /// Cards sit 7% lighter than the page so elevation reads without a shadow.
  /// Text clears 10.28:1 (primary) and 5.42:1 (secondary) on cards; phase
  /// colours were lightened only as far as needed to clear 4.5:1.
  static const ElaraPalette dark = ElaraPalette(
    bgPrimary: Color(0xFF2C2426),
    bgCard: Color(0xFF3B3335),
    textPrimary: Color(0xFFF3E9E4),
    textSecondary: Color(0xFFB9A9A5),
    textSecondaryStrong: Color(0xFFC4B5B1),
    phaseMenstrual: Color(0xFFCF8B8B),
    phaseFollicular: Color(0xFF7DB8A5),
    phaseOvulatory: Color(0xFFE8B86D),
    phaseLuteal: Color(0xFFA397C9),
    phaseMenstrualText: Color(0xFFCF8B8B),
    phaseFollicularText: Color(0xFF7DB8A5),
    phaseOvulatoryText: Color(0xFFE8B86D),
    phaseLutealText: Color(0xFFA397C9),
    accent: Color(0xFFD4956A),
    accentText: Color(0xFFD4956A),
    success: Color(0xFF7DB88B),
    successText: Color(0xFF7DB88B),
    warning: Color(0xFFD4A96A),
    warningText: Color(0xFFD4A96A),
    danger: Color(0xFFCF8B8B),
    dangerText: Color(0xFFCF8B8B),
    moonGlow: Color(0xFF4A3E3A),
    onPhase: Color(0xFF1A1416),
    divider: Color(0xFF4A3F41),
    track: Color(0xFF4A3F41),
    unknownPhase: Color(0xFF6B5F5C),
    unknownPhaseText: Color(0xFFB9A9A5),
  );

  /// Returns a copy with the named values replaced.
  ///
  /// Used by [ElaraTheme.paletteFor] to move the accent to the active phase and
  /// tint the two surfaces, without every other colour having to be restated.
  ElaraPalette copyWith({
    Color? bgPrimary,
    Color? bgCard,
    Color? accent,
    Color? accentText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textSecondaryStrong,
    Color? dangerText,
    Color? warningText,
    Color? successText,
  }) {
    return ElaraPalette(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgCard: bgCard ?? this.bgCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textSecondaryStrong: textSecondaryStrong ?? this.textSecondaryStrong,
      phaseMenstrual: phaseMenstrual,
      phaseFollicular: phaseFollicular,
      phaseOvulatory: phaseOvulatory,
      phaseLuteal: phaseLuteal,
      phaseMenstrualText: phaseMenstrualText,
      phaseFollicularText: phaseFollicularText,
      phaseOvulatoryText: phaseOvulatoryText,
      phaseLutealText: phaseLutealText,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      success: success,
      successText: successText ?? this.successText,
      warning: warning,
      warningText: warningText ?? this.warningText,
      danger: danger,
      dangerText: dangerText ?? this.dangerText,
      moonGlow: moonGlow,
      onPhase: onPhase,
      divider: divider,
      track: track,
      unknownPhase: unknownPhase,
      unknownPhaseText: unknownPhaseText,
    );
  }
}

/// Spacing scale, so padding is consistent and reviewable.
class ElaraSpacing {
  const ElaraSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page padding.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);

  /// Standard card interior.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Widest comfortable measure for body copy, in logical pixels.
  ///
  /// Beyond roughly 70 characters a line gets hard to track, so a list on a
  /// tablet or a landscape window keeps this width and turns the rest into
  /// margin instead of stretching.
  static const double readableWidth = 560;

  /// Page padding that centres a [readableWidth] column on wide screens.
  ///
  /// Screens use this instead of a fixed horizontal inset, so one layout works
  /// from a 320px phone to a tablet without a second breakpoint.
  static EdgeInsets pageInsets(
    BuildContext context, {
    double top = lg,
    double bottom = xxl,
  }) {
    final available = MediaQuery.sizeOf(context).width;
    final gutter = available > readableWidth
        ? (available - readableWidth) / 2
        : lg.toDouble();
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
  }
}

/// Corner radii. Kept modest: this is not a soft/rounded style.
class ElaraRadii {
  const ElaraRadii._();

  static const double chip = 8;
  static const double card = 14;
  static const double sheet = 20;
  static const double bar = 6;
}

/// The only shadow in the app: 0 1px 3px rgba(0,0,0,0.08).
class ElaraShadows {
  const ElaraShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000), // 8% black
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  /// No shadow at all. Named so call sites read intentionally.
  static const List<BoxShadow> none = [];
}

/// Text styles, all in the bundled DM Sans: 400 for secondary copy and captions,
/// 500 for body and controls, 700 for headings. The numeral styles ask for the
/// font's `tnum` feature so digits are tabular.
class ElaraTypography {
  const ElaraTypography();

  /// The one family in the app. Bundled as assets, so it renders on a first
  /// launch with no connectivity, and there is no runtime font fetching.
  static const String family = 'DM Sans';

  /// Builds a style in [family] at [weight].
  ///
  /// Weights are restricted to the three the font bundles: 400, 500 and 700.
  /// Asking for anything else would make Flutter synthesise a fake weight, which
  /// looks bolder and blockier than the real thing.
  static TextStyle _style(
    TextStyle base, {
    required FontWeight weight,
    required double size,
    double? height,
    double? letterSpacing,
  }) {
    // DM Sans ships 400/500/700, so anything else has to round to one of them.
    // Semibold rounds up rather than down: a caller asking for 600 wants weight,
    // and rounding it to 500 makes headings and numerals look lighter than
    // intended. Weights below 400 round up to 400 for the same reason.
    final resolved = switch (weight) {
      FontWeight.w600 || FontWeight.w700 || FontWeight.w800 || FontWeight.w900 =>
        FontWeight.w700,
      FontWeight.w500 => FontWeight.w500,
      _ => FontWeight.w400,
    };
    return TextStyle(
      fontFamily: family,
      fontWeight: resolved,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: base.color,
      fontFeatures: base.fontFeatures,
    );
  }

  /// Every numeral in the app goes through this: tabular figures, so a value
  /// that changes in place keeps its width and the layout does not shift.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Big numerals: "20" days, heat index.
  TextStyle displayNumber(Color color, {double size = 56}) => _style(
        TextStyle(color: color, fontFeatures: tabularFigures),
        weight: FontWeight.w700,
        size: size,
        height: 1.05,
      );

  /// Medium numerals: percentages, chart labels, cycle day.
  TextStyle number(Color color, {double size = 18, FontWeight? weight}) =>
      _style(
        TextStyle(color: color, fontFeatures: tabularFigures),
        weight: weight ?? FontWeight.w700,
        size: size,
      );

  TextStyle headline(Color color, {double size = 24}) =>
      _style(TextStyle(color: color), weight: FontWeight.w700, size: size, height: 1.2);

  TextStyle title(Color color, {double size = 18}) =>
      _style(TextStyle(color: color), weight: FontWeight.w700, size: size, height: 1.25);

  TextStyle subtitle(Color color, {double size = 15}) =>
      _style(TextStyle(color: color), weight: FontWeight.w500, size: size);

  TextStyle body(Color color, {double size = 15}) =>
      _style(TextStyle(color: color), weight: FontWeight.w500, size: size, height: 1.45);

  TextStyle bodyStrong(Color color, {double size = 15}) =>
      _style(TextStyle(color: color), weight: FontWeight.w700, size: size, height: 1.4);

  /// Secondary copy: weight 400, per the type scale.
  TextStyle label(Color color, {double size = 13}) =>
      _style(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.3);

  /// Small caption. Uses the AA-safe secondary token by default.
  TextStyle caption(Color color, {double size = 12}) =>
      _style(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.35);

  /// Letter-spaced all-caps eyebrow above a value.
  TextStyle overline(Color color) => _style(
        TextStyle(color: color),
        weight: FontWeight.w500,
        size: 11,
        height: 1.2,
        letterSpacing: 0.8,
      );
}

/// Colours, type and shadows resolved for the active brightness.
///
/// Installed as a [ThemeExtension] on [ThemeData] so every widget reaches the
/// same tokens with `context.elara`, and so Flutter interpolates them during a
/// theme change instead of snapping.
@immutable
class ElaraTokens extends ThemeExtension<ElaraTokens> {
  const ElaraTokens({
    required this.palette,
    required this.typography,
    required this.isDark,
  });

  final ElaraPalette palette;
  final ElaraTypography typography;
  final bool isDark;

  Color get bgPrimary => palette.bgPrimary;
  Color get bgCard => palette.bgCard;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textSecondaryStrong => palette.textSecondaryStrong;
  Color get accent => palette.accent;
  Color get accentText => palette.accentText;
  Color get success => palette.success;
  Color get successText => palette.successText;
  Color get warning => palette.warning;
  Color get warningText => palette.warningText;
  Color get danger => palette.danger;
  Color get dangerText => palette.dangerText;
  Color get moonGlow => palette.moonGlow;
  Color get onPhase => palette.onPhase;
  Color get divider => palette.divider;
  Color get track => palette.track;

  /// Absence of colour, exposed as a token so call sites never reach for
  /// `Colors.transparent` themselves.
  Color get transparent => const Color(0x00000000);

  /// Fill colour for a phase: chips, bars, calendar cells, chart bands.
  Color phaseFill(String phaseKey) {
    switch (phaseKey) {
      case 'menstrual':
        return palette.phaseMenstrual;
      case 'follicular':
        return palette.phaseFollicular;
      case 'ovulatory':
        return palette.phaseOvulatory;
      case 'luteal':
        return palette.phaseLuteal;
      default:
        return palette.unknownPhase;
    }
  }

  /// Text colour for a phase, adjusted to clear AA on card surfaces.
  Color phaseText(String phaseKey) {
    switch (phaseKey) {
      case 'menstrual':
        return palette.phaseMenstrualText;
      case 'follicular':
        return palette.phaseFollicularText;
      case 'ovulatory':
        return palette.phaseOvulatoryText;
      case 'luteal':
        return palette.phaseLutealText;
      default:
        return palette.unknownPhaseText;
    }
  }

  /// A very light wash of a phase colour, for calendar day fills.
  Color phaseWash(String phaseKey, {double opacity = 0.22}) =>
      phaseFill(phaseKey).withValues(alpha: opacity);

  @override
  ElaraTokens copyWith({
    ElaraPalette? palette,
    ElaraTypography? typography,
    bool? isDark,
  }) {
    return ElaraTokens(
      palette: palette ?? this.palette,
      typography: typography ?? this.typography,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ElaraTokens lerp(ThemeExtension<ElaraTokens>? other, double t) {
    if (other is! ElaraTokens) return this;
    // Interpolate each colour so a theme switch cross-fades consistently.
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    final a = palette;
    final b = other.palette;
    return ElaraTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      typography: other.typography,
      palette: ElaraPalette(
        bgPrimary: mix(a.bgPrimary, b.bgPrimary),
        bgCard: mix(a.bgCard, b.bgCard),
        textPrimary: mix(a.textPrimary, b.textPrimary),
        textSecondary: mix(a.textSecondary, b.textSecondary),
        textSecondaryStrong: mix(a.textSecondaryStrong, b.textSecondaryStrong),
        phaseMenstrual: mix(a.phaseMenstrual, b.phaseMenstrual),
        phaseFollicular: mix(a.phaseFollicular, b.phaseFollicular),
        phaseOvulatory: mix(a.phaseOvulatory, b.phaseOvulatory),
        phaseLuteal: mix(a.phaseLuteal, b.phaseLuteal),
        phaseMenstrualText: mix(a.phaseMenstrualText, b.phaseMenstrualText),
        phaseFollicularText:
            mix(a.phaseFollicularText, b.phaseFollicularText),
        phaseOvulatoryText: mix(a.phaseOvulatoryText, b.phaseOvulatoryText),
        phaseLutealText: mix(a.phaseLutealText, b.phaseLutealText),
        accent: mix(a.accent, b.accent),
        accentText: mix(a.accentText, b.accentText),
        success: mix(a.success, b.success),
        successText: mix(a.successText, b.successText),
        warning: mix(a.warning, b.warning),
        warningText: mix(a.warningText, b.warningText),
        danger: mix(a.danger, b.danger),
        dangerText: mix(a.dangerText, b.dangerText),
        moonGlow: mix(a.moonGlow, b.moonGlow),
        onPhase: mix(a.onPhase, b.onPhase),
        divider: mix(a.divider, b.divider),
        track: mix(a.track, b.track),
        unknownPhase: mix(a.unknownPhase, b.unknownPhase),
        unknownPhaseText: mix(a.unknownPhaseText, b.unknownPhaseText),
      ),
    );
  }
}

/// Builds the two [ThemeData]s.
class ElaraTheme {
  const ElaraTheme._();

  static ThemeData light({String? phaseKey}) =>
      _build(ElaraPalette.light, Brightness.light, phaseKey);

  static ThemeData dark({String? phaseKey}) =>
      _build(ElaraPalette.dark, Brightness.dark, phaseKey);

  /// The neutral accent, used whenever no phase can be classified.
  static const String neutralPhaseKey = 'unknown';

  /// How much of the phase colour is mixed into the tinted surfaces.
  ///
  /// 8% is enough to read as "the app is in the ovulatory phase today" without
  /// turning the page into a colour wash, and small enough that the documented
  /// contrast ratios for the text tokens still hold. A test asserts that.
  static const double surfaceTintOpacity = 0.08;

  /// Whether [phaseKey] names one of the four cycle phases.
  static bool isCyclePhase(String? phaseKey) => const {
        'menstrual',
        'follicular',
        'ovulatory',
        'luteal',
      }.contains(phaseKey);

  /// The palette for a phase: the accent follows the phase, the two surface
  /// colours carry an 8% tint of it, and everything else is unchanged.
  ///
  /// Semantic colours (danger, warning, success) are deliberately not touched:
  /// a warning must stay a warning whatever phase it is.
  static ElaraPalette paletteFor(
    ElaraPalette base,
    String? phaseKey,
  ) {
    if (!isCyclePhase(phaseKey)) return base;

    final accent = _phaseFill(base, phaseKey!);
    final surfaceTint = accent.withValues(alpha: surfaceTintOpacity);
    final bgPrimary = Color.alphaBlend(surfaceTint, base.bgPrimary);
    final bgCard = Color.alphaBlend(surfaceTint, base.bgCard);
    final isDark = base.bgPrimary.computeLuminance() < 0.5;

    // Tinting the surfaces moves every ratio a little, and a few of them drop
    // under 4.5:1 (measured: the dark theme's danger ink on an ovulatory card
    // fell to 3.80:1). Rather than ship that, each ink is nudged away from the
    // surface until it clears AA again. The nudge is at most a couple of
    // percent, so nothing changes character.
    Color ink(Color colour, {double minRatio = 4.5, Color? on}) => _ensureContrast(
          colour,
          on ?? bgCard,
          minRatio: minRatio,
          towards: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        );

    return base.copyWith(
      accent: accent,
      // The phase's text-safe variant is the starting point for a phase-coloured
      // label on a card, which is what accentText is for.
      accentText: ink(_phaseText(base, phaseKey)),
      bgPrimary: bgPrimary,
      bgCard: bgCard,
      textPrimary: ink(base.textPrimary, on: bgPrimary),
      textSecondary: ink(base.textSecondary),
      textSecondaryStrong: ink(base.textSecondaryStrong),
      dangerText: ink(base.dangerText),
      warningText: ink(base.warningText),
      successText: ink(base.successText),
    );
  }

  /// Walks [colour] towards [towards] in small steps until it reaches
  /// [minRatio] against [background].
  ///
  /// Deterministic and bounded: at most 60 steps, and it returns the closest it
  /// got rather than looping forever on an impossible pair.
  static Color _ensureContrast(
    Color colour,
    Color background, {
    required double minRatio,
    required Color towards,
  }) {
    var current = colour;
    for (var step = 0; step < 60; step++) {
      if (contrastRatio(current, background) >= minRatio) return current;
      current = Color.alphaBlend(towards.withValues(alpha: 0.03), current);
    }
    return current;
  }

  /// WCAG 2.1 contrast ratio between two opaque colours.
  ///
  /// Exposed so the theme tests can assert the documented ratios instead of
  /// taking the comments on trust.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static Color _phaseFill(ElaraPalette p, String phaseKey) {
    switch (phaseKey) {
      case 'menstrual':
        return p.phaseMenstrual;
      case 'follicular':
        return p.phaseFollicular;
      case 'ovulatory':
        return p.phaseOvulatory;
      case 'luteal':
        return p.phaseLuteal;
      default:
        return p.unknownPhase;
    }
  }

  static Color _phaseText(ElaraPalette p, String phaseKey) {
    switch (phaseKey) {
      case 'menstrual':
        return p.phaseMenstrualText;
      case 'follicular':
        return p.phaseFollicularText;
      case 'ovulatory':
        return p.phaseOvulatoryText;
      case 'luteal':
        return p.phaseLutealText;
      default:
        return p.unknownPhaseText;
    }
  }

  static ThemeData _build(
    ElaraPalette basePalette,
    Brightness brightness,
    String? phaseKey,
  ) {
    final palette = paletteFor(basePalette, phaseKey);
    final tokens = ElaraTokens(
      palette: palette,
      typography: const ElaraTypography(),
      isDark: brightness == Brightness.dark,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.onPhase,
      secondary: palette.phaseLuteal,
      onSecondary: palette.onPhase,
      error: palette.danger,
      onError: palette.onPhase,
      surface: palette.bgCard,
      onSurface: palette.textPrimary,
      // M3 renamed `background`; page colour is carried by the extension and
      // applied by the root scaffold, but this keeps dialogs correct too.
      surfaceContainerHighest: palette.bgCard,
      outline: palette.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Every text style Flutter builds for its own widgets (navigation labels,
      // dialogs, tooltips, snackbars) inherits this. Without it those pieces fell
      // back to the platform font and the app mixed two typefaces.
      fontFamily: ElaraTypography.family,
      scaffoldBackgroundColor: palette.bgPrimary,
      // Flat by design: elevation never draws a Material shadow.
      shadowColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      extensions: [tokens],
      textTheme: TextTheme(
        displayLarge: tokens.typography.displayNumber(palette.textPrimary),
        headlineMedium: tokens.typography.headline(palette.textPrimary),
        titleMedium: tokens.typography.title(palette.textPrimary),
        bodyMedium: tokens.typography.body(palette.textPrimary),
        bodySmall: tokens.typography.caption(palette.textSecondaryStrong),
        labelLarge: tokens.typography.label(palette.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgPrimary,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tokens.typography.headline(palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.bgCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.card),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ElaraRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: tokens.typography.body(palette.bgCard),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.bgCard
              : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.track,
        ),
        trackOutlineColor: WidgetStateProperty.all(palette.divider),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.onPhase
                : palette.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.accent
                : palette.bgCard,
          ),
          side: WidgetStateProperty.all(BorderSide(color: palette.divider)),
          textStyle: WidgetStateProperty.all(
            tokens.typography.label(palette.textPrimary),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentText,
          textStyle: tokens.typography.bodyStrong(palette.accentText),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onPhase,
          elevation: 0,
          textStyle: tokens.typography.bodyStrong(palette.onPhase),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElaraRadii.chip),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ElaraSpacing.xl,
            vertical: ElaraSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentText,
          side: BorderSide(color: palette.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElaraRadii.chip),
          ),
          textStyle: tokens.typography.bodyStrong(palette.accentText),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.track,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.bgCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.moonGlow,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => tokens.typography.caption(
            states.contains(WidgetState.selected)
                ? palette.textPrimary
                : palette.textSecondaryStrong,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? palette.accentText
                : palette.textSecondaryStrong,
          ),
        ),
      ),
    );
  }
}

/// `context.elara` — the only sanctioned way to read a colour.
extension ElaraThemeContext on BuildContext {
  ElaraTokens get elara =>
      Theme.of(this).extension<ElaraTokens>() ??
      const ElaraTokens(
        palette: ElaraPalette.light,
        typography: ElaraTypography(),
        isDark: false,
      );

  ElaraPalette get palette => elara.palette;
  ElaraTypography get type => elara.typography;
}
