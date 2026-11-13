import 'package:elara_core/elara_core.dart' as core;
import 'package:material_ui/material_ui.dart';

import '../../data/models/climate_snapshot.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/icons.dart';

/// Season name for display, from elara-core's four Bangladesh seasons.
String seasonLabel(core.Season season) {
  switch (season) {
    case core.Season.winter:
      return 'Winter';
    case core.Season.preMonsoon:
      return 'Pre-monsoon';
    case core.Season.monsoon:
      return 'Monsoon';
    case core.Season.postMonsoon:
      return 'Post-monsoon';
  }
}

/// Heat index, PM2.5 and season for the current day.
///
/// The heat index is drawn in the current phase colour once it passes 38 °C,
/// the threshold at which elara-core starts raising the environmental severity.
/// Values that came from the seasonal table rather than a live reading are
/// labelled "estimated" — the app should not present a seasonal average as a
/// measurement.
class ClimateStrip extends StatelessWidget {
  const ClimateStrip({
    super.key,
    required this.snapshot,
    required this.phaseKey,
  });

  final ClimateSnapshot snapshot;
  final String phaseKey;

  static const double heatIndexAlertThreshold = 38;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final isHot = snapshot.heatIndex > heatIndexAlertThreshold;
    final heatColor =
        isHot ? tokens.phaseText(phaseKey) : tokens.textPrimary;
    final season = seasonLabel(ClimateSnapshot.seasonFor(snapshot.date));

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: ElaraOverline('Today\u2019s climate')),
              if (snapshot.isFallback)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ElaraSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.bgPrimary,
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    border: Border.all(color: tokens.divider),
                  ),
                  child: Text(
                    'estimated',
                    style: type.caption(tokens.textSecondaryStrong, size: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.md),
          // Two measured figures side by side; the season is a word, and giving
          // it a third narrow column forced "Post-monsoon" to break after its
          // hyphen. It reads as a caption under the numbers instead.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(
                label: 'Heat index',
                value: snapshot.heatIndex.toStringAsFixed(0),
                unit: '°C',
                valueColor: heatColor,
                trailing: isHot
                    ? Icon(ElaraIcons.heat, size: 16, color: heatColor)
                    : null,
              ),
              _Divider(color: tokens.divider),
              _Metric(
                label: 'PM2.5',
                value: snapshot.pm25.toStringAsFixed(0),
                unit: 'µg/m³',
                valueColor: tokens.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            '$season season',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: ElaraSpacing.md),
      color: color,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
    this.unit,
    this.trailing,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? unit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: context.type.caption(tokens.textSecondaryStrong),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: ElaraSpacing.xs),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: ElaraSpacing.xs),
          // Season is a word, not a figure, so it uses the title style.
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: context.type.caption(tokens.textSecondaryStrong),
                  ),
              ],
            ),
            style: unit == null
                // Word values ("Post-monsoon") get a line to themselves; a
                // single line at 15pt ellipsised the longest season name.
                ? context.type.subtitle(valueColor, size: 14)
                : context.type
                    .number(valueColor, size: 20)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            maxLines: unit == null ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
