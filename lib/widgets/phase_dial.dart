import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final maxDiameter = MediaQuery.sizeOf(context).width - ElaraSpacing.lg * 2;
    final size = (diameter * textScale.clamp(1.0, 1.6)).clamp(
      diameter,
      maxDiameter,
    );

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
                      colour: fill,
                      track: tokens.divider,
                      surface: tokens.bgCard,
                      ring: tokens.textSecondaryStrong,
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
                      lit: fill,
                      shadow: fill.withValues(alpha: 0.16),
                    ),
                    SizedBox(height: size * 0.03),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.subtitle(tokens.textPrimary, size: 17).copyWith(
                        height: 1.15,
                      ),
                    ),
                    if (day != null) ...[
                      SizedBox(height: size * 0.02),
                      Text(
                        length == null ? 'Day $day' : 'Day $day of $length',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption(tokens.textSecondaryStrong)
                            .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
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
  });

  /// 0..1 around the ring, or null when there is nothing to sweep.
  final double? progress;

  final Color colour;
  final Color track;
  final Color surface;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke sits fully inside the box: at 3.5 dp on a 168 dp dial, a
    // centred stroke would shave its outer edge off at the bounding rect.
    const stroke = 3.5;
    final radius = size.shortestSide / 2 - stroke / 2 - 1;
    final centre = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final progress = this.progress;
    if (progress == null || progress <= 0) return;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

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
      old.colour != colour ||
      old.track != track ||
      old.surface != surface ||
      old.ring != ring;
}
