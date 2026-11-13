/// Partner-facing notes for the four broad parts of a menstrual cycle.
///
/// The body notes follow general NHS and ACOG guidance. The practical ideas
/// reflect recurring themes in women's own accounts: warmth, a meal, one less
/// chore, being treated normally, and being left alone when that is what she
/// wants. Those accounts disagree on the details, so the app asks the partner
/// to listen rather than treating a phase as a script.
///
/// The phase is estimated from dates, not measured. Nothing here is a medical
/// instruction, a promise about how she feels, or a substitute for her answer.
library;

/// What may be happening, and how a partner can make the day easier without
/// turning an estimate into an expectation.
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

  /// A broad point in the cycle, not a day count or a schedule.
  final String timing;

  /// A human reminder of what the phase label cannot tell the partner.
  final String aka;
  final String whatHappens;
  final List<String> doThis;
  final List<String> skip;
  final List<PartnerFood> foods;
}

/// A familiar thing to offer, and the non-medical reason it belongs here.
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
    aka: 'Pain and pace are hers to describe.',
    whatHappens:
        'The uterine lining is shedding. Prostaglandins make the uterus '
        'contract, which can cause cramps that reach the back or thighs. Pain '
        'and energy vary from person to person, and from one cycle to the next.',
    doThis: [
      'Take dinner, dishes, or the shopping off her list before she has to ask. '
          'A hot water bag helps less if she still has to get up and fill it.',
      'Offer a warm, wrapped hot water bag and ask whether her belly or lower '
          'back feels better.',
      'Ask once: "Would you like quiet, company, or something from the kitchen?" '
          'Then let her answer be enough.',
    ],
    skip: [
      'Saying "it is just hormones" or asking "are you on your period?" in '
          'the middle of a disagreement. Neither answers what she said.',
      'Assuming she wants to be fussed over. Some people want closeness; some '
          'want a normal day and a little space.',
    ],
    foods: [
      PartnerFood(
        'Chhola bhuna',
        'A filling, familiar snack if she fancies it. Offer it as food, not a '
            'cramp remedy.',
      ),
      PartnerFood(
        'Palong shak with masoor dal',
        'An ordinary home meal with greens and dal. Comfort is enough; the '
            'meal need not do anything to her cycle.',
      ),
      PartnerFood(
        'Khejur or gur with tea',
        'A little sweetness if that is what she feels like; her appetite gets '
            'the final say.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'follicular',
    name: 'Follicular',
    timing: 'After bleeding, before ovulation',
    aka: 'A transition, not a promise of extra energy.',
    whatHappens:
        'Follicles develop and oestrogen rises as the uterine lining begins to '
        'build again. Those are body changes, not a forecast of her mood, '
        'energy, or appetite; she may notice a shift or none at all.',
    doThis: [
      'If she has something she wants to do, help make room for it: arrange '
          'the fuchka run, the riverside walk, or a film at home without '
          'leaving her to plan every detail.',
      'When things are calm, ask what would make the harder days easier next '
          'time. Remember her answer, and check again later; it may change.',
    ],
    skip: [
      'Treating a guessed high-energy week as a promise that she will want an '
          'outing, extra work, or affection. The estimate cannot make that call.',
    ],
    foods: [
      PartnerFood(
        'Doi and chira',
        'A quick, familiar breakfast when she wants it. No special phase recipe '
            'is required.',
      ),
      PartnerFood(
        'An egg, boiled or bhuna',
        'An easy addition to a meal she already likes.',
      ),
      PartnerFood(
        'Peyara or mango in season',
        'A simple seasonal snack. Let her choose what sounds good.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'ovulatory',
    name: 'Ovulatory',
    timing: 'Around ovulation',
    aka: 'An estimate, never a green light.',
    whatHappens:
        'A rise in luteinising hormone prompts an ovary to release an egg. The '
        'timing can shift, and a cycle estimate cannot confirm ovulation. Some '
        'people notice a brief one-sided ache; many notice nothing.',
    doThis: [
      'Make the plan she actually wants: a walk, a night in, or no plan at all. '
          'Share the thinking rather than choosing for her.',
      'Offer affection, then let her decide. The date on a screen cannot stand '
          'in for a conversation or consent.',
    ],
    skip: [
      'Treating "ovulatory" as proof of a fertile day or as an invitation to '
          'sex. Elara measures neither hormone levels nor consent.',
      'Asking her to cancel something she is looking forward to because a '
          'quieter evening suits you better.',
    ],
    foods: [
      PartnerFood(
        'Ilish, when it is in season',
        'Cook it the way she likes it, when it fits the meal. It is dinner, not '
            'a fertility food.',
      ),
      PartnerFood(
        'Tishi, if she already enjoys it',
        'Add it to a familiar dish if she likes the taste. Nothing on the plate '
            'needs to promise anything about her cycle.',
      ),
      PartnerFood(
        'Doi or seasonal fruit',
        'An ordinary side or snack, offered because she likes it.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'luteal',
    name: 'Luteal',
    timing: 'After ovulation',
    aka: 'Some notice a pattern; no one is a calendar.',
    whatHappens:
        'After ovulation, progesterone rises and later falls if pregnancy does '
        'not occur. Some people notice premenstrual symptoms such as bloating, '
        'breast tenderness, headache, appetite changes, or low mood. Others '
        'notice few or none.',
    doThis: [
      'On a day she says is hard, take one task all the way off her hands: '
          'make the tea, clear dinner, or wash the dishes. Do not leave a second '
          'list for tomorrow.',
      'Ask when things are calm what helps before her period. Remember it, '
          'then check again next time; what she wants can change.',
    ],
    skip: [
      'Using "it is PMS" to end a disagreement, or calling a feeling '
          'irrational because of the date. A symptom does not cancel what she '
          'said.',
      'A lecture about salt, sugar, cravings, or self-control. Offer options, '
          'not rules.',
    ],
    foods: [
      PartnerFood(
        'Lal shak or pui shak',
        'A familiar meal if she wants it. Let it be food, not a promise about '
            'her symptoms.',
      ),
      PartnerFood(
        'Tok doi',
        'Serve it because she enjoys it, not because a cycle app prescribed it.',
      ),
      PartnerFood(
        'Whatever she asks for',
        'Fuchka, mango, mishti, or something else entirely. There is no perfect '
            'period snack; the useful part is that she named it.',
      ),
    ],
  ),
];
