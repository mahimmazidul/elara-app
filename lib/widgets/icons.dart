import 'package:flutter/material.dart';

/// The app's icon vocabulary, in one place.
///
/// Two rules make a set of icons feel like a system rather than a collection of
/// pictures: the same stroke weight everywhere, and the same meaning every time
/// a shape appears. Both are enforced here rather than at the call sites, so no
/// screen can invent its own glyph for "food".
///
/// Everything is an outlined Material icon, because the outline family is drawn
/// on a consistent 2px grid that matches the weight of the app's type at
/// these sizes.
/// Filled icons are reserved for the one case where a shape must read as
/// "selected": the navigation bar.
///
/// Icons are deliberately not added to every label. A row of small glyphs beside
/// every line of text is noise; these appear where they carry meaning — a care
/// suggestion, a symptom, a source of information — and nowhere else.
///
/// ## Why every glyph lives here
///
/// A vocabulary that only covers *some* of the icons the app draws is worse
/// than none, because the ones left out drift: "add" becomes `Icons.add` in
/// one place and `Icons.add_rounded` in another, and the two are visibly
/// different weights at 16 px. Every icon the app draws is therefore named
/// here, and `test/widgets/icon_system_test.dart` fails if a screen reaches
/// for a raw `Icons.` constant instead.
///
/// The one exception is the navigation bar, which needs a filled icon for the
/// selected tab and an outlined one for the rest. That pair is a single
/// decision about one widget, so it lives with that widget.
class ElaraIcons {
  const ElaraIcons._();

  // ---- care, and the things a person does ---------------------------------

  /// Care recommendations and gestures.
  static const IconData care = Icons.favorite_border_rounded;

  /// A prompt to talk, rather than to act.
  static const IconData talk = Icons.chat_bubble_outline_rounded;

  /// Food and drink suggestions.
  static const IconData food = Icons.restaurant_outlined;

  /// Anything the partner has told you, as opposed to a guess.
  static const IconData confirmed = Icons.check_circle_outline_rounded;

  /// An observation rather than a confirmed fact.
  ///
  /// A pencil, not an eye: an eye means "looking at something", and what this
  /// marks is a note somebody wrote but nobody has confirmed. The eye is kept
  /// for [reveal], which means something is folded away.
  static const IconData observation = Icons.edit_note_outlined;

  // ---- dates and time ------------------------------------------------------

  /// Calendar events and dates.
  static const IconData calendar = Icons.event_outlined;

  /// A specific day, as opposed to a calendar.
  static const IconData day = Icons.calendar_today_outlined;

  /// Editing a date.
  static const IconData editDate = Icons.edit_calendar_outlined;

  /// A recorded period start, which can be corrected or removed.
  static const IconData recorded = Icons.event_available_outlined;

  /// Moving back and forward through months.
  static const IconData previous = Icons.chevron_left_rounded;

  static const IconData next = Icons.chevron_right_rounded;

  /// Disclosure of a chevron-style row.
  static const IconData disclosure = Icons.chevron_right_rounded;
  static const IconData github = Icons.code_rounded;

  // ---- symptoms ------------------------------------------------------------

  /// Symptoms the partner reported.
  static const IconData symptom = Icons.healing_outlined;

  /// General symptoms: cramps, headache, fatigue.
  static const IconData symptomGeneral = Icons.sick_outlined;

  /// Mood and feelings.
  static const IconData mood = Icons.psychology_outlined;

  /// Energy levels.
  static const IconData energy = Icons.battery_2_bar_rounded;

  /// A symptom with no more specific glyph: pain somewhere.
  static const IconData pain = Icons.waves_rounded;

  /// Sleep and rest.
  static const IconData sleep = Icons.spa_outlined;

  /// Water retention.
  static const IconData water = Icons.water_drop_outlined;

  /// A symptom recorded but not classified further.
  static const IconData other = Icons.circle_outlined;

  // ---- body and cycle ------------------------------------------------------

  /// The cycle timeline.
  static const IconData timeline = Icons.timeline_outlined;

  /// A measured length: a cycle's duration, a distance.
  static const IconData measure = Icons.straighten;

  /// How the cycle has changed over time.
  static const IconData trend = Icons.show_chart;

  // ---- environment ---------------------------------------------------------

  /// Weather, heat and air quality.
  static const IconData weather = Icons.thermostat_outlined;

  /// The heat index specifically, where the temperature would be ambiguous.
  static const IconData heat = Icons.thermostat;

  /// A cloud, for humidity or general conditions.
  static const IconData cloud = Icons.cloud_outlined;

  // ---- information ---------------------------------------------------------

  /// Educational medical information. Never diagnostic.
  static const IconData medical = Icons.menu_book_outlined;

  /// Something worth reading, and not an error.
  static const IconData info = Icons.info_outline_rounded;

  /// A warning worth reading.
  static const IconData warning = Icons.priority_high_rounded;

  /// Insights and analysis.
  static const IconData insights = Icons.insights_outlined;

  // ---- privacy and data ----------------------------------------------------

  /// Consent, privacy and data handling.
  static const IconData privacy = Icons.lock_outline_rounded;

  /// A shared decision, made together.
  static const IconData shared = Icons.people_outline_rounded;

  /// Undoing something — withdrawing consent, removing an entry.
  static const IconData undo = Icons.undo_rounded;

  /// Showing something that is currently hidden.
  ///
  /// Not the same as [observation]: that one means "this is a note, not a
  /// confirmed fact", while this one means "this field is folded away".
  static const IconData reveal = Icons.visibility_outlined;

  /// Hiding something that is currently shown.
  static const IconData hide = Icons.visibility_off_outlined;

  /// Copying something to the clipboard.
  static const IconData copy = Icons.copy_rounded;

  /// Removing something permanently.
  static const IconData delete = Icons.delete_outline_rounded;

  // ---- reminders -----------------------------------------------------------

  /// Notifications and reminders.
  static const IconData notification = Icons.notifications_none_rounded;

  // ---- appearance ----------------------------------------------------------

  /// Following the system's light or dark setting.
  static const IconData themeSystem = Icons.brightness_auto_outlined;

  /// The light palette.
  static const IconData themeLight = Icons.light_mode_outlined;

  /// The dark palette.
  static const IconData themeDark = Icons.dark_mode_outlined;

  // ---- about ---------------------------------------------------------------

  /// Developer, source and licensing information.
  static const IconData developer = Icons.code_outlined;

  /// Checking for and fetching a newer release.
  static const IconData download = Icons.system_update_alt_rounded;

  /// The moon and the sky strip.
  static const IconData moon = Icons.nightlight_outlined;

  // ---- actions -------------------------------------------------------------

  /// Adding an entry.
  static const IconData plus = Icons.add_rounded;

  /// A row's secondary actions.
  static const IconData more = Icons.more_horiz_rounded;

  /// An entry that is not yet done.
  static const IconData pending = Icons.radio_button_unchecked;

  // ---- sizes ---------------------------------------------------------------

  /// Default size, matched to the caption and label type sizes.
  static const double size = 18;

  /// Size for a standalone list row.
  static const double rowSize = 20;

  /// Size for an icon inside a button, where it sits beside a label.
  static const double buttonSize = 16;
}
