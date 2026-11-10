import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/consent_record.dart';
import '../../providers/consent_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/icons.dart';

/// The "Privacy and data" card behind Settings: consent, export, restore, delete.
///
/// Kept in its own file because it is the one part of the app whose job is to
/// let the user take things away, and that deserves to be readable on its own.
///
/// Three design rules, all of them about not making the destructive or the
/// revealing path the easy one by accident:
///
///  * **Export is always encrypted** and the passphrase is never stored, so the
///    file is only as exposed as the user's choice of where to put it.
///  * **Restore replaces, and says so first.** The confirmation names the number
///    of periods currently stored, so nobody overwrites a year of history by
///    accident.
///  * **Deletion is behind a typed confirmation.** It removes the cycles, the
///    settings and the consent record, and it is the only control here that
///    cannot be undone from inside the app.
class PrivacyDataSection extends StatefulWidget {
  const PrivacyDataSection({super.key});

  @override
  State<PrivacyDataSection> createState() => _PrivacyDataSectionState();
}

class _PrivacyDataSectionState extends State<PrivacyDataSection> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final consent = context.watch<ConsentProvider>();
    final cycles = context.watch<CycleProvider>();
    final settings = context.watch<SettingsProvider>();

    return ElaraGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- consent status
          Row(
            children: [
              Expanded(
                child: Text(
                  'Consent',
                  style: type.subtitle(tokens.textPrimary, size: 14),
                ),
              ),
              const SizedBox(width: ElaraSpacing.md),
              _StatusPill(
                label: consent.hasConsent ? 'Recorded' : 'Not recorded',
                good: consent.hasConsent,
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            _consentSummary(consent),
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.md),
          // The action states what it does, in full, and then the control that
          // does it is a single short label.
          //
          // It used to be an outlined button carrying the entire sentence,
          // centred, inside a full-width box. The sentence wrapped after
          // "delete", so the second line held one word with empty space either
          // side of it, and an outlined control is the visual language of a
          // secondary action — which this is not. The label above is the
          // sentence; the button is filled, one line, and unmistakably the
          // destructive one.
          Text(
            'Withdraw consent and delete everything',
            style: type.bodyStrong(tokens.dangerText, size: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'Removes every recorded period, the settings and the consent '
            'record from this phone. It cannot be undone.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _working ? null : () => _revoke(context),
              icon: const Icon(ElaraIcons.delete, size: 18),
              label: const Text('Delete everything'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.dangerText,
                foregroundColor: tokens.bgCard,
                disabledBackgroundColor: tokens.divider,
                textStyle: const TextStyle(
                  fontFamily: 'Hind Siliguri',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ElaraRadii.chip),
                ),
              ),
            ),
          ),

          const _Hairline(),

          // ---- notification privacy
          Text(
            'Notification privacy',
            style: type.subtitle(tokens.textPrimary, size: 14),
          ),
          const SizedBox(height: 2),
          Text(
            settings.notifyPreviewDetails
                ? 'Reminders can name the phase and the cycle day.'
                : 'Reminders say only that there is a note waiting.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Show cycle details in reminders',
                  style: type.body(tokens.textPrimary, size: 14),
                ),
              ),
              const SizedBox(width: ElaraSpacing.md),
              Switch.adaptive(
                value: settings.notifyPreviewDetails,
                onChanged: (value) async {
                  await context
                      .read<SettingsProvider>()
                      .setNotifyPreviewDetails(value);
                  if (!context.mounted) return;
                  // Rebuild the schedule so text already queued under the old
                  // choice is replaced rather than shown tomorrow morning.
                  await _reschedule(context);
                },
                activeTrackColor: tokens.accent,
                activeThumbColor: tokens.bgCard,
                inactiveTrackColor: tokens.track,
                inactiveThumbColor: tokens.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            'Off by default. Android is also told to treat every reminder as '
            'private, so the text stays off the lock screen either way.',
            style: type.caption(tokens.textSecondaryStrong),
          ),

          const _Hairline(),

          // ---- backup
          Text('Backup', style: type.subtitle(tokens.textPrimary, size: 14)),
          const SizedBox(height: 2),
          Text(
            'Exports ${_periodCount(cycles.count)} as an encrypted file. Only '
            'the dates are included: no location, no settings.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _working || cycles.isEmpty
                      ? null
                      : () => _export(context),
                  child: const Text('Export'),
                ),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => _restore(context),
                  child: const Text('Restore'),
                ),
              ),
            ],
          ),

          const _Hairline(),

          // ---- the limit, stated rather than implied
          Text(
            'On this phone',
            style: type.subtitle(tokens.textPrimary, size: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'The database itself is not encrypted at rest: it relies on the '
            'phone\'s own app sandbox and device encryption. That protects it '
            'from other apps and from a stolen, locked phone, but not from '
            'someone holding this phone unlocked. Exports are encrypted; the '
            'stored history is not.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }

  String _consentSummary(ConsentProvider consent) {
    final record = consent.latest;
    if (record == null) {
      return 'No decision has been recorded on this device.';
    }
    final when = _formatDate(record.recordedAt);
    return switch (record.action) {
      ConsentAction.granted =>
        'You confirmed on $when that she knows about Elara.',
      ConsentAction.acknowledgedLegacy =>
        'On $when you confirmed you had spoken with her about Elara. This is '
            'your acknowledgement, not a record of her agreeing.',
      ConsentAction.revoked =>
        'Consent was withdrawn on $when and the data was deleted.',
    };
  }

  // ------------------------------------------------------------- operations --

  Future<void> _export(BuildContext context) async {
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(),
    );
    if (passphrase == null || !context.mounted) return;

    setState(() => _working = true);
    final backup = context.read<BackupService>();
    try {
      final contents = await backup.exportToString(passphrase: passphrase);
      if (!context.mounted) return;

      final name = 'elara-backup-${_formatFileDate(DateTime.now())}.elara.txt';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(contents.codeUnits),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          subject: 'Elara backup',
          text: 'Encrypted Elara backup. It needs your passphrase to open.',
        ),
      );
      if (!context.mounted) return;
      _snack(context, 'Backup ready. Keep the passphrase somewhere safe.');
    } on BackupException catch (error) {
      if (!context.mounted) return;
      _snack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, 'Could not create the backup: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final restored = await showDialog<bool>(
      context: context,
      builder: (_) => const _RestoreDialog(),
    );
    if (restored != true || !context.mounted) return;

    // Everything derived from the old history is stale now.
    await context.read<CycleProvider>().load();
    if (!context.mounted) return;
    await context.read<PredictionProvider>().refresh();
    if (!context.mounted) return;
    await _reschedule(context);
    if (!context.mounted) return;
    _snack(context, 'History restored.');
  }

  Future<void> _revoke(BuildContext context) async {
    // Capture everything the operation needs before the first await, so no
    // BuildContext is used across an async gap.
    final consent = context.read<ConsentProvider>();
    final cycles = context.read<CycleProvider>();
    final settings = context.read<SettingsProvider>();
    final rescheduler = context.read<NotificationRescheduler>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _TypedConfirmDialog(
        title: 'Withdraw consent?',
        message:
            'This deletes every recorded period, the settings and the '
            'consent record on this phone, and clears the reminder schedule. '
            'Elara will ask again before storing anything new. It cannot be '
            'undone.',
        word: 'withdraw',
        action: 'Withdraw',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);

    // Cancel reminders first: a queued notification can still fire between the
    // wipe and the next resume, and it would name a cycle that no longer exists.
    try {
      await rescheduler.reschedule();
    } catch (_) {
      // Scheduling must never block a deletion the user asked for.
    }

    final ok = await consent.revoke();
    if (!mounted) return;

    if (!ok) {
      setState(() => _working = false);
      messenger.showSnackBar(
        SnackBar(content: Text(consent.lastError ?? 'Could not withdraw.')),
      );
      return;
    }

    // Re-read the emptied database so the app is consistent if consent is
    // granted again without a restart.
    await cycles.load();
    await settings.load();
    if (!mounted) return;
    setState(() => _working = false);
  }

  /// Cancels everything queued, then rebuilds the schedule from current data.
  Future<void> _reschedule(BuildContext context) async {
    try {
      await context.read<NotificationRescheduler>().reschedule();
    } catch (_) {
      // A scheduling failure must not block a deletion or a restore.
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _periodCount(int count) {
    if (count == 0) return 'no recorded periods';
    if (count == 1) return '1 recorded period';
    return '$count recorded periods';
  }

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatFileDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ElaraSpacing.sm,
        vertical: ElaraSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tokens.bgPrimary,
        borderRadius: BorderRadius.circular(ElaraRadii.chip),
        border: Border.all(color: tokens.divider),
      ),
      child: Text(
        label,
        style: context.type.label(
          good ? tokens.successText : tokens.warningText,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: ElaraSpacing.md),
      color: context.elara.divider,
    );
  }
}

/// Asks for a passphrase twice, because a backup locked with a typo is a backup
/// nobody can open, and there is no reset.
class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog();

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pass = _pass.text;
    if (pass.trim().length < BackupService.minPassphraseLength) {
      setState(
        () => _error =
            'Use at least ${BackupService.minPassphraseLength} characters.',
      );
      return;
    }
    if (pass != _confirm.text) {
      setState(() => _error = 'The two passphrases do not match.');
      return;
    }
    Navigator.of(context).pop(pass);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return AlertDialog(
      backgroundColor: tokens.bgCard,
      surfaceTintColor: tokens.transparent,
      title: Text(
        'Encrypt the backup',
        style: type.title(tokens.textPrimary, size: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The file holds dates, so it is encrypted. Elara does not keep '
              'this passphrase: if it is lost, the backup cannot be opened.',
              style: type.body(tokens.textSecondaryStrong),
            ),
            const SizedBox(height: ElaraSpacing.md),
            _passField(
              context,
              controller: _pass,
              label: 'Passphrase',
              autofocus: true,
            ),
            const SizedBox(height: ElaraSpacing.sm),
            _passField(
              context,
              controller: _confirm,
              label: 'Repeat passphrase',
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: ElaraSpacing.sm),
              Text(_error!, style: type.caption(tokens.dangerText)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create file')),
      ],
    );
  }

  Widget _passField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    final tokens = context.elara;
    return TextField(
      controller: controller,
      obscureText: _obscure,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      style: context.type.body(tokens.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.type.label(tokens.textSecondaryStrong),
        filled: true,
        fillColor: tokens.bgPrimary,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? ElaraIcons.reveal
                : ElaraIcons.hide,
            size: 18,
            color: tokens.textSecondaryStrong,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Show passphrase' : 'Hide passphrase',
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
          borderSide: BorderSide(color: tokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElaraRadii.chip),
          borderSide: BorderSide(color: tokens.divider),
        ),
      ),
    );
  }
}

/// Paste a backup, decrypt it, look at what it holds, and only then apply it.
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _contents = TextEditingController();
  final _pass = TextEditingController();
  RestorePreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _contents.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _decrypt() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final backup = context.read<BackupService>();
    try {
      final preview = await backup.preview(
        contents: _contents.text,
        passphrase: _pass.text,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _busy = false;
      });
    } on BackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read that backup: $error';
        _busy = false;
      });
    }
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() => _busy = true);
    final backup = context.read<BackupService>();
    try {
      await backup.apply(preview);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not restore: $error';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final preview = _preview;

    return AlertDialog(
      backgroundColor: tokens.bgCard,
      surfaceTintColor: tokens.transparent,
      title: Text(
        'Restore a backup',
        style: type.title(tokens.textPrimary, size: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview == null) ...[
              Text(
                'Paste the contents of the backup file, then its passphrase.',
                style: type.body(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.md),
              TextField(
                controller: _contents,
                minLines: 3,
                maxLines: 5,
                style: type.caption(tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Backup contents',
                  labelStyle: type.label(tokens.textSecondaryStrong),
                  filled: true,
                  fillColor: tokens.bgPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                ),
              ),
              const SizedBox(height: ElaraSpacing.sm),
              TextField(
                controller: _pass,
                obscureText: true,
                style: type.body(tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  labelStyle: type.label(tokens.textSecondaryStrong),
                  filled: true,
                  fillColor: tokens.bgPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ElaraRadii.chip),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'This backup holds ${preview.cycles.length} '
                '${preview.cycles.length == 1 ? 'period' : 'periods'}'
                '${_range(preview)}.',
                style: type.body(tokens.textPrimary),
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                preview.existingCount == 0
                    ? 'Nothing is stored on this phone, so nothing is lost.'
                    : 'Restoring replaces the ${preview.existingCount} '
                          '${preview.existingCount == 1 ? 'period' : 'periods'} '
                          'stored on this phone. They are not merged.',
                style: type.body(tokens.textSecondaryStrong),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: ElaraSpacing.sm),
              Text(_error!, style: type.caption(tokens.dangerText)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (preview == null)
          TextButton(
            onPressed: _busy ? null : _decrypt,
            child: const Text('Open'),
          )
        else
          TextButton(
            onPressed: _busy ? null : _apply,
            child: const Text('Replace history'),
          ),
      ],
    );
  }

  static String _range(RestorePreview preview) {
    final first = preview.firstStart;
    final last = preview.lastStart;
    if (first == null || last == null) return '';
    final f = _short(first);
    final l = _short(last);
    return f == l ? ', $f' : ', from $f to $l';
  }

  static String _short(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// A confirmation that requires typing a word, for the operations that cannot
/// be undone.
class _TypedConfirmDialog extends StatefulWidget {
  const _TypedConfirmDialog({
    required this.title,
    required this.message,
    required this.word,
    required this.action,
  });

  final String title;
  final String message;
  final String word;
  final String action;

  @override
  State<_TypedConfirmDialog> createState() => _TypedConfirmDialogState();
}

class _TypedConfirmDialogState extends State<_TypedConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim().toLowerCase() == widget.word;
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return AlertDialog(
      backgroundColor: tokens.bgCard,
      surfaceTintColor: tokens.transparent,
      title: Text(
        widget.title,
        style: type.title(tokens.textPrimary, size: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: type.body(tokens.textSecondaryStrong)),
            const SizedBox(height: ElaraSpacing.md),
            Text(
              'Type ${widget.word} to continue.',
              style: type.caption(tokens.textSecondaryStrong),
            ),
            const SizedBox(height: ElaraSpacing.sm),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              style: type.body(tokens.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: tokens.bgPrimary,
                hintText: widget.word,
                hintStyle: type.body(tokens.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ElaraRadii.chip),
                  borderSide: BorderSide(color: tokens.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ElaraRadii.chip),
                  borderSide: BorderSide(color: tokens.divider),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            widget.action,
            style: type.subtitle(
              _matches ? tokens.dangerText : tokens.textSecondaryStrong,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}
