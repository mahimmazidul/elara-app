import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/icons.dart';

/// Chart 1: cycle length history as a line.
///
/// Shows the last [maxPoints] completed cycle lengths with the mean as a dashed
/// reference line, so a single outlier reads as an outlier rather than as the
/// average. Grid lines are the only chrome; there is no fill or gradient.
class CycleLengthChart extends StatelessWidget {
  const CycleLengthChart({
    super.key,
    required this.lengths,
    this.maxPoints = 12,
  });

  final List<int> lengths;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    if (lengths.length < 2) {
      return const EmptyState(
        icon: ElaraIcons.trend,
        title: 'Not enough cycles yet',
        message:
            'Two completed cycles are needed before a trend means '
            'anything.',
      );
    }

    final shown = lengths.length > maxPoints
        ? lengths.sublist(lengths.length - maxPoints)
        : lengths;

    final minValue = shown.reduce(math.min).toDouble();
    final maxValue = shown.reduce(math.max).toDouble();
    final mean = shown.reduce((a, b) => a + b) / shown.length;

    // Pad the axis by a day either side so points never touch the frame.
    final minY = (minValue - 2).floorToDouble();
    final maxY = (maxValue + 2).ceilToDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < shown.length; i++)
        FlSpot(i.toDouble(), shown[i].toDouble()),
    ];

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: ElaraOverline('Cycle length history')),
              NumberText(
                '${shown.length}',
                size: 13,
                color: tokens.textSecondaryStrong,
                suffix: ' cycles',
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.lg),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (shown.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: tokens.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: type.number(
                          tokens.textSecondaryStrong,
                          size: 11,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        // fl_chart also asks for titles at fractional
                        // positions, which printed duplicate day numbers.
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        final index = value.round();
                        if (index < 0 || index >= shown.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${index + 1}',
                            style: type.number(
                              tokens.textSecondaryStrong,
                              size: 11,
                              weight: FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: mean,
                      color: tokens.textSecondaryStrong,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: type.number(
                          tokens.textSecondaryStrong,
                          size: 10,
                          weight: FontWeight.w400,
                        ),
                        labelResolver: (_) => 'avg ${mean.toStringAsFixed(1)}',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => tokens.textPrimary,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${spot.y.toInt()} days',
                          type.number(tokens.bgCard, size: 12),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: tokens.phaseFill('luteal'),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: tokens.phaseFill('luteal'),
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Left to right, oldest to most recent.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}

/// Chart 2: mean cycle length with one standard deviation either side.
///
/// The bar is the mean; the whisker spans mean − SD to mean + SD, with caps.
/// Drawn with fl_chart line segments at a single x position so it participates
/// in the same charting library as the others. The SD is the sample standard
/// deviation (n − 1), matching how drip reports cycle variability.
class MeanSdChart extends StatelessWidget {
  const MeanSdChart({
    super.key,
    required this.mean,
    required this.standardDeviation,
    required this.sampleCount,
  });

  final double mean;
  final double standardDeviation;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    if (sampleCount < 2) {
      return const EmptyState(
        icon: ElaraIcons.measure,
        title: 'No spread to show',
        message: 'Standard deviation needs at least two completed cycles.',
      );
    }

    final low = (mean - standardDeviation).clamp(1.0, 99.0);
    final high = (mean + standardDeviation).clamp(1.0, 99.0);
    final minY = (low - 4).floorToDouble();
    final maxY = (high + 4).ceilToDouble();
    const capHalfWidth = 0.18;

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: ElaraOverline('Average length')),
              NumberText(mean.toStringAsFixed(1), size: 16, suffix: ' days'),
            ],
          ),
          const SizedBox(height: ElaraSpacing.lg),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minX: -0.6,
                maxX: 0.6,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: tokens.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 2,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: type.number(
                          tokens.textSecondaryStrong,
                          size: 11,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: mean,
                      color: tokens.divider,
                      strokeWidth: 1,
                      dashArray: const [3, 3],
                    ),
                  ],
                ),
                lineBarsData: [
                  // The bar: a thick vertical segment from the axis floor to the
                  // mean, using the phase-neutral accent.
                  LineChartBarData(
                    spots: [FlSpot(0, minY), FlSpot(0, mean)],
                    isCurved: false,
                    color: tokens.accent,
                    barWidth: 14,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // The whisker: mean - SD up to mean + SD.
                  LineChartBarData(
                    spots: [FlSpot(0, low), FlSpot(0, high)],
                    isCurved: false,
                    color: tokens.textPrimary,
                    barWidth: 1.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 2,
                            color: tokens.textPrimary,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Lower cap.
                  LineChartBarData(
                    spots: [
                      FlSpot(-capHalfWidth, low),
                      FlSpot(capHalfWidth, low),
                    ],
                    isCurved: false,
                    color: tokens.textPrimary,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Upper cap.
                  LineChartBarData(
                    spots: [
                      FlSpot(-capHalfWidth, high),
                      FlSpot(capHalfWidth, high),
                    ],
                    isCurved: false,
                    color: tokens.textPrimary,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            '±${standardDeviation.toStringAsFixed(1)} days '
            '(1 SD, n = $sampleCount). '
            '${_spreadNote(standardDeviation)}',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }

  /// Honest framing of what a given spread implies to the user.
  static String _spreadNote(double sd) {
    if (sd < 1.5) {
      return 'A steady cycle; the estimate should land close.';
    }
    if (sd < 3.5) {
      return 'Ordinary variation; expect the estimate to move by a few days.';
    }
    return 'Wide variation, so treat a single date as a rough guide.';
  }
}

/// Chart 3: heat index over recent days with predicted phase bands behind it.
///
/// The bands come from the same [PhaseTimeline] the calendar uses, so both
/// screens agree. The 38 °C line marks where elara-core begins to raise the
/// environmental severity.
class HeatIndexChart extends StatelessWidget {
  const HeatIndexChart({super.key, required this.points, required this.bands});

  /// One entry per day that has a cached reading, oldest first.
  final List<({DateTime date, double heatIndex})> points;

  /// Phase runs aligned to the same date range as [points].
  final List<({int startIndex, int endIndex, String phaseKey})> bands;

  static const double alertThreshold = 38;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    if (points.length < 2) {
      return const EmptyState(
        icon: ElaraIcons.heat,
        title: 'No climate history yet',
        message:
            'Heat index is recorded as the app is used each day. '
            'Come back after a few days.',
      );
    }

    final values = points.map((p) => p.heatIndex).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final minY = (minValue - 2).floorToDouble();
    final maxY = (maxValue + 3).ceilToDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].heatIndex),
    ];

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: ElaraOverline('Heat index, recent days')),
              NumberText(
                '${points.length}',
                size: 13,
                color: tokens.textSecondaryStrong,
                suffix: ' days',
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.lg),
          // The plot is inset by half a slot at each end and clipped by the
          // card's own rounded corner. Without the inset, day one and the last
          // day sat exactly on the plot's edge, so the line and the band wash
          // were drawn half outside the box and the left edge read as a chart
          // that had escaped its card.
          ClipRRect(
            borderRadius: BorderRadius.circular(ElaraRadii.card - 4),
            child: SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: -0.5,
                  maxX: points.length - 0.5,
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: tokens.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: RangeAnnotations(
                    verticalRangeAnnotations: [
                      for (final band in bands)
                        VerticalRangeAnnotation(
                          x1: band.startIndex.toDouble() - 0.5,
                          x2: band.endIndex.toDouble() + 0.5,
                          color: tokens.phaseWash(band.phaseKey, opacity: 0.20),
                        ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: type.number(
                            tokens.textSecondaryStrong,
                            size: 11,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: alertThreshold,
                        color: tokens.warning,
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          style: type.number(
                            tokens.warningText,
                            size: 10,
                            weight: FontWeight.w400,
                          ),
                          labelResolver: (_) => '38°C',
                        ),
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => tokens.textPrimary,
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}°C',
                            type.number(tokens.bgCard, size: 12),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: tokens.phaseFill('ovulatory'),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Background bands are the predicted phase for each day.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}
