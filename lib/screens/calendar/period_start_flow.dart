import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';

/// Records a period start, on the day it happened rather than the day you
/// remembered.
///
/// This used to write today's date and nothing else, so a start that began three
/// days ago could not be entered at all. The alternative was to log it today and
/// be wrong by three days, and every estimate afterwards would carry that error.
/// A picker with today already selected costs one tap in the common case and
/// fixes the case that matters.
///
/// It lives here rather than inside [CalendarScreen] because the calendar's
/// header button is no longer the only way in: the shell's centre action offers
/// it from every tab. The two must write the same row the same way, so they call
/// the same function.
Future<void> logPeriodStart(BuildContext context) async {
  final cycles = context.read<CycleProvider>();
  final prediction = context.read<PredictionProvider>();
  final today = dateOnly(DateTime.now());

  final picked = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: DateTime(today.year - 2, today.month, today.day),
    lastDate: today,
    helpText: 'Which day did it start?',
  );
  if (picked == null || !context.mounted) return;

  final start = dateOnly(picked);
  final stored = await cycles.addCycle(startDate: start);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        stored == null
            ? (cycles.lastError ?? 'Could not log the period start.')
            : 'Logged ${formatShortDate(start)} as a period start.',
      ),
    ),
  );

  if (stored != null) {
    // The provider graph also reacts to the revision bump; forcing here keeps
    // the calendar in step even if that path is still mid-frame.
    await prediction.refresh();
  }
}

/// `12 Nov 2026`: the form used wherever a date sits inside a sentence.
///
/// Short month names, because a full one turns a snackbar and a line of caption
/// text into two lines on a 320dp phone. The month list is spelled out rather
/// than taken from `intl`, so the app formats dates the same way with no locale
/// data loaded and no dependency on the device's language.
const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatShortDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1].substring(0, 3)} ${date.year}';
