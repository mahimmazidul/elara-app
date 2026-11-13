import 'package:material_ui/material_ui.dart';

import '../../data/medical_content.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import 'medical_topic_screen.dart';
import '../../widgets/elara_route.dart';

/// Background reading, kept deliberately separate from personalized care.
///
/// Today carries suggestions that depend on what this user has recorded, with
/// its own evidence and caveats. This screen carries none of that: it is the
/// same text for everybody, written from published sources, and it says so at
/// the top before anything else.
class MedicalScreen extends StatelessWidget {
  const MedicalScreen({super.key});

  /// The route this screen is pushed with.
  ///
  /// It takes a [BuildContext] because the transition depends on the
  /// platform's animation setting, which is read at push time.
  static Route<void> route(BuildContext context) => elaraRoute<void>(
        context,
        const MedicalScreen(),
        name: 'medical',
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Scaffold(
      appBar: AppBar(title: const Text('Health information')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ElaraSpacing.readableWidth,
            ),
            child: ListView(
              padding: ElaraSpacing.pageInsets(context),
              children: [
                Text(
                  'General, educational information',
                  style: type.title(tokens.textPrimary, size: 22),
                ),
                const SizedBox(height: ElaraSpacing.xs),
                Text(
                  medicalDisclaimer,
                  style: type.body(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.sm),
                Text(
                  'Every topic below is written from the published sources '
                  'listed on it, and is the same for everyone who opens the '
                  'app. The suggestions on Today are different: those are '
                  'based on what has been recorded here and are labelled as '
                  'estimates.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.xl),

                for (final topic in medicalTopics) ...[
                  _TopicRow(topic: topic),
                  const Hairline(margin: 0),
                ],

                const SizedBox(height: ElaraSpacing.lg),
                Text(
                  'Sources checked $medicalSourcesChecked. Elara is not a '
                  'medical device, has not been clinically reviewed, and does '
                  'not replace advice from a qualified clinician.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final MedicalTopic topic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return InkWell(
      borderRadius: BorderRadius.circular(ElaraRadii.chip),
      onTap: () => Navigator.of(context).push(MedicalTopicScreen.route(context, topic)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: type.bodyStrong(tokens.textPrimary, size: 16),
                  ),
                  const SizedBox(height: ElaraSpacing.xxs),
                  Text(
                    topic.summary,
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ElaraSpacing.sm),
            Icon(
              ElaraIcons.disclosure,
              size: 18,
              color: tokens.textSecondaryStrong,
            ),
          ],
        ),
      ),
    );
  }
}
