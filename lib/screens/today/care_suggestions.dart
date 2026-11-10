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
    this.general = const [],
  });

  /// What the app knows about her: her answers, what she reported, what you
  /// noticed, the weather. In that order.
  final List<CareSuggestion> suggestions;

  final String phaseKey;

  /// General, source-backed advice for this phase. Shown underneath the
  /// personalised list, or instead of it when there is nothing personal.
  final List<CareSuggestion> general;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;

    // Where the personalised list is empty, the general one leads — and says
    // so. An app that has nothing personal to go on should still be useful in
    // the first five seconds, and its first suggestion should not be an
    // apology.
    if (suggestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GeneralHeader(empty: true, phaseKey: phaseKey),
          const SizedBox(height: ElaraSpacing.sm),
          for (var i = 0; i < general.length; i++) ...[
            if (i > 0) const SizedBox(height: ElaraSpacing.md),
            _Secondary(suggestion: general[i], showSource: true),
          ],
          const SizedBox(height: ElaraSpacing.lg),
          Text(
            'None of this is about her yet. Add something she has told you in '
            'Preferences, or log a symptom, and these become specific.',
            style: context.type.caption(tokens.textSecondaryStrong),
          ),
        ],
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
        if (general.isNotEmpty) ...[
          const SizedBox(height: ElaraSpacing.lg),
          _GeneralHeader(empty: false, phaseKey: phaseKey),
          const SizedBox(height: ElaraSpacing.sm),
          for (var i = 0; i < general.length; i++) ...[
            if (i > 0) const SizedBox(height: ElaraSpacing.md),
            _Secondary(suggestion: general[i], showSource: true),
          ],
        ],
      ],
    );
  }
}

/// The heading above the general layer.
///
/// It has to be clear about what follows, because this is the part that is not
/// about her. "In general, this phase" says that the advice is about the phase
/// rather than about her, which is exactly true, and the sources under each item
/// say where it came from.
class _GeneralHeader extends StatelessWidget {
  const _GeneralHeader({required this.empty, required this.phaseKey});

  final bool empty;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Row(
      children: [
        Icon(ElaraIcons.medical, size: 16, color: tokens.textSecondaryStrong),
        const SizedBox(width: ElaraSpacing.xs),
        Expanded(
          child: Text(
            empty
                ? 'In general, for this phase'
                : 'In general: ${_phaseName(phaseKey)} phase',
            style: context.type
                .caption(tokens.textSecondaryStrong, size: 12)
                .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }

  static String _phaseName(String key) {
    switch (key) {
      case 'menstrual':
        return 'menstrual';
      case 'follicular':
        return 'follicular';
      case 'ovulatory':
        return 'ovulatory';
      case 'luteal':
        return 'luteal';
      default:
        return 'any';
    }
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
  const _Secondary({required this.suggestion, this.showSource = false});

  final CareSuggestion suggestion;

  /// General advice names its source, because "a general idea" is not a
  /// citation. Personal advice does not need one: the source is her.
  final bool showSource;

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
              const SizedBox(height: 2),
              Text(
                suggestion.body,
                style: type.caption(tokens.textSecondaryStrong, size: 13),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              if (showSource && suggestion.source != null)
                Text(
                  suggestion.source!,
                  style: context.type.caption(
                    tokens.textSecondaryStrong,
                    size: 12,
                  ),
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
