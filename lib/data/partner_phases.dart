/// What to do for each phase, written for the partner rather than the person
/// whose cycle it is.
///
/// The shape comes from a set of eight slides the user supplied - four phases,
/// each with what is happening inside her body, a Do, a Don't, and three snacks
/// that answer something the phase does. The content here is the Bangladeshi
/// version of that: local food, local money, local family life. The slides
/// themselves are not shipped; the files were read and deleted, and what is in
/// the app is this file.
///
/// Two deliberate departures from the originals. The snack lists name food a
/// household in Khulna or Dhaka can actually buy - chhola, doi, chira, ilish,
/// palong shak - instead of cacao nibs and Greek yoghurt, and each one says what
/// it is for rather than what it contains, because "magnesium" is not a reason
/// anyone walks to the corner shop. And the "Don't" column keeps the original's
/// best line - do not call it hormones - without the profanity, because this is
/// read on a phone in a family house.
///
/// Nothing here is a medical instruction and nothing here is personalised: the
/// phase is an estimate from recorded dates, and the guide says so where it
/// opens.
class PartnerPhase {
  const PartnerPhase({
    required this.phaseKey,
    required this.name,
    required this.days,
    required this.aka,
    required this.whatHappens,
    required this.doThis,
    required this.skip,
    required this.foods,
  });

  /// The key elara-core uses, so the card can be tinted like the phase it
  /// describes without a second vocabulary.
  final String phaseKey;
  final String name;
  final String days;

  /// How she might describe it, in her words rather than a chart's.
  final String aka;
  final String whatHappens;
  final List<String> doThis;
  final List<String> skip;
  final List<PartnerFood> foods;
}

/// One thing to put in front of her, and the plain reason it helps.
class PartnerFood {
  const PartnerFood(this.name, this.why);

  final String name;
  final String why;
}

const List<PartnerPhase> partnerPhases = [
  PartnerPhase(
    phaseKey: 'menstrual',
    name: 'Menstrual',
    days: 'Days 1–5',
    aka: 'the days she is bleeding',
    whatHappens:
        'Oestrogen and progesterone are at their lowest. Energy drops, cramps '
        'are common, and a long list of small decisions costs more than it did '
        'last week.',
    doThis: [
      'Take the cooking and the dishes for two or three evenings. Rice, dal '
          'and an egg is enough, and it is the most useful thing in the house.',
      'Keep the hot water bag filled and where she can reach it without asking.',
      'Carry the water and the shopping. Both are heavier this week than they '
          'look from the outside.',
    ],
    skip: [
      'The sentence "এটা তো শুধু হরমোন" - it is just her hormones. Whatever is '
          'happening is happening to her, and naming the hormone does not make '
          'it smaller.',
      'Booking a long bus journey or a big family lunch into these days.',
    ],
    foods: [
      PartnerFood(
        'Khejur and gur',
        'Iron and quick energy for the days energy is lowest.',
      ),
      PartnerFood(
        'Chhola bhuna',
        'Magnesium, which is the mineral every cramp remedy is reaching for, '
            'and the cheapest protein in the bazaar.',
      ),
      PartnerFood(
        'Palong shak with masoor dal',
        'Iron, and the vitamin C in the dal helps her body take it up.',
      ),
      PartnerFood(
        'A banana',
        'Magnesium and potassium, and no cooking at all on a day that has none '
            'to spare.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'follicular',
    name: 'Follicular',
    days: 'Days 6–13',
    aka: 'she feels like herself again',
    whatHappens:
        'Oestrogen climbs and the lining rebuilds itself. Energy and sleep come '
        'back, patience comes back, and plans stop feeling like effort.',
    doThis: [
      'Plan the thing she has been putting off: a fuchka run, a walk by the '
          'river, a film at home with the phone in another room.',
      'Start the conversations that need patience from both of you. This is the '
          'week they are cheapest.',
    ],
    skip: [
      'Taking her independence personally. This is the week she says yes to '
          'things, and none of them are about you.',
    ],
    foods: [
      PartnerFood(
        'Doi and chira',
        'Live cultures and a slow carbohydrate - a steady morning without a '
            'second cup of tea.',
      ),
      PartnerFood(
        'An egg, boiled or bhuna',
        'Protein for the rebuilding this phase is doing.',
      ),
      PartnerFood(
        'Peyara, or a mango in season',
        'Vitamin C, which is what the iron in her dal needs to be absorbed.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'ovulatory',
    name: 'Ovulatory',
    days: 'Days 14–16',
    aka: 'her best three days, most cycles',
    whatHappens:
        'Oestrogen peaks and the egg is released. Strength, stamina and appetite '
        'for company all tend to be at their highest, and so does her tolerance '
        'for a crowded room.',
    doThis: [
      'Say yes to the plans she makes, and make one yourself, in advance, so '
          'she is not the only one arranging things.',
      'Show affection where she welcomes it. She is more likely to want it this '
          'week than next.',
    ],
    skip: [
      'Asking her to cancel something she is excited about so the evening is '
          'quieter for you.',
    ],
    foods: [
      PartnerFood(
        'Ilish, when it is in season',
        'Omega-3, and in season the best-value fish in the market.',
      ),
      PartnerFood(
        'Chingri, or kachki eaten with the bones',
        'Protein and calcium, in the form the household already cooks.',
      ),
      PartnerFood(
        'Tishi, soaked overnight',
        'The local answer to a chia pudding: omega-3 and fibre for a few taka.',
      ),
    ],
  ),
  PartnerPhase(
    phaseKey: 'luteal',
    name: 'Luteal',
    days: 'Days 17–28',
    aka: 'her body is working harder than it looks',
    whatHappens:
        'Progesterone rises and then falls away. Sleep gets lighter, appetite '
        'and cravings change, and patience runs shorter than it did last week - '
        'hers and yours both.',
    doThis: [
      'Make the tea without being asked, and take one chore off the list she '
          'has been carrying all month.',
      'Listen without fixing. Most of what she says in these days needs an ear '
          'and not a plan.',
    ],
    skip: [
      'Taking it personally. A short answer is not a verdict on the marriage.',
      'Telling her she is overreacting, or diagnosing the mood for her.',
    ],
    foods: [
      PartnerFood(
        'Lal shak or pui shak',
        'Magnesium and fibre, which is what the bloating advice is about.',
      ),
      PartnerFood(
        'Tok doi',
        'Calcium and cultures, and it is already in the fridge.',
      ),
      PartnerFood(
        'Whatever she asks for',
        'Fuchka, roshogolla, a whole mango. Four weeks of shifting hormones is '
            'not the week to argue about the menu.',
      ),
    ],
  ),
];
