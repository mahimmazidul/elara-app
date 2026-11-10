import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';
import 'lunar_strip.dart';

/// The moon, the Hijri date and the nakshatra, with room to say what they are.
///
/// None of these are part of the prediction and none of them should be mistaken
/// for it — which is exactly why they get their own page. On Today they were the
/// last thing on a long scroll and the first thing a reader was likely to
/// misread as part of the estimate. Here the page can say what each calendar is
/// computed from, and that the phase names are English because they are lunar
/// phase names rather than Bangla month names.
class CalendarsPage extends StatelessWidget {
  const CalendarsPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const CalendarsPage());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return ElaraSubPage(
      title: 'Moon and calendars',
      subtitle:
          'Computed on this phone from the date. Reference information, kept '
          'separate from the cycle estimate.',
      children: [
        ElaraGlass(child: LunarStrip(date: DateTime.now())),
        const SizedBox(height: ElaraSpacing.lg),
        ElaraGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What each one is',
                style: type.subtitle(tokens.textPrimary, size: 15),
              ),
              const SizedBox(height: ElaraSpacing.sm),
              const _Entry(
                icon: ElaraIcons.moon,
                label: 'Moon',
                body:
                    'The astronomical phase, from an ephemeris calculation — '
                    'not the sighting-based lunar month. The fraction shown is '
                    'the illuminated portion.',
              ),
              const SizedBox(height: ElaraSpacing.md),
              const _Entry(
                icon: ElaraIcons.moon,
                label: 'Hijri',
                body:
                    'The tabular Islamic calendar, computed arithmetically. '
                    'Official dates in Bangladesh are set by moon sighting and '
                    'can differ by a day, which is why this is labelled as '
                    'computed rather than as the date.',
              ),
              const SizedBox(height: ElaraSpacing.md),
              const _Entry(
                icon: ElaraIcons.trend,
                label: 'Nakshatra',
                body:
                    'The lunar mansion of the Vedic calendar, from the same '
                    'ephemeris. Shown because a good part of the app\'s '
                    'audience reads it, not because it affects the estimate.',
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.lg),
        Text(
          'Nothing on this page changes what Today says about the cycle. It is '
          'calendar arithmetic, shown for information, and it is computed from '
          'the date rather than looked up.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.label, required this.body});

  final IconData icon;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: tokens.textSecondaryStrong),
        ),
        const SizedBox(width: ElaraSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: type.label(tokens.textPrimary, size: 13)),
              const SizedBox(height: 2),
              Text(body, style: type.caption(tokens.textSecondaryStrong)),
            ],
          ),
        ),
      ],
    );
  }
}
