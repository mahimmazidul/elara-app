import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/elara_motion.dart';
import '../theme/elara_theme.dart';
import 'moon_glyph.dart';

/// The cycle dial: where today sits in the cycle, as a ring rather than a disc.
///
/// The disc this replaces was a filled 150 dp circle with two lines of text in
/// it. It carried one value — the phase name — at the cost of the largest area
/// on the screen, and it said the same thing as the chip above it. A ring says
/// more with less paint: the sweep is the cycle, the gap is how much of it is
/// left, and the dot is today.
///
/// Three things are deliberate:
///
///  * **The ring is not a progress bar for a goal.** It sweeps from the start of
///    the cycle to today, so "more" is not "better" — the colour and the label
///    carry the meaning, and the geometry only places today in time.
///  * **The moon inside it is the cycle's moon, not the sky's.** New at the
///    start of bleeding, waxing through the follicular phase, full at the
///    estimated ovulatory days, waning through the luteal phase. It is a motif,
///    not a measurement, and the phase name sits beside it in words.
///  * **Unknown is a state, not zero.** With no phase the ring is drawn in a
///    neutral tone with no sweep and no dot, rather than sitting at 0% as if the
///    cycle had just begun.
class PhaseDial extends StatelessWidget {
  const PhaseDial({
    super.key,
    required this.label,
    required this.fill,
    this.cycleDay,
    this.cycleLength,
    this.phaseKey = 'unknown',
    this.diameter = 168,
    this.onHero = false,
  });

  /// The phase name, as it should be read out: "Ovulatory", "Unclassified".
  final String label;

  /// The phase colour for the sweep and the dot.
  final Color fill;

  /// Today's position in the cycle, 1-based. Null when there is no phase.
  final int? cycleDay;

  /// The estimated cycle length the sweep is measured against.
  final int? cycleLength;

  /// A stable key for the phase, used to pick the moon and to settle the label.
  final String phaseKey;

  /// Whether the dial is drawn on a saturated hero panel.
  ///
  /// On the panel the geometry stays the same and only the paint changes: the
  /// track becomes the panel's own ink at low alpha and the sweep becomes solid
  /// ink, because a dust-coloured arc on a deep panel disappears entirely and a
  /// panel-tinted arc on the same panel is invisible. Nothing about the meaning
  /// changes, which is the test for whether a colour is doing work: the ring is
  /// still the cycle, the gap still the part of it that has not happened yet.
  final bool onHero;

  /// The outer size at 1.0x text scale. The dial grows with the text setting up
  /// to the width of the page, so a large label is never clipped.
  final double diameter;

  /// Where the cycle's moon is, 0..1, for the eight conventional buckets.
  ///
  /// Menstrual is the new moon and the ovulatory days are full; that is the
  /// whole of the claim. It is not the astronomical phase, which the lunar
  /// strip at the foot of the screen reports separately.
  static double moonFractionFor(String phaseKey) {
    switch (phaseKey) {
      case 'menstrual':
        return 0.0;
      case 'follicular':
        return 0.18;
      case 'ovulatory':
        return 0.5;
      case 'luteal':
        return 0.76;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints),
  );

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final tokens = context.elara;
    final type = context.type;

    final textScale = MediaQuery.textScalerOf(context).scale(1);

    // The dial measures itself against the space it was given, not against the
    // width of the display. It used to subtract the page margin from the screen
    // width, which is right on a page and wrong inside a card: at a 2x text
    // setting the dial grew past the card's inner width and the row overflowed
    // by twelve pixels, which is the kind of bug a screenshot shows and a test
    // catches only if somebody thought to set the text scale.
    final available = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width - ElaraSpacing.lg * 2;
    final size = (diameter * textScale.clamp(1.0, 1.6))
        .clamp(math.min(diameter, available), available)
        .toDouble();

    final day = cycleDay;
    final length = cycleLength;
    final progress = (day == null || length == null || length < 10)
        ? null
        : (day / length).clamp(0.0, 1.0);

    final inner = size * 0.62;

    // The ring is drawn at a fixed size and the text inside it is laid out in
    // a 62% inset, which is where a circle is widest enough to hold a line of
    // type without touching the stroke.
    return Semantics(
      container: true,
      label: day == null
          ? '$label. No phase for today.'
          : '$label, day $day${length == null ? '' : ' of $length'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress ?? 0),
                  duration: ElaraMotion.reduceMotion(context)
                      ? Duration.zero
                      : ElaraMotion.slow,
                  curve: ElaraMotion.curve,
                  builder: (context, value, _) => CustomPaint(
                    painter: _DialPainter(
                      progress: progress == null ? null : value,
                      colour: onHero ? tokens.onHero : fill,
                      track: onHero
                          ? tokens.onHero.withValues(alpha: 0.22)
                          : tokens.divider,
                      surface: onHero
                          ? tokens.heroFill(phaseKey)
                          : tokens.bgCard,
                      ring: onHero
                          ? tokens.onHero.withValues(alpha: 0.9)
                          : tokens.textSecondaryStrong,
                      stroke: onHero ? 6 : 3.5,
                      ticks: (day == null || length == null || length < 10)
                          ? null
                          : length.clamp(21, 40),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: inner,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoonGlyph(
                      phaseFraction: moonFractionFor(phaseKey),
                      size: size * 0.20,
                      // The phase colour, so the moon and the ring are the
                      // same object. At full phase the disc is solid, which is
                      // the correct drawing and the reason for the outline.
                      lit: onHero ? tokens.onHero : fill,
                      shadow: (onHero ? tokens.onHero : fill).withValues(
                        alpha: 0.16,
                      ),
                    ),
                    SizedBox(height: size * 0.03),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type
                          .subtitle(
                            onHero ? tokens.onHero : tokens.textPrimary,
                            size: 17,
                          )
                          .copyWith(height: 1.15),
                    ),
                    if (day != null) ...[
                      SizedBox(height: size * 0.02),
                      Text(
                        length == null ? 'Day $day' : 'Day $day of $length',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type
                            .caption(
                              onHero
                                  ? tokens.onHero.withValues(alpha: 0.72)
                                  : tokens.textSecondaryStrong,
                            )
                            .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.colour,
    required this.track,
    required this.surface,
    required this.ring,
    required this.stroke,
    required this.ticks,
  });

  /// 0..1 around the ring, or null when there is nothing to sweep.
  final double? progress;

  final Color colour;
  final Color track;
  final Color surface;
  final Color ring;
  final double stroke;

  /// One tick per day of the cycle, or null for a plain ring.
  ///
  /// A continuous arc of 72% says "mostly through" and nothing else. A tick per
  /// day says *which day*, is countable at a glance, and gives the ring a
  /// texture that reads as a made object rather than as a progress bar. The
  /// count is clamped into 21..40 because a cycle outside that range is either
  /// a mis-entry or a condition, and 60 hairlines on a 150 dp circle is a grey
  /// smudge.
  final int? ticks;

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke sits fully inside the box: a centred stroke would otherwise
    // shave its outer edge off at the bounding rect. Widen with the same rule.
    final radius = size.shortestSide / 2 - stroke / 2 - 1;
    final centre = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final progress = this.progress;
    final ticks = this.ticks;
    if (ticks == null) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track,
      );
    } else {
      // The wheel: one tick per day, the elapsed ones carrying the ink. Nothing
      // is drawn on the days that have not happened yet except their place,
      // which is the point of counting them.
      final reached = ((progress ?? 0) * ticks).round();
      final tickLength = stroke * 2.2;
      for (var i = 0; i < ticks; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i) / ticks;
        final done = i < reached;
        final outer = Offset(
          centre.dx + (radius + tickLength / 2) * math.cos(angle),
          centre.dy + (radius + tickLength / 2) * math.sin(angle),
        );
        final inner = Offset(
          centre.dx + (radius - tickLength / 2) * math.cos(angle),
          centre.dy + (radius - tickLength / 2) * math.sin(angle),
        );
        canvas.drawLine(
          inner,
          outer,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = done ? stroke * 0.55 : stroke * 0.42
            ..color = done ? colour : track,
        );
      }
    }

    if (progress == null || progress <= 0) return;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    if (ticks != null) {
      // On the wheel the marker is the only solid disc, so it does not need the
      // ring around it that the arc version used.
      final dot = Offset(
        centre.dx + radius * math.cos(start + sweep),
        centre.dy + radius * math.sin(start + sweep),
      );
      canvas.drawCircle(dot, stroke * 0.95, Paint()..color = colour);
      return;
    }

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colour,
    );

    // Today, as a dot on the end of the sweep: a surface-coloured core inside a
    // phase-coloured ring, so it reads as a marker rather than as a blob of
    // colour sitting on a line of the same colour.
    final dot = Offset(
      centre.dx + radius * math.cos(start + sweep),
      centre.dy + radius * math.sin(start + sweep),
    );
    canvas.drawCircle(dot, stroke * 2.1, Paint()..color = colour);
    canvas.drawCircle(dot, stroke * 1.1, Paint()..color = surface);
    canvas.drawCircle(
      dot,
      stroke * 1.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.ticks != ticks ||
      old.colour != colour ||
      old.track != track ||
      old.surface != surface ||
      old.ring != ring;
}
