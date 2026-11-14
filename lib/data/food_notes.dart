/// What a food suggestion actually means, and what it looks like on a plate in
/// Dhaka.
///
/// elara-core returns categories rather than ingredients — "iron-rich foods",
/// "magnesium-rich foods" — because it is a prediction package and has no
/// business deciding what anyone eats. The problem with handing that to someone
/// standing in a kitchen is that it is not food yet: nobody has ever come home
/// with a bag of "iron-rich foods".
///
/// So each label gets a note here saying what the nutrient is for and which of
/// the things actually sold in a Bangladeshi market carry it. This file is the
/// only place those two halves meet, which is what keeps the core reusable and
/// the app specific.
class FoodNote {
  const FoodNote({required this.nutrient, required this.examples});

  /// The reason the category exists, in four words or fewer.
  final String nutrient;

  /// Concrete things to buy or cook, with a clause on how to use them well.
  final String examples;
}

const Map<String, FoodNote> _notes = {
  'iron-rich foods': FoodNote(
    nutrient: 'Iron',
    examples:
        'Lentils, chickpeas, spinach, small fish with bones. Lemon or '
        'tomato in the same meal helps the body take it up.',
  ),
  'complex carbohydrates': FoodNote(
    nutrient: 'Slow energy',
    examples:
        'Brown rice, oats, whole-wheat roti, sweet potato. They hold '
        'hunger off longer than white rice on its own.',
  ),
  'carbohydrates': FoodNote(
    nutrient: 'Comfort and energy',
    examples:
        'Rice, roti, potato. The week before bleeding, a plain '
        'carbohydrate is often the thing people actually want.',
  ),
  'magnesium-rich foods': FoodNote(
    nutrient: 'Magnesium',
    examples:
        'Peanuts, pumpkin seeds, dark leafy greens, dark chocolate. '
        'Often the nutrient people are short of in the week before bleeding.',
  ),
  'leafy greens': FoodNote(
    nutrient: 'Iron and folate',
    examples:
        'Spinach, water spinach (kolmi), amaranth leaves. Cheap, '
        'in season most of the year, and wilted in a pan in two minutes.',
  ),
  'dark chocolate': FoodNote(
    nutrient: 'Magnesium',
    examples:
        'Above 70% cocoa. A square or two; the sugar in milk chocolate '
        'is what most of it is.',
  ),
  'banana': FoodNote(
    nutrient: 'Potassium and B6',
    examples:
        'One a day. Worth having in the house on the days cramps make '
        'a proper meal too much effort.',
  ),
  'turkey': FoodNote(
    nutrient: 'Tryptophan',
    examples:
        'Hard to find here and not the point: chicken, eggs, milk or '
        'yoghurt do the same job.',
  ),
  'a varied diet': FoodNote(
    nutrient: 'Everything',
    examples:
        'Dal, rice, a vegetable, a protein, a fruit with vitamin C. '
        'The pattern matters more than any single item.',
  ),
  'a light and fun meal': FoodNote(
    nutrient: 'Something to look forward to',
    examples:
        'Fuchka, a shared plate of biryani, or fruit and yoghurt enjoyed '
        'together.',
  ),
};

/// The note for a suggestion, or null when the label is one this file has not
/// seen. Null renders as the bare label rather than as a guess: inventing a
/// nutrient for an unknown category would be worse than saying nothing.
FoodNote? foodNoteFor(String label) => _notes[label.trim().toLowerCase()];
