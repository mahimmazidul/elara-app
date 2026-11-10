import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../data/models/care_reminder.dart';
import '../../providers/reminders_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';

/// Adds or edits one thing to remember on one day.
///
/// The suggestions are the same practical ideas the rest of the app is built
/// around — supplies, an errand, an evening she would enjoy — and are only a
/// starting point: the field is free text and nothing is inferred into it.
class CareReminderEditor extends StatefulWidget {
  const CareReminderEditor({
    super.key,
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final CareReminder? existing;

  static Future<void> show(
    BuildContext context, {
    required DateTime initialDate,
    CareReminder? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CareReminderEditor(
        initialDate: initialDate,
        existing: existing,
      ),
    );
  }

  @override
  State<CareReminderEditor> createState() => _CareReminderEditorState();
}

class _CareReminderEditorState extends State<CareReminderEditor> {
  static const List<String> _suggestions = [
    'Restock supplies',
    'Something she likes for dinner',
    'A quiet evening at home',
    'Ask how the day went',
  ];

  late DateTime _date;
  late final TextEditingController _title;
  late final TextEditingController _note;
  late bool _done;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = dateOnly(existing?.date ?? widget.initialDate);
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _done = existing?.done ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Which day?',
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final reminders = context.read<RemindersProvider>();
    final existing = widget.existing;

    final ok = existing == null
        ? await reminders.add(
            date: _date,
            title: _title.text,
            note: _note.text,
          )
        : await reminders.update(
            existing.copyWith(
              date: _date,
              title: _title.text,
              note: _note.text.trim().isEmpty ? null : _note.text,
              done: _done,
              clearNote: _note.text.trim().isEmpty,
            ),
          );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = reminders.lastError ?? 'Could not save that.');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing?.id == null) return;
    await context.read<RemindersProvider>().delete(existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ElaraSpacing.lg,
            0,
            ElaraSpacing.lg,
            ElaraSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editing ? 'Edit this plan' : 'Plan something',
                style: type.title(tokens.textPrimary, size: 20),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                'A note for one day. Elara will not send this anywhere or draw '
                'any conclusion from it.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.lg),

              ElaraListRow(
                title: _formatDate(_date),
                subtitle: 'Tap to change the day',
                icon: ElaraIcons.calendar,
                onTap: _pickDate,
              ),
              const Hairline(margin: 0),
              const SizedBox(height: ElaraSpacing.md),

              TextField(
                controller: _title,
                autofocus: !_editing,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'What to remember',
                  hintText: 'Restock supplies',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Wrap(
                spacing: ElaraSpacing.sm,
                runSpacing: ElaraSpacing.sm,
                children: [
                  for (final suggestion in _suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => setState(() {
                        _title.text = suggestion;
                        _title.selection = TextSelection.collapsed(
                          offset: suggestion.length,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.md),

              TextField(
                controller: _note,
                maxLength: 140,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Any detail (optional)',
                  hintText: 'The one from the shop on the corner',
                ),
              ),

              if (_editing)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _done,
                  onChanged: (value) => setState(() => _done = value),
                  title: const Text('Already done'),
                  subtitle: const Text(
                    'Kept on the day so it is clear it was handled.',
                  ),
                ),

              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  if (_editing) ...[
                    TextButton(
                      onPressed: _delete,
                      child: Text(
                        'Remove',
                        style: TextStyle(color: tokens.dangerText),
                      ),
                    ),
                    const SizedBox(width: ElaraSpacing.sm),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_editing ? 'Save' : 'Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _formatDate(DateTime date) {
    final today = dateOnly(DateTime.now());
    if (date == today) return 'Today, ${date.day} ${_months[date.month - 1]}';
    if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${date.day} ${_months[date.month - 1]}';
    }
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}
