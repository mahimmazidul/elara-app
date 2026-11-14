/// Partner-facing notes for the four broad parts of a menstrual cycle.
///
/// The body notes follow general NHS and ACOG guidance. The practical ideas
/// reflect recurring themes in women's own accounts: warmth, a meal, one less
/// chore, being treated normally, and room to rest when she wants it.
library;

/// Returns the [PartnerPhase] matching [phaseKey], or `null` if unknown.
PartnerPhase? partnerPhaseFor(String? phaseKey) {
  if (phaseKey == null) return null;
  for (final phase in partnerPhases) {
    if (phase.phaseKey == phaseKey) return phase;
  }
  return null;
}

/// What may be happening, and how a partner can make the day easier.
class PartnerPhase {
  const PartnerPhase({
    required this.phaseKey,
    required this.name,
    required this.timing,
    required this.aka,
    required this.whatHappens,
    required this.doThis,
    required this.skip,
    required this.foods,
  });

  /// The key elara-core uses, so the phase marker uses the same vocabulary.
  final String phaseKey;
  final String name;

  /// A broad point in the cycle.
  final String timing;

  /// A human reminder of what matters most in this phase.
  final String aka;
  final String whatHappens;
  final List<String> doThis;
  final List<String> skip;
  final List<PartnerFood> foods;
}

/// A familiar dish or snack to offer from the kitchen.
class PartnerFood {
  const PartnerFood(this.name, this.why);

  final String name;
  final String why;
}

const List<PartnerPhase> partnerPhases = [
  PartnerPhase(
    phaseKey: 'menstrual',
    name: 'Menstrual',
    timing: 'During bleeding',
    aka: 'Pain and pace vary from day to day, so let her set the rhythm.',
    whatHappens:
        'The uterine lining is shedding. Prostaglandins make the uterus '
        'contract, which can cause cramps that reach the back or thighs. Pain '
        'and energy vary from person to person, and from one cycle to the next.',
    doThis: [
      'Take dinner, dishes, or the shopping off her list before she has to ask. '
          'A hot water bag helps much more when you fill and bring it to her.',
      'Offer a warm, wrapped hot water bag and ask whether her belly or lower '
          'back feels better.',
      'Ask once: "Would you like quiet, company, or something from the kitchen?" '
          'Then let her answer guide the rest of the evening.',
    ],
    skip: [
      'Saying "it is just hormones" or asking "are you on your period?" in '
          'the middle of a disagreement. Listen to what she is actually saying.',
      'Assuming she wants a big fuss made over her. Some women want closeness, '
          'while others prefer an ordinary day and a little quiet space.',
    ],
    foods: [
      PartnerFood(
        'Chhola bhuna',
        'A filling, familiar snack when she wants something warm and savoury.',
      ),
      PartnerFood(
        'Palong shak with masoor dal',
        'A comforting everyday home meal with greens, dal, and warm rice.',
      ),
      PartnerFood(
        'Khejur or gur with tea',
        'A small sweet pairing with afternoon tea when she feels like having it.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'follicular',
    name: 'Follicular',
    timing: 'After bleeding, before ovulation',
    aka: 'Energy often steadies as the days after a period settle in.',
    whatHappens:
        'Follicles develop and oestrogen rises as the uterine lining begins to '
        'build again. Some women notice lighter energy or appetite shifts '
        'during these days, while others feel much the same as usual.',
    doThis: [
      'If she mentions wanting to go out or do something together, handle the '
          'details for the fuchka run, riverside walk, or film night at home.',
      'When things are calm, ask what would make the harder days easier next '
          'time. Remember her answer and check in again next month.',
    ],
    skip: [
      'Assuming that post-period days automatically mean high energy or plans '
          'every evening. Follow how she actually feels on the day.',
    ],
    foods: [
      PartnerFood(
        'Doi and chira',
        'A quick, cool breakfast or light afternoon bowl whenever she wants it.',
      ),
      PartnerFood(
        'An egg, boiled or bhuna',
        'An easy, nourishing addition to a meal she already likes.',
      ),
      PartnerFood(
        'Peyara or mango in season',
        'Fresh seasonal fruit cut and ready when she wants a snack.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'ovulatory',
    name: 'Ovulatory',
    timing: 'Around ovulation',
    aka: 'Mid-cycle days estimated from her recorded history.',
    whatHappens:
        'A rise in luteinising hormone prompts an ovary to release an egg. The '
        'exact timing can shift from cycle to cycle. Some women notice a brief '
        'one-sided ache, while many feel no different at all.',
    doThis: [
      'Plan the kind of evening she actually enjoys, whether that is a walk '
          'outside, a quiet night in, or an unscheduled evening together.',
      'Be warm and attentive while letting her set the pace for closeness and '
          'plans.',
    ],
    skip: [
      'Treating an estimated mid-cycle window as a certainty about fertility '
          'or mood. Always talk openly with each other instead of relying on '
          'the calendar.',
      'Asking her to cancel something she has been looking forward to just '
          'because a quieter evening suits you better.',
    ],
    foods: [
      PartnerFood(
        'Ilish, when it is in season',
        'Cook it the way she enjoys it when it fits the family meal.',
      ),
      PartnerFood(
        'Tishi, if she already enjoys it',
        'Add it to a familiar home dish when she likes the flavour.',
      ),
      PartnerFood(
        'Doi or seasonal fruit',
        'A simple side or snack offered because she enjoys it.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'luteal',
    name: 'Luteal',
    timing: 'After ovulation',
    aka: 'Some notice a pattern; every cycle has its own pace.',
    whatHappens:
        'After ovulation, progesterone rises and later falls before the next '
        'period begins. Some women notice bloating, breast tenderness, '
        'headache, appetite changes, or lower energy, while others feel '
        'completely normal.',
    doThis: [
      'On a day she says is tiring, take one task all the way off her hands: '
          'make the tea, clear dinner, or finish the dishes so nothing waits '
          'for her tomorrow.',
      'Ask when things are calm what helps most in the days before her period, '
          'and keep those small comforts ready.',
    ],
    skip: [
      'Bringing up PMS during a disagreement or brushing off a concern because '
          'of the date on the calendar.',
      'Commenting on salt, sugar, or cravings. Keep her favourite snacks '
          'around the house so she can have what she feels like.',
    ],
    foods: [
      PartnerFood(
        'Lal shak or pui shak',
        'A comforting home-cooked side with warm rice when she wants a full meal.',
      ),
      PartnerFood(
        'Tok doi',
        'Serve it chilled or alongside lunch whenever she enjoys the taste.',
      ),
      PartnerFood(
        'Whatever she asks for',
        'Fuchka, mango, mishti, or anything else she mentions wanting that day.',
      ),
    ],
  ),
];
