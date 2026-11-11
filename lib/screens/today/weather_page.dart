import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';
import '../../utils/phase_timeline.dart';
import '../settings/location_page.dart';
import 'climate_strip.dart';

/// The day's heat index, air quality and season, and why any of it is here.
///
/// The strip itself was a card on Today, sitting between the guidance and the
/// calendars, doing nothing wrong and taking a third of the screen to say two
/// numbers. On a page, the numbers can be explained: what the heat index
/// actually is, why Dhaka's is what it is, and what the app does with it.
class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const WeatherPage());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final result = context.watch<PredictionProvider>().result;
    final snapshot = result?.environment;
    final phaseKey = phaseKeyOfResult(result) ?? 'unknown';

    return ElaraSubPage(
      title: 'Weather and air',
      subtitle:
          'Read from the forecast for the coordinates typed into settings, and '
          'cached on this phone so the screen works offline.',
      children: [
        if (snapshot == null)
          ElaraGlass(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ElaraIcons.weather,
                  size: 18,
                  color: tokens.textSecondaryStrong,
                ),
                const SizedBox(width: ElaraSpacing.sm),
                Expanded(
                  child: Text(
                    'No weather has been recorded for today. Elara uses a '
                    'seasonal table for the area when it cannot reach a '
                    'forecast, and says so on the card when it does that.',
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ClimateStrip(snapshot: snapshot, phaseKey: phaseKey),
          const SizedBox(height: ElaraSpacing.lg),
        ],

        // Why weather is in a cycle app at all. This is the paragraph that was
        // missing when the strip sat on Today unannounced.
        ElaraGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why the weather is here',
                style: type.subtitle(tokens.textPrimary, size: 15),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                'The heat index combines temperature and humidity into what the '
                'body actually experiences, and in Dhaka it sits well above the '
                'air temperature for most of the year. On the days it is high, '
                'suggestions on Today change: rest and fluids rather than a '
                'walk, and no assumption that a bad day is only hormonal.',
                style: type.body(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'Air quality is shown for the same reason. On a high PM2.5 '
                'day, the suggestions stay indoors.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.lg),
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Location',
              subtitle: 'Change the coordinates the forecast is read for',
              icon: ElaraIcons.weather,
              onTap: () =>
                  Navigator.of(context).push(LocationPage.route(context)),
            ),
          ],
        ),
      ],
    );
  }
}
