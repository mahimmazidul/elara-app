import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
///   * Inter for headings, Source Sans 3 for body, tabular lining figures for
///     every numeral so values do not jitter as they change.
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

/// Text styles. Headings use Inter, body uses Source Sans 3 (both via
/// google_fonts), and [number] variants add tabular lining figures.
///
/// google_fonts fetches and caches fonts on first run, so an offline first
/// launch falls back to the platform font. That is a degradation, not a crash;
/// a later launch with connectivity picks the real faces up. If the app must be
/// fully offline on first run, the TTFs need bundling as assets instead.
class ElaraTypography {
  const ElaraTypography();

  TextStyle _inter(
    TextStyle base, {
    required FontWeight weight,
    required double size,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontWeight: weight,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: base.color,
    );
  }

  TextStyle _sourceSans(
    TextStyle base, {
    required FontWeight weight,
    required double size,
    double? height,
  }) {
    return GoogleFonts.sourceSans3(
      fontWeight: weight,
      fontSize: size,
      height: height,
      color: base.color,
    );
  }

  /// Big numerals: "12" days, "78%", heat index. Inter with tabular lining
  /// figures so digits share a width and do not shift as values update.
  TextStyle displayNumber(Color color, {double size = 56}) => _inter(
        TextStyle(color: color),
        weight: FontWeight.w600,
        size: size,
        height: 1.05,
      ).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Medium numerals: scores, percentages, chart labels.
  TextStyle number(Color color, {double size = 18, FontWeight? weight}) =>
      _inter(TextStyle(color: color), weight: weight ?? FontWeight.w600, size: size)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  TextStyle headline(Color color, {double size = 24}) =>
      _inter(TextStyle(color: color), weight: FontWeight.w600, size: size, height: 1.2);

  TextStyle title(Color color, {double size = 18}) =>
      _inter(TextStyle(color: color), weight: FontWeight.w600, size: size, height: 1.25);

  TextStyle subtitle(Color color, {double size = 15}) =>
      _inter(TextStyle(color: color), weight: FontWeight.w500, size: size);

  TextStyle body(Color color, {double size = 15}) =>
      _sourceSans(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.45);

  TextStyle bodyStrong(Color color, {double size = 15}) =>
      _sourceSans(TextStyle(color: color), weight: FontWeight.w600, size: size, height: 1.45);

  TextStyle label(Color color, {double size = 13}) =>
      _sourceSans(TextStyle(color: color), weight: FontWeight.w500, size: size, height: 1.3);

  /// Small caption. Uses the AA-safe secondary token by default.
  TextStyle caption(Color color, {double size = 12}) =>
      _sourceSans(TextStyle(color: color), weight: FontWeight.w400, size: size, height: 1.35);

  /// Letter-spaced all-caps eyebrow above a value.
  TextStyle overline(Color color) => _sourceSans(
        TextStyle(color: color),
        weight: FontWeight.w600,
        size: 11,
        height: 1.2,
      ).copyWith(letterSpacing: 0.8);
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

  static ThemeData light() => _build(ElaraPalette.light, Brightness.light);
  static ThemeData dark() => _build(ElaraPalette.dark, Brightness.dark);

  static ThemeData _build(ElaraPalette palette, Brightness brightness) {
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
