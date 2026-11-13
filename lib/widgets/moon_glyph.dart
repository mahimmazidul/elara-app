import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/elara_theme.dart';

/// Draws the moon at [phaseFraction], lit side in the accent colour.
///
/// The app used to render this with the eight phase emoji, which depends on the
/// device having an emoji font: OEM builds without one showed a blank box, and a
/// headless render showed one too. Drawing the shape instead makes the glyph
/// identical everywhere and costs one small painter.
///
/// 0.0 is new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
class MoonGlyph extends StatelessWidget {
  const MoonGlyph({
    super.key,
    required this.phaseFraction,
    this.size = 18,
    this.lit,
    this.shadow,
  });

  final double phaseFraction;
  final double size;

  /// Colour of the lit side. Defaults to the accent; the Today dial passes the
  /// phase colour, so the moon belongs to the same palette as the ring.
  final Color? lit;

  /// Colour of the unlit side, so a new moon still reads as a disc.
  final Color? shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return CustomPaint(
      size: Size.square(size),
      painter: _MoonPainter(
        phaseFraction: phaseFraction,
        lit: lit ?? tokens.accent,
        shadow: shadow ?? tokens.moonGlow,
        outline: tokens.textSecondaryStrong,
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({
    required this.phaseFraction,
    required this.lit,
    required this.shadow,
    required this.outline,
  });

  final double phaseFraction;
  final Color lit;
  final Color shadow;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 0.75;

    // The unlit disc, so a new moon still reads as a circle.
    canvas.drawCircle(centre, radius, Paint()..color = shadow);

    final f = phaseFraction % 1.0;
    if (f > 0.001 && f < 0.999) {
      canvas.save();
      // Waning phases are the waxing shape mirrored, so only one case is needed.
      final mirrored = f > 0.5;
      final effective = mirrored ? 1 - f : f;
      if (mirrored) {
        canvas.translate(centre.dx * 2, 0);
        canvas.scale(-1, 1);
      }

      final path = Path()
        ..addArc(
          Rect.fromCircle(center: centre, radius: radius),
          -math.pi / 2,
          math.pi,
        );

      // The terminator is a half-ellipse whose horizontal axis is cos of the
      // phase angle: at new moon it lies on the limb, at the quarters it is a
      // straight line, and at full moon it reaches the far limb.
      final terminatorX = radius * math.cos(2 * math.pi * effective);
      final sweep = terminatorX >= 0 ? -math.pi : math.pi;
      path.addArc(
        Rect.fromCenter(
          center: centre,
          width: terminatorX.abs() * 2,
          height: radius * 2,
        ),
        math.pi / 2,
        sweep,
      );
      path.close();

      canvas.drawPath(path, Paint()..color = lit);
      canvas.restore();
    } else if (f >= 0.999) {
      canvas.drawCircle(centre, radius, Paint()..color = lit);
    }

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.phaseFraction != phaseFraction ||
      old.lit != lit ||
      old.shadow != shadow ||
      old.outline != outline;
}
