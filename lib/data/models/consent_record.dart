import '../date_keys.dart';

/// What happened to consent, as an immutable event.
enum ConsentAction {
  /// The user declared that the woman whose data this is knows about the app
  /// and is content for it to be used.
  granted,

  /// Consent was withdrawn. Recorded after the health data has been deleted, so
  /// the row itself carries no cycle information.
  revoked,

  /// An existing install from before consent existed. The partner confirmed
  /// they have discussed it; this is deliberately *not* recorded as [granted],
  /// because the app never saw her agree.
  acknowledgedLegacy,
}

/// How the declaration was obtained, kept so the record is honest about itself.
enum ConsentMethod {
  /// Chosen during first-run setup.
  setup,

  /// Chosen on the screen shown after upgrading from a build without consent.
  upgrade,

  /// Chosen later from Settings.
  settings,
}

/// One row of `consent_records`: append-only, never edited.
///
/// The app never deletes these except through a full data reset, and a
/// revocation writes a fresh row rather than rewriting history, so the table is
/// always a truthful log of what the user was asked and what they answered.
class ConsentRecord {
  const ConsentRecord({
    this.id,
    required this.action,
    required this.method,
    required this.recordedAt,
  });

  final int? id;
  final ConsentAction action;
  final ConsentMethod method;
  final DateTime recordedAt;

  factory ConsentRecord.fromMap(Map<String, Object?> map) {
    return ConsentRecord(
      id: map['id'] as int?,
      action: ConsentAction.values.byName(map['action']! as String),
      method: ConsentMethod.values.byName(map['method']! as String),
      recordedAt: DateTime.parse(map['recorded_at']! as String),
    );
  }

  Map<String, Object?> toMap() => {
    'action': action.name,
    'method': method.name,
    'recorded_at': timestampKey(recordedAt),
  };

  @override
  String toString() => 'ConsentRecord(${action.name}, ${method.name})';
}
