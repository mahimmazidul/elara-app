import 'dart:convert';
import 'dart:math';

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the backup format against a real in-memory SQLite database.
///
/// The encryption is not mocked: every test below runs the genuine PBKDF2 and
/// AES-GCM, so a wrong passphrase, a tampered byte and a truncated file all fail
/// here exactly as they would on a device.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    db.overridePath = inMemoryDatabasePath;
    await db.resetAllData();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    // Real calendar dates: month 1 day 58 would silently roll into February.
    for (final date in [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 27),
    ]) {
      await db.insertCycle(CycleEntry(startDate: date, duration: 5));
    }
  }

  BackupService service() => BackupService(database: db, random: Random(7));

  test('exports and restores the full history', () async {
    await seed();
    final backup = service();
    final file = await backup.exportToString(passphrase: 'a long passphrase');

    await db.deleteAllCycles();
    expect(await db.countCycles(), 0);

    final preview = await backup.preview(
      contents: file,
      passphrase: 'a long passphrase',
    );
    expect(preview.cycles, hasLength(3));
    expect(preview.existingCount, 0);

    final summary = await backup.apply(preview);
    expect(summary.cyclesRestored, 3);

    final restored = await db.getAllCycles();
    expect(restored.map((c) => '${c.startDate.month}-${c.startDate.day}'), [
      '1-1',
      '1-29',
      '2-27',
    ]);
    expect(restored.every((c) => c.duration == 5), isTrue);
  });

  test('the file on disk contains no readable dates', () async {
    await seed();
    final file = await service().exportToString(
      passphrase: 'a long passphrase',
    );

    // The whole point of encrypting: none of these appear in the file.
    expect(file, isNot(contains('2026-01-01')));
    expect(file, isNot(contains('startDate')));
    expect(file, isNot(contains('elara.db')));
    expect(file.toLowerCase(), isNot(contains('cycle')));
    // What it does carry is the envelope.
    final envelope = jsonDecode(file) as Map<String, Object?>;
    expect(envelope['format'], 'elara-backup');
    expect(envelope['cipher'], 'AES-256-GCM');
    expect((envelope['kdf']! as Map)['name'], 'PBKDF2-HMAC-SHA256');
  });

  test('a wrong passphrase is refused, not silently accepted', () async {
    await seed();
    final file = await service().exportToString(
      passphrase: 'a long passphrase',
    );

    await expectLater(
      service().preview(contents: file, passphrase: 'a wrong passphrase'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('does not open this backup'),
        ),
      ),
    );
  });

  test('a tampered ciphertext is refused by the MAC', () async {
    await seed();
    final file = await service().exportToString(
      passphrase: 'a long passphrase',
    );
    final envelope = jsonDecode(file) as Map<String, Object?>;
    final bytes = base64Decode(envelope['ciphertext']! as String);
    bytes[0] = bytes[0] ^ 0xFF;
    envelope['ciphertext'] = base64Encode(bytes);

    await expectLater(
      service().preview(
        contents: jsonEncode(envelope),
        passphrase: 'a long passphrase',
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test('a short passphrase is rejected before any file is written', () async {
    await seed();
    await expectLater(
      service().exportToString(passphrase: 'short'),
      throwsA(isA<BackupException>()),
    );
  });

  test('exporting with no history explains itself', () async {
    await expectLater(
      service().exportToString(passphrase: 'a long passphrase'),
      throwsA(isA<BackupException>()),
    );
  });

  test('a non-Elara file is refused', () async {
    await expectLater(
      service().preview(
        contents: '{"hello":"world"}',
        passphrase: 'a long passphrase',
      ),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      service().preview(contents: 'not json at all', passphrase: 'x' * 12),
      throwsA(isA<BackupException>()),
    );
  });

  test('a backup from a newer format version is refused', () async {
    await seed();
    final file = await service().exportToString(
      passphrase: 'a long passphrase',
    );
    final envelope = jsonDecode(file) as Map<String, Object?>;
    envelope['version'] = BackupService.formatVersion + 1;

    await expectLater(
      service().preview(
        contents: jsonEncode(envelope),
        passphrase: 'a long passphrase',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });

  test('restore replaces rather than merges', () async {
    await seed();
    final backup = service();
    final file = await backup.exportToString(passphrase: 'a long passphrase');

    // A different history, then a restore of the original.
    await db.deleteAllCycles();
    await db.insertCycle(CycleEntry(startDate: DateTime(2026, 3, 4)));

    final preview = await backup.preview(
      contents: file,
      passphrase: 'a long passphrase',
    );
    expect(preview.existingCount, 1);
    await backup.apply(preview);

    final restored = await db.getAllCycles();
    expect(restored, hasLength(3));
    expect(
      restored.any((c) => c.startDate == DateTime(2026, 3, 4)),
      isFalse,
      reason: 'the replaced history must not survive',
    );
  });

  test('a hand-edited backup with a future date is refused', () async {
    await seed();
    final backup = service();
    final file = await backup.exportToString(passphrase: 'a long passphrase');
    final envelope = jsonDecode(file) as Map<String, Object?>;

    // Re-encrypt a hostile payload under the same passphrase, so decryption
    // succeeds and only the validation stands between it and the database.
    expect(envelope['version'], 1);
    final hostile = await backup.encryptPayload(
      jsonEncode({
        'format': 'elara-backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'cycles': [
          {'startDate': '2099-01-01'},
        ],
      }),
      passphrase: 'a long passphrase',
    );

    await expectLater(
      backup.preview(contents: hostile, passphrase: 'a long passphrase'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('future'),
        ),
      ),
    );
  });

  test('duplicate dates in a backup are refused', () async {
    final backup = service();
    final hostile = await backup.encryptPayload(
      jsonEncode({
        'format': 'elara-backup',
        'version': 1,
        'cycles': [
          {'startDate': '2026-01-01'},
          {'startDate': '2026-01-01'},
        ],
      }),
      passphrase: 'a long passphrase',
    );

    await expectLater(
      backup.preview(contents: hostile, passphrase: 'a long passphrase'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('twice'),
        ),
      ),
    );
  });
}
