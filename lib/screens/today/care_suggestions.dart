import 'package:flutter/material.dart';

import '../../services/care_recommender.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';

/// The care suggestions on Today.
///
/// One primary suggestion, given the room to read as a paragraph, then the rest
/// as a quieter list. No cards: a hairline and a change in type weight is enough
/// to separate them, and stacking three boxes made every suggestion look equally
/// important when the whole point is that the first one is better founded than
/// the ones below it.
///
/// Every suggestion carries its [CareBasis] as a small line with an icon, so the
/// user can always see whether they are acting on something she said or on
/// something the app inferred. That line is not decoration; it is the difference
/// between care and assumption.
class CareSuggestions extends StatelessWidget {
  const CareSuggestions({
    super.key,
    required this.suggestions,
    required this.phaseKey,
  });

  /// What the app knows about her: her answers, what she reported, what you
  /// noticed, the weather. In that order.
  final List<CareSuggestion> suggestions;

  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    // Nothing personal yet. The screen does not apologise for that here,
    // because the phase block below it is already filling the space with
    // something sourced; one line saying why is enough.
    if (suggestions.isEmpty) {
      return Text(
        'Nothing she has told you yet. Add something in Preferences, or record '
        'a symptom, and these become specific to her.',
        style: type.caption(tokens.textSecondaryStrong),
      );
    }

    final primary = suggestions.first;
    final rest = suggestions.skip(1).toList();

    // One pane, with hairlines between. Three floating paragraphs at the same
    // weight was the reason this section read as a wall: the pane says "these
    // belong together", the dividers say they are separate, and the padding
    // gives each one somewhere to breathe.
    return ElaraGlass(
      padding: const EdgeInsets.symmetric(
        horizontal: ElaraSpacing.lg,
        vertical: ElaraSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Primary(suggestion: primary, phaseKey: phaseKey),
          for (final suggestion in rest) ...[
            const SizedBox(height: ElaraSpacing.lg),
            Divider(height: 1, thickness: 1, color: tokens.divider),
            const SizedBox(height: ElaraSpacing.lg),
            _Secondary(suggestion: suggestion),
          ],
        ],
      ),
    );
  }
}

/// One general, sourced item for the phase.
///
/// Rendered with the citation instead of a basis tag: the basis is always the
/// same ("this is published guidance"), so the useful line is which guidance.
class GeneralGuidanceList extends StatelessWidget {
  const GeneralGuidanceList({
    super.key,
    required this.items,
    required this.phaseKey,
  });

  final List<CareSuggestion> items;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: ElaraSpacing.lg),
          _Secondary(
            suggestion: items[i],
            showSource: true,
            phaseKey: phaseKey,
          ),
        ],
      ],
    );
  }
}

/// The primary suggestion, given the room to read as a paragraph.
class _Primary extends StatelessWidget {
  const _Primary({required this.suggestion, required this.phaseKey});

  final CareSuggestion suggestion;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(suggestion.title, style: type.title(tokens.textPrimary, size: 19)),
        const SizedBox(height: ElaraSpacing.sm),
        Text(suggestion.body, style: type.body(tokens.textSecondaryStrong)),
        const SizedBox(height: ElaraSpacing.md),
        BasisLine(basis: suggestion.basis, phaseKey: phaseKey),
      ],
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.suggestion,
    this.showSource = false,
    this.phaseKey = 'unknown',
  });

  final CareSuggestion suggestion;

  /// General advice names its source, because "a general idea" is not a
  /// citation. Personal advice does not need one: the source is her.
  final bool showSource;

  /// Only used for the general layer, whose icon carries the phase dot.
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            // General advice is reference material rather than a suggestion
            // about her, and it draws the reference glyph so the eye can tell
            // the two layers apart without reading the heading.
            showSource ? ElaraIcons.info : iconFor(suggestion.kind),
            size: ElaraIcons.size,
            color: tokens.textSecondaryStrong,
          ),
        ),
        const SizedBox(width: ElaraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.title,
                style: type.subtitle(tokens.textPrimary, size: 15),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                suggestion.body,
                style: type.caption(tokens.textSecondaryStrong, size: 13.5),
              ),
              const SizedBox(height: ElaraSpacing.sm),
              if (showSource && suggestion.source != null)
                Text(
                  suggestion.source!,
                  style: type.caption(tokens.textSecondaryStrong, size: 12),
                )
              else
                BasisLine(basis: suggestion.basis),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "where did this come from" line.
///
/// Known information is stated plainly in the secondary ink; an assumption is
/// marked with an outline icon and phrased as an estimate. The distinction is
/// the reason this widget exists rather than being folded into the body text.
class BasisLine extends StatelessWidget {
  const BasisLine({super.key, required this.basis, this.phaseKey});

  final CareBasis basis;
  final String? phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;

    final colour = basis.isKnown
        ? (phaseKey == null
              ? tokens.textSecondaryStrong
              : tokens.phaseText(phaseKey!))
        : tokens.textSecondaryStrong;

    return BasisTag(
      label: basis.label,
      icon: basis.isKnown ? ElaraIcons.confirmed : ElaraIcons.observation,
      color: colour,
    );
  }
}

/// Maps a suggestion kind to its glyph.
///
/// Centralised so a "food" suggestion looks the same everywhere it appears,
/// including in the calendar sheet.
IconData iconFor(CareKind kind) {
  switch (kind) {
    case CareKind.food:
      return ElaraIcons.food;
    case CareKind.activity:
      return ElaraIcons.calendar;
    case CareKind.comfort:
      return ElaraIcons.care;
    case CareKind.gesture:
      return ElaraIcons.care;
    case CareKind.ask:
      return ElaraIcons.talk;
    case CareKind.avoid:
      return ElaraIcons.warning;
    case CareKind.prepare:
      return ElaraIcons.symptom;
    case CareKind.rest:
      return ElaraIcons.moon;
  }
}
