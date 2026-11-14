import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../data/models/symptom.dart';
import '../../providers/symptoms_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';

/// The glyph for each symptom.
///
/// One icon per kind, at one size, used in the logger, the list and the calendar
/// markers, so a symptom is recognisable before its label is read.
IconData iconForSymptom(SymptomKind kind) {
  switch (kind) {
    case SymptomKind.cramps:
      return ElaraIcons.pain;
    case SymptomKind.headache:
      return ElaraIcons.mood;
    case SymptomKind.fatigue:
      return ElaraIcons.energy;
    case SymptomKind.bloating:
      return ElaraIcons.other;
    case SymptomKind.nausea:
      return ElaraIcons.symptomGeneral;
    case SymptomKind.breastTenderness:
      return ElaraIcons.sleep;
    case SymptomKind.moodChange:
      return ElaraIcons.cloud;
    case SymptomKind.bleeding:
      return ElaraIcons.water;
  }
}

/// Logs or edits one symptom on one day.
///
/// Optional and light: the sheet opens defaulted to today and to the kind that
/// was tapped, takes a severity on three buttons, and closes. Nothing is
/// required, nothing is scored, and the wording never suggests a cause — a
/// headache is a headache, not evidence about a phase.
class SymptomEditor extends StatefulWidget {
  const SymptomEditor({
    super.key,
    this.existing,
    this.initialDate,
    this.initialKind,
  });

  /// Edits this row instead of creating one.
  final Symptom? existing;
  final DateTime? initialDate;
  final SymptomKind? initialKind;

  static Future<void> show(
    BuildContext context, {
    Symptom? existing,
    DateTime? initialDate,
    SymptomKind? initialKind,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SymptomEditor(
        existing: existing,
        initialDate: initialDate,
        initialKind: initialKind,
      ),
    );
  }

  @override
  State<SymptomEditor> createState() => _SymptomEditorState();
}

class _SymptomEditorState extends State<SymptomEditor> {
  late DateTime _date;
  late SymptomKind _kind;
  late int _severity;
  late final TextEditingController _note;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ??
        dateOnly(widget.initialDate ?? DateTime.now());
    _kind = existing?.kind ?? widget.initialKind ?? SymptomKind.cramps;
    _severity = existing?.severity ?? 2;
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A symptom is something that has happened. Logging one for a future day
      // would turn a record into a prediction.
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      helpText: 'Which day?',
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final symptoms = context.read<SymptomsProvider>();
    final ok = await symptoms.log(
      date: _date,
      kind: _kind,
      severity: _severity,
      note: _note.text,
      replacing: widget.existing,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = symptoms.lastError ?? 'Could not save that.');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing?.id == null) return;
    final symptoms = context.read<SymptomsProvider>();
    await symptoms.delete(existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                _editing ? 'Edit this record' : 'Record a symptom',
                style: type.title(tokens.textPrimary, size: 20),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                'Optional. A note of what she reported, kept as what was '
                'said rather than as an assessment; Elara will not guess at a '
                'cause.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.lg),

              // ---- day
              ElaraListRow(
                title: _formatDate(_date),
                subtitle: 'Tap to change the day',
                icon: ElaraIcons.calendar,
                onTap: _pickDate,
              ),
              const Hairline(margin: 0),

              const SizedBox(height: ElaraSpacing.md),
              ElaraOverline('What'),
              const SizedBox(height: ElaraSpacing.sm),
              Wrap(
                spacing: ElaraSpacing.sm,
                runSpacing: ElaraSpacing.sm,
                children: [
                  for (final kind in SymptomKind.values)
                    ChoiceChip(
                      avatar: Icon(iconForSymptom(kind), size: 16),
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),

              const SizedBox(height: ElaraSpacing.lg),
              ElaraOverline(_kind.isFlow ? 'How heavy' : 'How bad'),
              const SizedBox(height: ElaraSpacing.sm),
              Wrap(
                spacing: ElaraSpacing.sm,
                children: [
                  for (final (value, label) in [
                    (1, _kind.scaleLow),
                    (2, _kind.scaleMid),
                    (3, _kind.scaleHigh),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _severity == value,
                      onSelected: (_) => setState(() => _severity = value),
                    ),
                ],
              ),

              const SizedBox(height: ElaraSpacing.lg),
              TextField(
                controller: _note,
                maxLength: 140,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'A note (optional)',
                  hintText: 'Worse in the evening, helped by a hot pad',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: ElaraSpacing.xs),
                Text(
                  _error!,
                  style: type.caption(tokens.dangerText),
                ),
              ],

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
                      child: Text(_editing ? 'Save' : 'Record'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Not now'),
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
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${date.day} ${_months[date.month - 1]}';
    }
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}
