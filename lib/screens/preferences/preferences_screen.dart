import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models/preference.dart';
import '../../providers/preferences_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../../widgets/elara_route.dart';

/// Preferences, in the two perspectives the brief asks for.
///
/// **(A) What you have noticed** — the holder's own observations. Labelled as
/// observations throughout; the app never promotes one to a fact about her. An
/// observation can be marked confirmed, but only after asking her, and the UI
/// says so rather than implying the app can verify it.
///
/// **(B) What she has said** — answers she writes herself. She chooses, per
/// answer, whether it is shared, and only shared answers reach the suggestions
/// on Today. The screen states plainly that the answers live in the same
/// database as everything else, so the person holding the phone can read them:
/// promising more than that would be a lie, because a single-device app with no
/// accounts has no way to enforce anything else.
///
/// Editing, deleting and sharing are all reachable from each row. Nothing here is
/// required, and an empty screen is a complete state, not an error.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  /// The route this screen is pushed with.
  ///
  /// It takes a [BuildContext] because the transition depends on the
  /// platform's animation setting, which is read at push time.
  static Route<void> route(BuildContext context) =>
      elaraRoute<void>(context, const PreferencesScreen(), name: 'preferences');

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final prefs = context.watch<PreferencesProvider>();

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      appBar: AppBar(
        title: const Text('Preferences'),
        backgroundColor: tokens.bgPrimary,
      ),
      body: ListView(
        // An AppBar already sits below the status bar.
        padding: ElaraSpacing.pageInsets(context, underStatusBar: false),
        children: [
          Text(
            'Two lists. What she has told you carries more weight than what '
            'you have noticed, and the suggestions on Today say which one they '
            'are using.',
            style: type.body(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.xl),

          // ---- her answers
          ElaraSection(
            title: 'What she has said',
            icon: ElaraIcons.talk,
            children: [
              Text(
                'She fills this in herself, and only if she wants to. Each '
                'answer can be kept private, and unshared answers stay out of '
                'the suggestions. Everything is stored on this phone, so '
                'whoever holds the phone can open this screen. Elara keeps it '
                'out of sight and says so here rather than pretending '
                'otherwise.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.md),
              if (prefs.herAnswers.isEmpty)
                _Empty(
                  message:
                      'Answers land here. Hand her the phone, or open the '
                      'questionnaire together.',
                )
              else
                for (final preference in prefs.herAnswers) ...[
                  _PreferenceRow(preference: preference, herPerspective: true),
                  const Hairline(margin: 0),
                ],
              const SizedBox(height: ElaraSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _openEditor(context, source: PreferenceSource.herAnswer),
                  icon: const Icon(ElaraIcons.plus, size: ElaraIcons.size),
                  label: const Text('Add an answer she gave'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xxl),

          // ---- observations
          ElaraSection(
            title: 'What you have noticed',
            icon: ElaraIcons.observation,
            children: [
              Text(
                'Your own notes. They are observations you have made, not as '
                'facts about her. She decides whether they are true, and they '
                'rank below anything she has said.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.md),
              if (prefs.observations.isEmpty)
                _Empty(
                  message:
                      'Nothing recorded yet. Foods she likes, comforts that '
                      'help, small gestures, things to avoid. Anything you '
                      'have noticed.',
                )
              else
                for (final preference in prefs.observations) ...[
                  _PreferenceRow(preference: preference, herPerspective: false),
                  const Hairline(margin: 0),
                ],
              const SizedBox(height: ElaraSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openEditor(
                    context,
                    source: PreferenceSource.partnerObservation,
                  ),
                  icon: const Icon(ElaraIcons.plus, size: ElaraIcons.size),
                  label: const Text('Add an observation'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xxl),

          Text(
            'Elara uses these only to suggest things to do. Nothing here is '
            'scored, and no answer changes what the calendar shows.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    required PreferenceSource source,
    Preference? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PreferenceEditor(source: source, existing: existing),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Text(message, style: context.type.body(tokens.textSecondaryStrong));
  }
}

/// One stored preference: category, the value, and where it came from.
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.preference,
    required this.herPerspective,
  });

  final Preference preference;
  final bool herPerspective;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final prefs = context.read<PreferencesProvider>();

    // Her answers are confirmed by definition; an observation is only confirmed
    // once she has agreed with it.
    final status = preference.isHerOwn
        ? (preference.shared ? 'Shared with you' : 'Kept private')
        : preference.status.label;

    return ElaraListRow(
      title: preference.value,
      subtitle:
          '${preference.category.label} · ${preference.source.label} · '
          '$status',
      icon: herPerspective ? ElaraIcons.confirmed : ElaraIcons.observation,
      onTap: () => PreferencesScreen._openEditor(
        context,
        source: preference.source,
        existing: preference,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        icon: Icon(
          ElaraIcons.more,
          size: ElaraIcons.rowSize,
          color: tokens.textSecondaryStrong,
        ),
        onSelected: (action) async {
          switch (action) {
            case 'share':
              await prefs.setShared(preference, !preference.shared);
            case 'confirm':
              await prefs.confirm(preference);
            case 'delete':
              final confirmed = await _confirmDelete(context);
              if (confirmed) await prefs.delete(preference.id!);
          }
        },
        itemBuilder: (_) => [
          if (preference.isHerOwn)
            PopupMenuItem(
              value: 'share',
              child: Text(
                preference.shared ? 'Keep private' : 'Share with you',
              ),
            ),
          if (!preference.isHerOwn &&
              preference.status == PreferenceStatus.unconfirmed)
            const PopupMenuItem(
              value: 'confirm',
              child: Text('She confirmed this'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('Remove')),
        ],
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this?'),
        content: const Text(
          'It will stop being used for suggestions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Add or edit one entry.
class _PreferenceEditor extends StatefulWidget {
  const _PreferenceEditor({required this.source, this.existing});

  final PreferenceSource source;
  final Preference? existing;

  @override
  State<_PreferenceEditor> createState() => _PreferenceEditorState();
}

class _PreferenceEditorState extends State<_PreferenceEditor> {
  late final TextEditingController _controller;
  late PreferenceCategory _category;
  late bool _shared;
  late bool _confirmed;
  String? _error;

  bool get _isHerAnswer => widget.source == PreferenceSource.herAnswer;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _controller = TextEditingController(text: existing?.value ?? '');
    _category = existing?.category ?? PreferenceCategory.food;
    _shared = existing?.shared ?? true;
    _confirmed = existing?.status == PreferenceStatus.confirmed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = context.read<PreferencesProvider>();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something first.');
      return;
    }

    final existing = widget.existing;
    final ok = existing != null
        ? await prefs.update(
            existing.copyWith(
              category: _category,
              value: text,
              shared: _isHerAnswer ? _shared : existing.shared,
              status: _isHerAnswer
                  ? existing.status
                  : (_confirmed
                        ? PreferenceStatus.confirmed
                        : PreferenceStatus.unconfirmed),
            ),
          )
        : _isHerAnswer
        ? await prefs.addHerAnswer(
            category: _category,
            value: text,
            share: _shared,
          )
        : await prefs.addObservation(
            category: _category,
            value: text,
            confirmedByHer: _confirmed,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = prefs.lastError ?? 'Could not save that.');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final prefs = context.read<PreferencesProvider>();
    await prefs.delete(existing.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final editing = widget.existing != null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ElaraSpacing.lg,
            0,
            ElaraSpacing.lg,
            ElaraSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editing
                    ? 'Edit'
                    : _isHerAnswer
                    ? 'An answer from her'
                    : 'Something you noticed',
                style: type.title(tokens.textPrimary, size: 20),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                _isHerAnswer
                    ? 'Only write what she actually said. You can mark it '
                          'private if she does not want it used.'
                    : 'Phrase it as something you observed. Whether it is true '
                          'is for her to say.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.lg),

              TextField(
                controller: _controller,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'What it is',
                  hintText: _hintFor(_category),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: ElaraSpacing.sm),

              Text('Kind', style: type.label(tokens.textSecondaryStrong)),
              const SizedBox(height: ElaraSpacing.sm),
              Wrap(
                spacing: ElaraSpacing.sm,
                runSpacing: ElaraSpacing.sm,
                children: [
                  for (final category in PreferenceCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.lg),

              if (_isHerAnswer)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _shared,
                  onChanged: (value) => setState(() => _shared = value),
                  title: const Text('Share this with you'),
                  subtitle: const Text(
                    'Off means Elara will not use it for suggestions.',
                  ),
                )
              else
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: (value) => setState(() => _confirmed = value),
                  title: const Text('She confirmed this'),
                  subtitle: const Text(
                    'Only switch this on if she has actually agreed with it.',
                  ),
                ),

              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  if (editing) ...[
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
                      child: Text(editing ? 'Save' : 'Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hintFor(PreferenceCategory category) {
    switch (category) {
      case PreferenceCategory.food:
        return 'Khichuri, warm, no chilli';
      case PreferenceCategory.activity:
        return 'Long walks in the evening';
      case PreferenceCategory.comfort:
        return 'Hot water bottle, the grey blanket';
      case PreferenceCategory.gesture:
        return 'A note left on the table';
      case PreferenceCategory.avoid:
        return 'Being asked to decide when tired';
      case PreferenceCategory.dateIdea:
        return 'Small cafés instead of big dinners';
      case PreferenceCategory.note:
        return 'Anything else worth remembering';
    }
  }
}
