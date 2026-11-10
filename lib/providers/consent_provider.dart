import 'package:flutter/foundation.dart';

import '../data/models/consent_record.dart';
import '../data/database_helper.dart';

/// Where the user stands with respect to the consent gate.
enum ConsentState {
  /// The database has not answered yet; show neither the app nor the gate.
  unknown,

  /// Nothing has ever been decided. First run shows the setup screen.
  notAsked,

  /// The user declared that the woman whose data this is knows about the app
  /// and is content for it to be used.
  granted,

  /// Consent was withdrawn. Data has been deleted; the gate is shown again.
  revoked,

  /// An install that predates the consent log, holding cycle records but no
  /// record of anyone agreeing. The app asks for an acknowledgement before it
  /// will take new data, and never writes [ConsentAction.granted] on the user's
  /// behalf.
  legacyAcknowledgementDue,
}

/// Owns the consent decision and the append-only log behind it.
///
/// Two rules are enforced here rather than in the UI, because the UI is where
/// they would be forgotten:
///
///  * **[ConsentState.granted] is only ever written by an explicit user
///    action.** Nothing derives it from the presence of cycle rows.
///  * **Revoking deletes the health data first, then records the revocation.**
///    The log therefore never holds a row that says "revoked" while the cycles
///    it referred to are still on disk.
class ConsentProvider extends ChangeNotifier {
  ConsentProvider({DatabaseHelper? database})
    : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  ConsentState _state = ConsentState.unknown;
  ConsentRecord? _latest;
  bool _busy = false;
  String? _lastError;

  ConsentState get state => _state;
  ConsentRecord? get latest => _latest;
  bool get isBusy => _busy;
  String? get lastError => _lastError;

  /// True when the app may be shown. Only an explicit grant opens the app.
  bool get hasConsent => _state == ConsentState.granted;

  /// True when the state could not be read, as opposed to not yet read. The
  /// gate distinguishes the two so a storage failure is reported instead of
  /// leaving a blank screen.
  bool get hasFailed => _state == ConsentState.unknown && _lastError != null;

  /// True when the gate must be shown instead of the app.
  bool get needsGate =>
      _state != ConsentState.granted && _state != ConsentState.unknown;

  /// Reads the log and works out where the user stands.
  ///
  /// An install holding cycles but no consent row is [ConsentState
  /// .legacyAcknowledgementDue]. That is the whole upgrade path: the records
  /// are left untouched, and the user is asked rather than assumed.
  Future<void> load() async {
    try {
      final latest = await _database.getLatestConsentRecord();
      _latest = latest;

      if (latest == null) {
        final cycleCount = await _database.countCycles();
        _state = cycleCount > 0
            ? ConsentState.legacyAcknowledgementDue
            : ConsentState.notAsked;
      } else {
        _state = switch (latest.action) {
          ConsentAction.granted => ConsentState.granted,
          ConsentAction.revoked => ConsentState.revoked,
          // An acknowledgement is not a grant: it says the partner has talked
          // to her, and it stays visible in Settings as such. For the purposes
          // of opening the app it counts, because the alternative is to lock
          // someone out of their own data.
          ConsentAction.acknowledgedLegacy => ConsentState.granted,
        };
      }
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not read the consent record: $error';
      _state = ConsentState.unknown;
    }
    notifyListeners();
  }

  /// Records the user's declaration that this is a shared decision.
  ///
  /// Returns false if the write failed, leaving the gate in place.
  Future<bool> grant({required ConsentMethod method}) async {
    if (_busy) return false;
    return _write(ConsentAction.granted, method);
  }

  /// Records an upgrade acknowledgement: the partner has discussed the app with
  /// her. Distinct from [grant] in the log, so the history is not overstated.
  Future<bool> acknowledgeLegacy({required ConsentMethod method}) async {
    if (_busy) return false;
    return _write(ConsentAction.acknowledgedLegacy, method);
  }

  Future<bool> _write(ConsentAction action, ConsentMethod method) async {
    _busy = true;
    notifyListeners();
    try {
      final record = await _database.addConsentRecord(
        ConsentRecord(
          action: action,
          method: method,
          recordedAt: DateTime.now(),
        ),
      );
      _latest = record;
      _state = action == ConsentAction.revoked
          ? ConsentState.revoked
          : ConsentState.granted;
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Could not record that: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Withdraws consent and destroys the health data it referred to.
  ///
  /// Every table is cleared, including the settings, because a location and a
  /// notification history are part of what was handed over. The revocation row
  /// is written afterwards, so what survives is a note that a withdrawal
  /// happened and when — and nothing about her.
  Future<bool> revoke() async {
    if (_busy) return false;
    _busy = true;
    notifyListeners();
    try {
      await _database.resetAllData();
      final record = await _database.addConsentRecord(
        ConsentRecord(
          action: ConsentAction.revoked,
          method: ConsentMethod.settings,
          recordedAt: DateTime.now(),
        ),
      );
      _latest = record;
      _state = ConsentState.revoked;
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Could not withdraw consent: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Reloads after a restore has replaced the database contents.
  Future<void> reload() => load();
}
