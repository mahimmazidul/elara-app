/// General guidance for a cycle phase, with its source.
///
/// This is the layer shown beneath the partner's personal care suggestions. It
/// is not personalised: it does not read her preferences, symptoms, or notes.
/// Health information names its publisher; practical advice drawn from online
/// accounts is labelled as lived experience, not medical evidence.
///
/// The writing avoids a timetable for her mood, energy, appetite, or affection.
/// A phase can describe a broad body process. It cannot tell the partner what
/// she wants today.
library;

/// One piece of general advice.
class GenericGuidance {
  const GenericGuidance({
    required this.title,
    required this.body,
    required this.source,
    required this.citation,
  });

  /// A short, plain statement or invitation. Never an instruction about her.
  final String title;

  /// One or two sentences of why.
  final String body;

  /// Where it came from, short enough for a caption: "NHS", "WHO", "BIRDEM".
  final String source;

  /// The specific page or guidance, for the reader who wants to check it.
  final String citation;
}

/// General guidance keyed by phase, plus a set that applies to any phase.
///
/// Kept as data rather than as code so the wording can be reviewed and changed
/// without touching the recommender, which is the same rule the health section
/// follows.
class GenericGuidanceTable {
  const GenericGuidanceTable._();

  /// Advice that holds regardless of where she is in the cycle.
  static const List<GenericGuidance> anyPhase = [
    GenericGuidance(
      title: 'Ask first. Then follow her answer.',
      body:
          'Women describe very different kinds of care: a hot water bag, a '
          'favourite snack, one less chore, or quiet. Offer one specific thing, '
          'then take her answer at face value.',
      source: 'Reddit',
      citation:
          'Reddit · r/AskWomenOver30 · “What do you wish your partner would '
          'do during your period?” (July 2025)',
    ),
    GenericGuidance(
      title: 'Warmth or gentle movement may ease cramps',
      body:
          'A warm shower or a wrapped hot water bag on the belly or lower back '
          'may help. Some people prefer a walk or gentle stretch; ask what she '
          'wants today.',
      source: 'NHS',
      citation: 'NHS · Period pain',
    ),
  ];

  /// Guidance for a phase, by the same keys the theme uses.
  static const Map<String, List<GenericGuidance>> byPhase = {
    'menstrual': [
      GenericGuidance(
        title: 'Heat and gentle movement are options for cramps',
        body:
            'A warm shower or a wrapped heat pad on the belly or lower back may '
            'help. Some people prefer a walk or stretch; let her choose what '
            'feels right today.',
        source: 'NHS',
        citation: 'NHS · Period pain',
      ),
      GenericGuidance(
        title: 'Pain that stops her day deserves attention',
        body:
            'Period pain is common, but pain that regularly disrupts work, '
            'sleep, study, or ordinary activity is worth discussing with a '
            'clinician.',
        source: 'NHS',
        citation: 'NHS · Period pain',
      ),
    ],
    'follicular': [
      GenericGuidance(
        title: 'The lining begins to build again',
        body:
            'After bleeding, follicles develop and oestrogen rises as the '
            'body prepares for the next part of the cycle. Energy and '
            'appetite can feel steadier, or feel much the same as any other '
            'week.',
        source: 'Cleveland Clinic',
        citation: 'Cleveland Clinic · Menstrual cycle',
      ),
      GenericGuidance(
        title: 'Plan the week around what she feels like doing',
        body:
            'Every week has its own pace. Ask what she feels up for and plan '
            'around her answer.',
        source: 'Reddit',
        citation:
            'Reddit · r/AskWomenOver30 · “What do you wish your partner would '
            'do during your period?” (July 2025)',
      ),
    ],
    'ovulatory': [
      GenericGuidance(
        title: 'A calendar cannot confirm ovulation',
        body:
            'This phase is estimated from recorded dates on the calendar. '
            'Rely on medical methods for contraception and talk openly with '
            'each other about how she feels.',
        source: 'Elara',
        citation: 'Elara · Forecast limits',
      ),
      GenericGuidance(
        title: 'Some people notice a brief one-sided ache',
        body:
            'Mild mid-cycle pain can pass on its own. Severe pain, pain that '
            'persists, or pain with fever or vomiting should not be brushed '
            'aside.',
        source: 'NICE',
        citation: 'NICE CKS · Ovulation pain',
      ),
    ],
    'luteal': [
      GenericGuidance(
        title: 'PMS looks different from person to person',
        body:
            'Bloating, tender breasts, headache, tiredness, appetite changes, '
            'or mood symptoms can happen before a period. The pattern and '
            'severity vary, including from month to month.',
        source: 'NHS',
        citation: 'NHS · Premenstrual syndrome',
      ),
      GenericGuidance(
        title: 'Make room for the habits she finds useful',
        body:
            'Sleep, regular movement, balanced meals, and symptom notes are '
            'among the options in NHS guidance. Ask what she wants to try; '
            'repeated symptoms that affect daily life merit a clinician '
            'conversation.',
        source: 'NHS',
        citation: 'NHS · Premenstrual syndrome',
      ),
    ],
  };

  /// Everything that applies on a given day: the phase's own items, then the
  /// ones that hold in any phase.
  ///
  /// The phase list comes first because it is the more specific of the two, and
  /// because a reader who has opened Today in the luteal phase is asking about
  /// the luteal phase. An unknown phase gets the general set alone, which is
  /// the right answer rather than an invitation to guess.
  static List<GenericGuidance> forPhase(String? phaseKey) {
    final phase = byPhase[phaseKey] ?? const <GenericGuidance>[];
    return [...phase, ...anyPhase];
  }
}
