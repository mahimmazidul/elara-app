import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import 'settings_page.dart';

/// Theme, and what the two palettes actually look like.
///
/// The choice used to be three chips with no preview, which asks someone to
/// remember what "Dark" looks like in an app they are currently looking at. The
/// swatches below show the page colour, the raised surface and the phase accent
/// from each palette, drawn from the same tokens the app uses, so a swatch can
/// never drift from the theme it describes.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const AppearancePage());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final type = context.type;
    final tokens = context.elara;

    return ElaraSettingsPage(
      title: 'Appearance',
      subtitle:
          'System follows the phone\'s own light or dark setting. The palette '
          'is neutral with the phase colour used as an accent, so text stays '
          'readable in both.',
      children: [
        Wrap(
          spacing: ElaraSpacing.sm,
          runSpacing: ElaraSpacing.sm,
          children: [
            for (final (mode, label, icon) in const [
              (ThemeMode.system, 'System', ElaraIcons.themeSystem),
              (ThemeMode.light, 'Light', ElaraIcons.themeLight),
              (ThemeMode.dark, 'Dark', ElaraIcons.themeDark),
            ])
              ChoiceChip(
                avatar: Icon(icon, size: 16),
                label: Text(label),
                selected: settings.themeMode == mode,
                onSelected: (_) => settings.setThemeMode(mode),
              ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.lg),
        Text('Light', style: type.subtitle(tokens.textPrimary, size: 14)),
        const SizedBox(height: ElaraSpacing.xs),
        const _PalettePreview(brightness: Brightness.light),
        const SizedBox(height: ElaraSpacing.lg),
        Text('Dark', style: type.subtitle(tokens.textPrimary, size: 14)),
        const SizedBox(height: ElaraSpacing.xs),
        const _PalettePreview(brightness: Brightness.dark),
      ],
    );
  }
}

/// A strip of the palette: page, raised surface, and the four phase accents.
class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    // The tokens come from a built theme, not from a constructor, so a preview
    // reads exactly what the app will read rather than a second copy of the
    // palette that can drift.
    final theme = brightness == Brightness.dark
        ? ElaraTheme.dark()
        : ElaraTheme.light();
    final palette = theme.extension<ElaraTokens>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ElaraRadii.card),
      child: Container(
        decoration: BoxDecoration(
          color: palette.bgPrimary,
          border: Border.all(color: context.elara.divider),
          borderRadius: BorderRadius.circular(ElaraRadii.card),
        ),
        padding: const EdgeInsets.all(ElaraSpacing.md),
        child: Row(
          children: [
            _Swatch(colour: palette.bgPrimary, label: 'Page', ring: true),
            const SizedBox(width: ElaraSpacing.sm),
            _Swatch(colour: palette.bgCard, label: 'Card', ring: true),
            const SizedBox(width: ElaraSpacing.md),
            for (final key in const ['menstrual', 'follicular', 'ovulatory', 'luteal'])
              Padding(
                padding: const EdgeInsets.only(right: ElaraSpacing.xs),
                child: _Swatch(colour: palette.phaseFill(key)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour, this.label, this.ring = false});

  final Color colour;
  final String? label;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: ring ? Border.all(color: tokens.divider) : null,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: context.type.caption(tokens.textSecondaryStrong, size: 11),
          ),
        ],
      ],
    );
  }
}
