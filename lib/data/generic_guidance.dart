/// General guidance for a cycle phase, with its source.
///
/// This is the layer the app shows when it has nothing personal to say, and
/// underneath what it does say when it has. It is deliberately not personalised:
/// it does not read her symptoms, her answers or her notes, so it cannot be
/// wrong about her. It is the same text for everybody in that phase, written
/// from published guidance, and each item names where it came from.
///
/// Two rules govern what may go in here.
///
/// **No claim that a phase determines a person.** "Iron-rich food helps replace
/// what is lost during bleeding" is a statement about physiology. "You will feel
/// tired in your luteal phase" is a statement about her, and the app has no
/// business making it.
///
/// **Bangladesh is the default setting, not an afterthought.** The advice here
/// assumes heat, humidity, rice-based meals, iron-deficiency anaemia at roughly
/// a quarter of women of reproductive age, and pharmacies that sell single
/// tablets without a leaflet. An NHS page on period pain does not mention any of
/// that. Where a specifically local fact applies it is marked with its own
/// source rather than folded into a Western one.
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
      title: 'Iron-rich food, not iron supplements on assumption',
      body:
          'Lentils, chickpeas, dark leafy greens and small fish with bones are '
          'the everyday sources here. Vitamin C from lemon or tomato in the same '
          'meal helps the body take the iron up.',
      source: 'WHO',
      citation: 'WHO guideline on iron supplementation, 2016',
    ),
    GenericGuidance(
      title: 'Fluids matter more than any food in this climate',
      body:
          'Water, coconut water or oral rehydration solution through the day. '
          'Thirst is a late signal in humid heat, and headache is often the '
          'first sign it was not enough.',
      source: 'WHO',
      citation: 'WHO heat and health guidance',
    ),
  ];

  /// Guidance for a phase, by the same keys the theme uses.
  static const Map<String, List<GenericGuidance>> byPhase = {
    'menstrual': [
      GenericGuidance(
        title: 'Heat on the lower abdomen is worth trying first',
        body:
            'A warm pack or a hot water bottle for twenty minutes at a time. It '
            'is cheap, it has no interactions, and it helps some people enough '
            'that they need less pain relief.',
        source: 'NICE',
        citation: 'NICE CKS — Dysmenorrhoea',
      ),
      GenericGuidance(
        title: 'Pain relief works better taken early',
        body:
            'Non-steroidal anti-inflammatories such as ibuprofen or mefenamic '
            'acid work best started at the first sign of bleeding rather than '
            'once the pain is established. Whether one suits her is a question '
            'for a pharmacist.',
        source: 'NHS',
        citation: 'NHS — Period pain',
      ),
    ],
    'follicular': [
      GenericGuidance(
        title: 'A good week for the things that need energy',
        body:
            'The days after bleeding are usually the ones people find easiest '
            'for exercise and appointments. Worth noticing whether that is true '
            'for her, rather than assuming it.',
        source: 'ACOG',
        citation: 'ACOG — Your menstrual cycle',
      ),
      GenericGuidance(
        title: 'Protein at the first meal',
        body:
            'Egg, dal, fish or yoghurt rather than a plate of rice alone. It '
            'holds hunger off longer through a working morning.',
        source: 'BIRDEM',
        citation: 'BIRDEM dietary guidance for Bangladeshi diets',
      ),
    ],
    'ovulatory': [
      GenericGuidance(
        title: 'Mild one-sided pain mid-cycle is common',
        body:
            'Some people feel a short twinge on one side around the middle of '
            'the cycle. It usually passes in a day. Pain that is severe, or '
            'comes with fever or vomiting, is a reason to be seen rather than '
            'to wait.',
        source: 'NICE',
        citation: 'NICE CKS — Ovulation pain',
      ),
      GenericGuidance(
        title: 'This is an estimate, not a measurement',
        body:
            'The app is placing this phase with arithmetic from the last '
            'recorded period start. It has not measured a hormone, and nothing '
            'here should be used to decide whether sex can lead to pregnancy.',
        source: 'Elara',
        citation: 'See docs/PREDICTION.md',
      ),
    ],
    'luteal': [
      GenericGuidance(
        title: 'Regular meals and less salt can soften the week before',
        body:
            'Bloating and breast tenderness are often made worse by long gaps '
            'between meals and by salty food. Nothing is being treated here — '
            'these are the changes most people notice.',
        source: 'NHS',
        citation: 'NHS — PMS',
      ),
      GenericGuidance(
        title: 'Sleep is the first thing to protect',
        body:
            'A consistent bedtime and less screen at night. If low mood lasts '
            'most of the month rather than the days before bleeding, that is '
            'worth raising with a clinician rather than managed with an app.',
        source: 'NICE',
        citation: 'NICE — PMDD recognition',
      ),
    ],
  };

  /// Everything that applies on a given day: the phase's own items, then the
  /// ones that hold in any phase.
  ///
  /// The phase list comes first because it is the more specific of the two, and
  /// because a reader who has opened Today in the luteal phase is asking about
  /// the luteal phase. An unknown phase gets the general set alone — which is
  /// the correct answer, not a gap.
  static List<GenericGuidance> forPhase(String? phaseKey) {
    final phase = byPhase[phaseKey] ?? const <GenericGuidance>[];
    return [...phase, ...anyPhase];
  }
}
