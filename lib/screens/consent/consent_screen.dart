import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/consent_record.dart';
import '../../providers/consent_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';

/// The screen that has to be answered before Elara holds anyone's data.
///
/// Three situations bring a person here:
///
///  * **First run.** Nothing has been decided and nothing is stored.
///  * **An upgrade from a build without consent.** Cycle records exist but no
///    record of anyone agreeing does. Both routes out are honest: acknowledge
///    that the conversation has happened, or remove the records.
///  * **After a revocation.** The data is gone; this is the way back in.
///
/// The wording is doing real work, so it avoids three traps. It does not claim
/// that tapping a button means she consented — it records that *he* says they
/// talked. It does not describe the data as belonging to the phone. And it gives
/// the destructive option equal standing, because a screen that only offers
/// "agree" is not a choice.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.state});

  final ConsentState state;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _busy = false;
  String? _error;

  bool get _isUpgrade => widget.state == ConsentState.legacyAcknowledgementDue;
  bool get _isRevoked => widget.state == ConsentState.revoked;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final consent = context.read<ConsentProvider>();

    // An upgrade acknowledgement and a fresh grant are recorded as different
    // events, because they mean different things. Both are explicit.
    final ok = _isUpgrade
        ? await consent.acknowledgeLegacy(method: ConsentMethod.upgrade)
        : await consent.grant(method: ConsentMethod.setup);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : consent.lastError;
    });
  }

  Future<void> _deleteInstead() async {
    if (!_isUpgrade) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmDeleteDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final consent = context.read<ConsentProvider>();
    final ok = await consent.revoke();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : consent.lastError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Scaffold(
      backgroundColor: tokens.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ElaraSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ElaraCard(
                padding: const EdgeInsets.all(ElaraSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isUpgrade ? 'One thing first' : 'Before you start',
                      style: type.headline(tokens.textPrimary, size: 24),
                    ),
                    const SizedBox(height: ElaraSpacing.md),
                    Text(_intro, style: type.body(tokens.textSecondaryStrong)),
                    const SizedBox(height: ElaraSpacing.lg),

                    const _Point(
                      icon: Icons.lock_outline_rounded,
                      text:
                          'Cycle dates stay in this app on this phone. There '
                          'is no account and no server.',
                    ),
                    const SizedBox(height: ElaraSpacing.sm),
                    _Point(
                      icon: Icons.people_outline_rounded,
                      text: _isUpgrade
                          ? 'These dates were entered by someone else, so '
                                'Elara will not assume they were agreed to.'
                          : 'This is a shared decision. Elara works best when '
                                'she knows it exists and is happy for it to be '
                                'used.',
                    ),
                    const SizedBox(height: ElaraSpacing.sm),
                    const _Point(
                      icon: Icons.undo_rounded,
                      text:
                          'You can withdraw this at any time from Settings, '
                          'which also deletes what is stored.',
                    ),

                    const SizedBox(height: ElaraSpacing.xl),
                    if (_error != null) ...[
                      Text(_error!, style: type.caption(tokens.dangerText)),
                      const SizedBox(height: ElaraSpacing.md),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _confirm,
                        child: _busy
                            ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: tokens.onPhase,
                                ),
                              )
                            : Text(_primaryLabel),
                      ),
                    ),
                    if (_isUpgrade) ...[
                      const SizedBox(height: ElaraSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _busy ? null : _deleteInstead,
                          child: Text(
                            'Delete the records instead',
                            style: type.subtitle(tokens.textSecondaryStrong),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: ElaraSpacing.md),
                    Text(
                      _footnote,
                      style: type.caption(tokens.textSecondaryStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _intro {
    if (_isUpgrade) {
      return 'Elara now asks who this data is about. There are already period '
          'dates recorded on this phone, and they have been kept. Nothing has '
          'been assumed from them.';
    }
    if (_isRevoked) {
      return 'Consent was withdrawn and the stored data was deleted. Elara '
          'will not record anything until you decide again.';
    }
    return 'Elara keeps a record of a menstrual cycle to help a partner offer '
        'better care. That is someone else\u2019s health information, so it '
        'asks before it starts.';
  }

  String get _primaryLabel {
    if (_isUpgrade) return 'We have talked about it';
    if (_isRevoked) return 'Start again';
    return 'She knows, and this is fine';
  }

  String get _footnote {
    if (_isUpgrade) {
      return 'This records that you said you have talked with her. Elara '
          'cannot verify that, and does not treat it as her consent.';
    }
    return 'Elara cannot check this. It stores your word and the date, so the '
        'question is not asked again by accident.';
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: tokens.textSecondaryStrong),
        ),
        const SizedBox(width: ElaraSpacing.md),
        Expanded(
          child: Text(
            text,
            style: context.type.body(tokens.textSecondaryStrong),
          ),
        ),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return AlertDialog(
      backgroundColor: tokens.bgCard,
      surfaceTintColor: tokens.transparent,
      title: Text(
        'Delete the recorded periods?',
        style: type.title(tokens.textPrimary, size: 18),
      ),
      content: Text(
        'The cycle dates stored on this phone will be deleted and the '
        'notification schedule cleared. This cannot be undone.',
        style: type.body(tokens.textSecondaryStrong),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep them'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Delete',
            style: type.subtitle(tokens.dangerText, size: 14),
          ),
        ),
      ],
    );
  }
}
