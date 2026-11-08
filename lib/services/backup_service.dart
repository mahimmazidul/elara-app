import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/models/cycle_entry.dart';

/// Raised when a backup cannot be read, with a message meant for the user.
class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a restored backup did.
class RestoreSummary {
  const RestoreSummary({
    required this.cyclesRestored,
    required this.exportedAt,
  });

  final int cyclesRestored;
  final DateTime? exportedAt;

  @override
  String toString() =>
      'RestoreSummary($cyclesRestored cycles, exported $exportedAt)';
}

/// Builds, encrypts, decrypts and applies Elara backups.
///
/// Shape of a backup:
///
/// ```json
/// {"format":"elara-backup","version":1,"kdf":{...},"cipher":"AES-256-GCM",
///  "nonce":"...","ciphertext":"...","mac":"..."}
/// ```
///
/// Two decisions carry the privacy story:
///
///  * **The file is always encrypted.** There is no "plain" mode to talk
///    someone into. A backup of cycle dates left in a shared folder or a chat
///    thread is the same disclosure as a screenshot of the app.
///  * **Nothing but cycle dates is exported.** No location, no notification
///    settings, no consent log. A restore therefore cannot quietly re-enable a
///    reminder or overwrite a decision, and the backup reveals only what it must.
///
/// The passphrase is never stored, never logged, and never leaves the process.
class BackupService {
  BackupService({
    DatabaseHelper? database,
    DateTime Function()? clock,
    Random? random,
  }) : _database = database ?? DatabaseHelper.instance,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final DatabaseHelper _database;
  final DateTime Function() _clock;

  /// Only salt and nonce come from here, and both may be public. The platform's
  /// secure generator is used so a repeated nonce — the one failure that breaks
  /// AES-GCM completely — is impossible in practice.
  final Random _random;

  /// Version of the *file format*, independent of the database schema. A future
  /// build can read format 1 and still write format 1 until it must change.
  static const int formatVersion = 1;

  static const String _magic = 'elara-backup';

  /// PBKDF2 iterations. Chosen so a passphrase that is merely short is still
  /// expensive to attack offline, without a visible pause on a mid-range phone.
  static const int pbkdf2Iterations = 210000;

  static const int _keyBits = 256;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;

  /// Minimum passphrase length. Long rather than complicated: length is what
  /// actually helps a key that is stretched this way.
  static const int minPassphraseLength = 10;

  AesGcm get _algorithm => AesGcm.with256bits();

  // ---------------------------------------------------------------- export --

  /// Serialises the current history and encrypts it under [passphrase].
  ///
  /// Returns the file contents, ready to be shared or copied. Throws
  /// [BackupException] if the passphrase is unusable or nothing is stored.
  Future<String> exportToString({required String passphrase}) async {
    _validatePassphrase(passphrase);

    final cycles = await _database.getAllCycles();
    if (cycles.isEmpty) {
      throw BackupException('There is nothing to back up yet.');
    }

    final payload = jsonEncode({
      'format': _magic,
      'version': formatVersion,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'cycles': [
        for (final cycle in cycles)
          {
            'startDate': _dateKey(cycle.startDate),
            if (cycle.duration != null) 'duration': cycle.duration,
          },
      ],
    });

    return encryptPayload(payload, passphrase: passphrase);
  }

  /// Encrypts an arbitrary payload into the backup envelope.
  ///
  /// The export path calls this, and tests call it to build deliberately
  /// hostile backups — a future-dated cycle, a duplicate date, a payload that
  /// is not JSON at all — sealed with a valid key. That is the only honest way
  /// to prove the validation in [_readCycles] actually runs, since a payload
  /// that fails decryption never reaches it.
  @visibleForTesting
  Future<String> encryptPayload(
    String payload, {
    required String passphrase,
  }) async {
    final saltBytes = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);

    final key = await _deriveKey(passphrase, saltBytes);
    final box = await _algorithm.encrypt(
      utf8.encode(payload),
      secretKey: key,
      nonce: nonce,
    );

    return jsonEncode({
      'format': _magic,
      'version': formatVersion,
      'cipher': 'AES-256-GCM',
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': pbkdf2Iterations,
        'salt': base64Encode(saltBytes),
      },
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  // ---------------------------------------------------------------- import --

  /// Decrypts and validates [contents] without touching the database.
  ///
  /// Separated from [apply] so the preview can be shown, and so a malformed or
  /// hostile file is rejected before anything is written.
  Future<RestorePreview> preview({
    required String contents,
    required String passphrase,
  }) async {
    final decoded = _decodeEnvelope(contents);
    final key = await _deriveKey(passphrase, decoded.salt, decoded.iterations);

    List<int> plain;
    try {
      plain = await _algorithm.decrypt(
        SecretBox(
          decoded.cipherText,
          nonce: decoded.nonce,
          mac: Mac(decoded.mac),
        ),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw BackupException(
        'That passphrase does not open this backup. Check it and try again.',
      );
    } catch (_) {
      throw BackupException(
        'This backup could not be opened. The file may be damaged.',
      );
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw BackupException('The decrypted backup is not readable.');
    }
    if (json is! Map<String, Object?>) {
      throw BackupException('The decrypted backup is not readable.');
    }

    final cycles = _readCycles(json);
    final exportedAt = DateTime.tryParse('${json['exportedAt'] ?? ''}');

    return RestorePreview(
      cycles: cycles,
      exportedAt: exportedAt,
      existingCount: await _database.countCycles(),
    );
  }

  /// Replaces the stored history with the backup's, in one transaction.
  ///
  /// Deliberately a replace rather than a merge: merging two histories produces
  /// duplicate starts on adjacent days and a prediction that is wrong in a way
  /// nobody can see. The preview says how many rows will be replaced, so the
  /// user chooses with the number in front of them.
  Future<RestoreSummary> apply(RestorePreview preview) async {
    await _database.replaceAllCycles(preview.cycles);
    return RestoreSummary(
      cyclesRestored: preview.cycles.length,
      exportedAt: preview.exportedAt,
    );
  }

  // --------------------------------------------------------------- helpers --

  static void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < minPassphraseLength) {
      throw BackupException(
        'Use a passphrase of at least $minPassphraseLength characters. '
        'It is the only thing protecting the file.',
      );
    }
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, [
    int? iterations,
  ]) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations ?? pbkdf2Iterations,
      bits: _keyBits,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  _Envelope _decodeEnvelope(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw.trim());
    } catch (_) {
      throw BackupException(
        'That does not look like an Elara backup. Paste the whole file.',
      );
    }
    if (json is! Map<String, Object?>) {
      throw BackupException(
        'That does not look like an Elara backup. Paste the whole file.',
      );
    }
    if (json['format'] != _magic) {
      throw BackupException('That file is not an Elara backup.');
    }
    final version = json['version'];
    if (version is! int) {
      throw BackupException('This backup has no readable version.');
    }
    if (version > formatVersion) {
      throw BackupException(
        'This backup was written by a newer version of Elara.',
      );
    }

    final kdf = json['kdf'];
    if (kdf is! Map<String, Object?>) {
      throw BackupException('This backup has no key derivation settings.');
    }
    final iterations = kdf['iterations'];
    if (iterations is! int || iterations < 10000) {
      throw BackupException('This backup has implausible key settings.');
    }

    try {
      return _Envelope(
        salt: base64Decode(kdf['salt']! as String),
        iterations: iterations,
        nonce: base64Decode(json['nonce']! as String),
        cipherText: base64Decode(json['ciphertext']! as String),
        mac: base64Decode(json['mac']! as String),
      );
    } catch (_) {
      throw BackupException('This backup is damaged and cannot be read.');
    }
  }

  /// Reads and validates cycle rows.
  ///
  /// A backup is untrusted input: it may have been edited by hand or produced
  /// by a different build. Anything that could corrupt the prediction is
  /// rejected here rather than stored.
  List<CycleEntry> _readCycles(Map<String, Object?> json) {
    final raw = json['cycles'];
    if (raw is! List) {
      throw BackupException('This backup contains no cycle history.');
    }

    final cycles = <CycleEntry>[];
    final today = DateTime.now();
    final seen = <String>{};

    for (final item in raw) {
      if (item is! Map) {
        throw BackupException('This backup has a malformed cycle entry.');
      }
      final startRaw = item['startDate'];
      if (startRaw is! String) {
        throw BackupException('This backup has a cycle entry without a date.');
      }
      final start = DateTime.tryParse(startRaw);
      if (start == null) {
        throw BackupException('This backup has an unreadable date: $startRaw');
      }
      final day = DateTime(start.year, start.month, start.day);
      if (day.isAfter(today)) {
        throw BackupException(
          'This backup contains a period start in the future '
          '(${_dateKey(day)}).',
        );
      }
      if (!seen.add(_dateKey(day))) {
        throw BackupException('This backup lists ${_dateKey(day)} twice.');
      }

      final durationRaw = item['duration'];
      int? duration;
      if (durationRaw != null) {
        if (durationRaw is! int || durationRaw < 1 || durationRaw > 30) {
          throw BackupException(
            'This backup has an implausible period length '
            '($durationRaw days).',
          );
        }
        duration = durationRaw;
      }

      cycles.add(CycleEntry(startDate: day, duration: duration));
    }

    cycles.sort((a, b) => a.startDate.compareTo(b.startDate));
    return cycles;
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// A decrypted backup that has been validated but not yet applied.
class RestorePreview {
  const RestorePreview({
    required this.cycles,
    required this.exportedAt,
    required this.existingCount,
  });

  final List<CycleEntry> cycles;
  final DateTime? exportedAt;

  /// How many periods are currently stored, so the UI can say what is replaced.
  final int existingCount;

  DateTime? get firstStart => cycles.isEmpty ? null : cycles.first.startDate;
  DateTime? get lastStart => cycles.isEmpty ? null : cycles.last.startDate;
}

class _Envelope {
  const _Envelope({
    required this.salt,
    required this.iterations,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> salt;
  final int iterations;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
}
