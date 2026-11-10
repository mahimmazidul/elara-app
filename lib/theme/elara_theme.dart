import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///   * Hind Siliguri throughout, bundled with the app: weight 400 for
///     secondary copy and captions, 500 for body, 600 for emphasis, 700 for
///     headings. One family draws both the Latin and the Bengali. The bundled
///     files carry a real `tnum` feature (see
///     tool/fonts/build_hind_siliguri.py), and every numeral asks for it, so
///     values do not jitter as they change.
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

  /// The light theme.
  ///
  /// The page is cool slate-blue-grey and the surface is pure white, so the
  /// two read as one continuous sheet rather than a stack of boxes. The ink is
  /// deep slate navy. Every phase fill is cool -- dusty mauve, soft teal, cool
  /// periwinkle, deep indigo -- never warm cream, yellow-heavy, brown, muddy or
  /// excessively pink.
  ///
  /// Contrast, measured against both the page and the surface: primary
  /// clears 13:1, secondary-strong clears 5:1, and every phase-text variant
  /// clears 4.5:1. The four phase fills themselves are never used as text on
  /// light; they are fills, and their text-safe variants sit beside them.
  static const ElaraPalette light = ElaraPalette(
    bgPrimary: Color(0xFFE8EEF6),
    bgCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A2E4A),
    textSecondary: Color(0xFF5A708C),
    textSecondaryStrong: Color(0xFF3E5A7A),
    phaseMenstrual: Color(0xFF9E7CB0),
    phaseFollicular: Color(0xFF7FB3B8),
    phaseOvulatory: Color(0xFF8B9AE8),
    phaseLuteal: Color(0xFF6E7BB8),
    phaseMenstrualText: Color(0xFF7A5A90),
    phaseFollicularText: Color(0xFF4A7A85),
    phaseOvulatoryText: Color(0xFF5A6AC0),
    phaseLutealText: Color(0xFF4A5AA0),
    accent: Color(0xFF9AA8E8),
    accentText: Color(0xFF263450),
    success: Color(0xFF6FA88C),
    successText: Color(0xFF3E6E56),
    warning: Color(0xFFB88FA8),
    warningText: Color(0xFF7A5A7E),
    danger: Color(0xFFB07CA0),
    dangerText: Color(0xFF7A5A7E),
    moonGlow: Color(0xFFF0F3F8),
    onPhase: Color(0xFF1A2E4A),
    divider: Color(0xFFD8E0EA),
    track: Color(0xFFE4ECF4),
    unknownPhase: Color(0xFF8A93A3),
    unknownPhaseText: Color(0xFF5A6677),
  );

  /// The dark theme.
  ///
  /// Page deep midnight slate, surface one step lighter, so the surface reads
  /// as a slightly raised sheet without a shadow. The ink is cool light grey.
  /// The phase fills keep the same four cool hues as the light theme, each
  /// with a lighter variant for text, because a fill that reads well as a
  /// block is too dark to read as a word.
  static const ElaraPalette dark = ElaraPalette(
    bgPrimary: Color(0xFF12161E),
    bgCard: Color(0xFF1C232E),
    textPrimary: Color(0xFFE8EEF6),
    textSecondary: Color(0xFF7E90A8),
    textSecondaryStrong: Color(0xFFA8B8C8),
    phaseMenstrual: Color(0xFF9E7CB0),
    phaseFollicular: Color(0xFF7FB3B8),
    phaseOvulatory: Color(0xFF8B9AE8),
    phaseLuteal: Color(0xFF6E7BB8),
    phaseMenstrualText: Color(0xFFB399CD),
    phaseFollicularText: Color(0xFF8FC9CE),
    phaseOvulatoryText: Color(0xFFABB2F2),
    phaseLutealText: Color(0xFF8E9BCC),
    accent: Color(0xFF2A4A7D),
    accentText: Color(0xFFE8EEF6),
    success: Color(0xFF6FA88C),
    successText: Color(0xFF7FB89E),
    warning: Color(0xFFB88FA8),
    warningText: Color(0xFFC89FB8),
    danger: Color(0xFFB07CA0),
    dangerText: Color(0xFFC08CB0),
    moonGlow: Color(0xFF1E2530),
    onPhase: Color(0xFF1A1416),
    divider: Color(0xFF2E3844),
    track: Color(0xFF26303C),
    unknownPhase: Color(0xFF8A93A3),
    unknownPhaseText: Color(0xFF9FB0C4),
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

  /// Height of the Material 3 [NavigationBar] at the bottom of a narrow window.
  ///
  /// Used to reserve space at the end of a scrolling page: the Scaffold body is
  /// laid out above the bar, but the last row of content was still ending level
  /// with the bar's top edge, so the final control on Settings sat half-hidden
  /// behind it. `kBottomNavigationBarHeight` (56) is the pre-M3 value and is too
  /// small for a labelled NavigationBar.
  static const double navigationBarHeight = 80;

  /// Page padding that centres a [readableWidth] column on wide screens.
  ///
  /// Screens use this instead of a fixed horizontal inset, so one layout works
  /// from a 320px phone to a tablet without a second breakpoint.
  /// Standard page padding: a centred readable column on wide screens, and
  /// enough space at the bottom that the last line clears the navigation bar.
  ///
  /// The [bottom] value used to be a flat 32, which let the final paragraph of
  /// Today slide under the bottom navigation bar and be clipped mid-sentence. It
  /// now clears the bar's own height as well.
  static EdgeInsets pageInsets(
    BuildContext context, {
    double top = lg,
    double bottom = xxl,
  }) {
    final media = MediaQuery.of(context);
    // The bar sits inside the Scaffold body inset, so its height is not part of
    // the safe area the screen already receives.
    final barHeight = media.size.width >= 720
        ? 0.0
        : navigationBarHeight + media.padding.bottom;
    final available = media.size.width;
    final gutter = available > readableWidth
        ? (available - readableWidth) / 2
        : lg.toDouble();
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom + barHeight);
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

/// Text styles, all in the bundled Hind Siliguri: 400 for secondary copy and
/// captions, 500 for body and controls, 600 for emphasis, 700 for headings.
/// The numeral styles ask for the font's `tnum` feature so digits are
/// tabular.
class ElaraTypography {
  const ElaraTypography();

  /// The one family in the app. Bundled as assets, so it renders on a first
  /// launch with no connectivity, and there is no runtime font fetching.
  ///
  /// Hind Siliguri draws both scripts, so there is no fallback and no seam
  /// where the Bengali meets the English.
  static const String family = 'Hind Siliguri';

  /// The fallback family.
  ///
  /// Hind Siliguri carries the Latin, the Bengali and the punctuation the app
  /// prints, so nothing falls back to another typeface in normal use. The
  /// list is empty rather than absent so that a style without a fallback says
  /// so explicitly.
  static const List<String> banglaFamily = <String>[];

  /// The family actually used, and the fallbacks that follow it.
  ///
  /// These are variables rather than constants so that
  /// tool/fonts/font_comparison_test.dart can render the real screens in a
  /// candidate family and have it compared against the current one, with
  /// identical content. They are set only by that harness; the app always
  /// uses [family] and [banglaFamily].
  static String get activeFamily => _activeFamily ?? family;
  static List<String> get activeFallbacks =>
      _activeFallbacks ?? banglaFamily;
  static String? _activeFamily;
  static List<String>? _activeFallbacks;

  /// Swaps the family for the duration of a comparison run.
  ///
  /// Not for use in the app. It exists so that
  /// tool/screenshots/screenshots_test.dart can render the real screens in a
  /// candidate family and have them compared against the current one.
  static void overrideFamily(String family, {List<String> fallbacks = const []}) {
    _activeFamily = family;
    _activeFallbacks = fallbacks;
  }

  /// Restores the app's own family.
  static void resetFamily() {
    _activeFamily = null;
    _activeFallbacks = null;
  }

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
    // Hind Siliguri ships 400/500/600/700, so those four are used exactly.
    // Anything else rounds to the nearest one that exists, because asking
    // for a weight the font does not carry makes Flutter synthesise a fake
    // one, which looks bolder and blockier than the real thing.
    final resolved = switch (weight) {
      FontWeight.w700 || FontWeight.w800 || FontWeight.w900 =>
        FontWeight.w700,
      FontWeight.w600 => FontWeight.w600,
      FontWeight.w500 => FontWeight.w500,
      // Below 400 rounds up rather than down: a caller asking for a light
      // face wants it lighter than regular, not regular.
      _ => FontWeight.w400,
    };
    return TextStyle(
      fontFamily: activeFamily,
      // One family draws both scripts, so there is no fallback in normal use.
      // It is still declared per style rather than per widget, so that a
      // character the family happens not to carry resolves through a family
      // that does, instead of rendering as a row of tofu boxes.
      fontFamilyFallback: activeFallbacks,
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
      _style(TextStyle(color: color), weight: FontWeight.w500, size: size, height: 1.35);

  /// Primary body copy. 1.5 line height: long paragraphs of guidance are the
  /// main reading on the Today screen, and Hind Siliguri at 15pt sits tightly
  /// at the default height.
  TextStyle body(Color color, {double size = 15}) =>
      _style(TextStyle(color: color), weight: FontWeight.w500, size: size, height: 1.5);

  TextStyle bodyStrong(Color color, {double size = 15}) =>
      _style(TextStyle(color: color), weight: FontWeight.w700, size: size, height: 1.45);

  /// Secondary copy: weight 400, per the type scale.
  TextStyle label(Color color, {double size = 13}) =>
      _style(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.4);

  /// Small caption. Uses the AA-safe secondary token by default.
  TextStyle caption(Color color, {double size = 12}) =>
      _style(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.4);

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
    final isDark = base.bgPrimary.computeLuminance() < 0.5;

    Color ink(Color colour, {double minRatio = 4.5, Color? on}) => _ensureContrast(
          colour,
          on ?? base.bgCard,
          minRatio: minRatio,
          towards: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        );

    // The page and the surface stay exactly as declared. A phase wash belongs
    // on a designated surface — the care card, the phase chip — not across the
    // whole app, where an amber week would turn every screen cream and the
    // colour would stop meaning anything. Widgets ask for the wash explicitly
    // through [ElaraTokens.phaseWash].
    return base.copyWith(
      accent: accent,
      // The phase's text-safe variant is the starting point for a phase-coloured
      // label, which is what accentText is for.
      accentText: ink(_phaseText(base, phaseKey)),
      textPrimary: ink(base.textPrimary),
      textSecondary: ink(base.textSecondary),
      textSecondaryStrong: ink(base.textSecondaryStrong),
      dangerText: ink(base.dangerText),
      warningText: ink(base.warningText),
      successText: ink(base.successText),
    );
  }

  /// Nudges [colour] away from [background] until it reaches [minRatio].
  ///
  /// A phase accent or a tinted surface moves every contrast ratio a little, and
  /// a few land just under AA — measured, the dark theme's danger ink on a tinted
  /// card fell to 3.80:1. Rather than ship that or hand-tune each combination,
  /// the ink is blended towards white or black in small steps until it clears
  /// the ratio. The change is at most a few percent, so the colour keeps its
  /// character; the guarantee is what the tests assert.
  static Color _ensureContrast(
    Color colour,
    Color background, {
    required double minRatio,
    required Color towards,
  }) {
    if (contrastRatio(colour, background) >= minRatio) return colour;

    var candidate = colour;
    // 20 steps of 3% reaches a 45% blend, which is always enough to clear AA
    // from any starting point. The loop is bounded so a pathological input can
    // never hang a build.
    for (var step = 0; step < 20; step++) {
      candidate = Color.alphaBlend(towards.withValues(alpha: 0.03), candidate);
      if (contrastRatio(candidate, background) >= minRatio) return candidate;
    }
    // Fall back to the extreme rather than returning something that fails.
    return towards;
  }

  /// WCAG 2.1 contrast ratio between two opaque colours, 1.0 to 21.0.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
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
      fontFamily: ElaraTypography.activeFamily,
      fontFamilyFallback: ElaraTypography.activeFallbacks,
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
      // Choice and filter chips are the app's only "pick one" control, used for
      // the theme switch and the preference category. Material's default selects
      // them with `secondary`, which here is the luteal purple — a phase colour
      // on an action that has nothing to do with the cycle. Selected chips take
      // the neutral raised tint instead, with the accent kept for the border.
      chipTheme: ChipThemeData(
        backgroundColor: palette.bgCard,
        selectedColor: palette.moonGlow,
        checkmarkColor: palette.textPrimary,
        side: BorderSide(color: palette.divider),
        labelStyle: tokens.typography.label(palette.textPrimary),
        secondaryLabelStyle: tokens.typography.label(palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgPrimary,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tokens.typography.headline(palette.textPrimary),
        // The app draws edge to edge, so the status bar sits over the page
        // rather than over a separate strip. The icons have to be drawn in
        // the colour that is legible on *this* background: dark icons on the
        // light page, light icons on the dark one. Without this the system
        // keeps whatever brightness the window was created with, which is
        // dark icons by default and invisible on a dark theme.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              brightness == Brightness.dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
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
 
