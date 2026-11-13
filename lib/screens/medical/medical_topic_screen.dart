import 'package:material_ui/material_ui.dart';

import '../../data/medical_content.dart';
import '../../theme/elara_theme.dart';
import '../../utils/open_link.dart';
import '../../widgets/primitives.dart';
import '../../widgets/icons.dart';
import '../../widgets/elara_route.dart';

/// One topic, read top to bottom: what it is, what is usually done, when to
/// seek help, and where the text came from.
class MedicalTopicScreen extends StatelessWidget {
  const MedicalTopicScreen({super.key, required this.topic});

  final MedicalTopic topic;

  /// The route this screen is pushed with.
  ///
  /// It takes a [BuildContext] because the transition depends on the
  /// platform's animation setting, which is read at push time.
  static Route<void> route(BuildContext context, MedicalTopic topic) =>
      elaraRoute<void>(
        context,
        MedicalTopicScreen(topic: topic),
        name: 'medical/${topic.id}',
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Scaffold(
      appBar: AppBar(title: Text(topic.title, overflow: TextOverflow.ellipsis)),
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
                  medicalDisclaimer,
                  style: type.caption(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.lg),

                if (topic.urgentNote != null) ...[
                  _UrgentBlock(text: topic.urgentNote!),
                  const SizedBox(height: ElaraSpacing.lg),
                ],

                for (final section in topic.sections) ...[
                  ElaraOverline(section.heading),
                  const SizedBox(height: ElaraSpacing.xs),
                  for (final paragraph in section.paragraphs) ...[
                    Text(paragraph, style: type.body(tokens.textPrimary)),
                    const SizedBox(height: ElaraSpacing.sm),
                  ],
                  if (section.bullets.isNotEmpty)
                    for (final bullet in section.bullets)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: ElaraSpacing.xxs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•  ',
                              style: type.body(tokens.textSecondaryStrong),
                            ),
                            Expanded(
                              child: Text(
                                bullet,
                                style: type.body(tokens.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: ElaraSpacing.lg),
                ],

                // The most useful part of the page, so it is never last and
                // never folded away.
                ElaraOverline(
                  'When to see a clinician',
                  color: tokens.dangerText,
                ),
                const SizedBox(height: ElaraSpacing.xs),
                for (final flag in topic.whenToSeekHelp)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ElaraSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: tokens.dangerText,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: ElaraSpacing.sm),
                        Expanded(
                          child: Text(
                            flag,
                            style: type.body(tokens.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: ElaraSpacing.lg),
                const Hairline(margin: 0),
                const SizedBox(height: ElaraSpacing.lg),

                ElaraOverline('Sources'),
                const SizedBox(height: ElaraSpacing.xs),
                Text(
                  'Checked $medicalSourcesChecked. Tap a reference to copy its '
                  'address.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
                const SizedBox(height: ElaraSpacing.sm),
                for (final source in topic.sources) _SourceRow(source: source),

                const SizedBox(height: ElaraSpacing.lg),
                Text(
                  'This page is general education and is not reviewed against '
                  'her own history. If something here worries you, or does not '
                  'match what she has told you, ask a clinician rather than '
                  'relying on the app.',
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

/// The safety line for topics where waiting is the wrong advice.
class _UrgentBlock extends StatelessWidget {
  const _UrgentBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Container(
      padding: const EdgeInsets.all(ElaraSpacing.md),
      decoration: BoxDecoration(
        color: tokens.bgCard,
        borderRadius: BorderRadius.circular(ElaraRadii.card),
        border: Border.all(color: tokens.dangerText.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ElaraIcons.warning, size: 18, color: tokens.dangerText),
          const SizedBox(width: ElaraSpacing.sm),
          Expanded(child: Text(text, style: type.body(tokens.textPrimary))),
        ],
      ),
    );
  }
}

/// A reference. Tapping copies the URL — the app deliberately ships without a
/// browser launcher, so a link that cannot open is better as selectable text
/// and a browser than as a button that does nothing.
///
/// It shows the publisher and the site, not the address. A column of raw URLs
/// with percent-escapes in it is unreadable on a phone, unmemorisable, and
/// looks like a developer artefact that was left in the build — the reader needs
/// to know *whose* guidance this is, and to be able to open it, and nothing more.
class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final MedicalSource source;

  /// The site, without the scheme or the path: "nhs.uk", "who.int".
  static String _site(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return InkWell(
      borderRadius: BorderRadius.circular(ElaraRadii.chip),
      onTap: () => openLink(context, source.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ElaraSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.label,
                    style: type.label(tokens.textSecondaryStrong),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Opens ${_site(source.url)}',
                    style: type.bodyStrong(tokens.accentText, size: 13),
                  ),
                ],
              ),
            ),
            Icon(
              ElaraIcons.disclosure,
              size: 16,
              color: tokens.textSecondaryStrong,
            ),
          ],
        ),
      ),
    );
  }
}
