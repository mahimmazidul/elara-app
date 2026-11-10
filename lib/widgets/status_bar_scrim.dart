import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';

/// The soft band the status bar sits in.
///
/// The tabs scroll to the very top of the display, which is the point — content
/// travelling under the clock is what makes a long list feel like a sheet of
/// paper rather than a panel with a lid. What it is not allowed to do is make the
/// clock unreadable.
///
/// So there is a scrim: the page colour, nearly opaque at the top edge and gone
/// by the bottom of the status bar. It is not a bar and it has no edge. Scrolled
/// to the top, the first line of the page is below it and nothing looks
/// different; scrolled halfway, the previous content is visible behind the icons,
/// dimmed just enough to read them.
///
/// This is a gradient rather than a `BackdropFilter` for the same reason the glass
/// panels are: a blur here would re-sample the whole display on every scroll
/// frame for an effect a 20 %-alpha veil achieves.
class ElaraStatusBarScrim extends StatelessWidget {
  const ElaraStatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final inset = MediaQuery.paddingOf(context).top;
    if (inset <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: inset + 10,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tokens.bgPrimary.withValues(alpha: 0.94),
                tokens.bgPrimary.withValues(alpha: 0.72),
                tokens.bgPrimary.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
