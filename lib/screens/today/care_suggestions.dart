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

  final List<CareSuggestion> suggestions;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;

    if (suggestions.isEmpty) {
      return Text(
        'Nothing to suggest yet. Add something she has told you, and this '
        'becomes useful.',
        style: context.type.body(tokens.textSecondaryStrong),
      );
    }

    final primary = suggestions.first;
    final rest = suggestions.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Primary(suggestion: primary, phaseKey: phaseKey),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: ElaraSpacing.lg),
          for (var i = 0; i < rest.length; i++) ...[
            if (i > 0) const SizedBox(height: ElaraSpacing.md),
            _Secondary(suggestion: rest[i]),
          ],
        ],
      ],
    );
  }
}

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
        Text(
          suggestion.title,
          style: type.title(tokens.textPrimary, size: 19),
        ),
        const SizedBox(height: ElaraSpacing.sm),
        Text(
          suggestion.body,
          style: type.body(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.md),
        BasisLine(basis: suggestion.basis, phaseKey: phaseKey),
      ],
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({required this.suggestion});

  final CareSuggestion suggestion;

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
            iconFor(suggestion.kind),
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
              const SizedBox(height: 2),
              Text(
                suggestion.body,
                style: type.caption(tokens.textSecondaryStrong, size: 13),
              ),
              const SizedBox(height: ElaraSpacing.xs),
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
