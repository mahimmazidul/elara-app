# Privacy model and the encryption-at-rest decision

Date: 2026-11-08. This records what Elara does with health data, and the
decision taken on encrypting the local database — including the reasoning for
not doing it in this pass.

## 1. What is stored, and where

Everything is in one SQLite file in the app's private directory
(`elara.db`), created by `lib/data/database_helper.dart`:

| Table | Contents | Sensitivity |
|---|---|---|
| `cycles` | Period start dates and durations | Health data |
| `symptoms` | Reported symptoms, severity, free-text notes | Health data |
| `preferences` | Partner-entered observations and her answers | Health data, some of it intimate |
| `care_reminders` | Free-text plans attached to dates | Personal, occasionally suggestive |
| `consent_records` | When consent was given or withdrawn | Personal |
| `settings` | Theme, coordinates, notification and privacy switches | Location-adjacent |
| `climate_cache` | Weather readings for the stored coordinates | Low |

The app makes two kinds of request: weather (Open-Meteo/OpenAQ, coordinates only)
and, if the user switches it on, a public GitHub Releases lookup that carries no
query and no identifying headers. There is nothing else in the network stack to
send.

## 2. Protections that exist

- **Encrypted export.** The backup contains cycle dates, so it is AES-GCM
  encrypted under a key stretched from a user passphrase with PBKDF2. Import
  validates before writing and never wipes the database on a format or
  passphrase failure (`lib/services/backup_service.dart`, and its tests).
- **Notification privacy.** Detail in notifications is off by default; when it
  is on, the text may name a phase. The default assumes a lock screen can be
  read by someone else.
- **Screen-level honesty about the same-device limit.** The preferences screen
  says that anything stored on this phone can be read by whoever holds it; a
  questionnaire answer marked "not shared" is kept out of the suggestion pool,
  but that is a *product* rule, not access control, and the UI says so.
- **Least-privilege footprint.** No contacts, no calendar, no location
  permission request is used for tracking; the district is picked from an
  offline list of the sixty-four district towns, or coordinates are typed in
  or defaulted.

## 3. What is not protected

The database file itself is plain SQLite. Anyone with:

- physical access to an unlocked phone, or
- a rooted device, or
- a full-device backup that includes app data,

can read every cycle date, symptom and answer without needing Elara.

## 4. The decision: do not add database encryption in this pass

The brief asked for the question to be resolved rather than assumed. Four
options were weighed.

| Option | Protection gained | Cost and risk |
|---|---|---|
| A. Leave plain SQLite, document it | None at rest | Honest, but the file is readable if the sandbox is broken |
| B. Encrypt with a Keystore-held key the app can always use | Protects a copied file or a device backup; **not** a running app on an unlocked device | Key management, a new dependency or platform channel, and a failure mode that can lock a user out of their own history |
| C. Encrypt with a user passphrase | Real protection, including against someone who unlocks the phone | A passphrase prompt on launch, an unavoidable support burden for "I forgot it", and a decision that would lose data unless the recovery path is designed first |
| D. SQLCipher via a maintained package | Strong, well-reviewed implementation of B or C | A heavy native dependency in an offline-first app that currently has none |

**Decision: A for this pass, with C as the target model if encryption is added.**

Reasons, in order of weight:

1. **The threat that matters is not addressed by the easy option.** Android's
   app sandbox plus device encryption already protects the file against another
   app and against a powered-off stolen device. Option B would mostly move the
   key next to the lock, and would add a decryption failure path that this
   milestone's rules forbid from destroying data. The residual risk it closes —
   a copied file, or a backup that includes app data — is real but narrower than
   it looks.
2. **The brief's rule about failure modes is the binding constraint.** "Never
   silently destroy data after a decryption failure" cannot be satisfied by a
   key the app must be able to regenerate: if the Keystore entry is lost (a
   restore to a new device, a cleared credential store, a vendor bug), the data
   is unreadable, and there is no honest recovery other than a passphrase the
   user holds. That is option C, and option C needs its own design (setup,
   verification, an explicit "I have lost the passphrase" path, and a migration
   of existing plaintext data that keeps a copy until the encrypted store is
   verified readable).
3. **Nothing here is hiding from an attacker with the unlocked phone.** Any
   answer that does not ask for a secret at launch is defeated by picking up the
   phone. Claiming otherwise in the UI would be worse than the current honesty.
4. **Scope.** Adding a native crypto dependency, a migration and a recovery
   design is a milestone of its own, and doing it late in a pass without a
   device to test failure recovery on would be reckless.

## 4a. Correction, 10 November 2026: Android cloud backup was on

The decision above covers encryption at rest. It did not cover *egress*, and the
manifest left three defaults in place that made the app's own summary of itself
false:

| Manifest attribute | Value before | Effect |
|---|---|---|
| `android:allowBackup` | absent (defaults to `true`) | `elara.db` was included in Android Auto Backup |
| `android:fullBackupContent` | absent | nothing excluded from a pre-API-31 backup |
| `android:dataExtractionRules` | absent | nothing excluded from cloud backup or device transfer on API 31+ |

So every cycle date, symptom severity, free-text note and questionnaire answer
written on the phone was being copied to the user's Google account by the
operating system, with no interaction from this app. Section 3 lists "a
full-device backup that includes app data" as a residual threat; on Android 12
and later it was not residual, it was the default behaviour, and section 1's
statement that no server holds anyone's health history was therefore untrue.

That is now fixed rather than documented:

- `android:allowBackup="false"`;
- `android:fullBackupContent="false"`;
- `android:dataExtractionRules="@xml/data_extraction_rules"`, which excludes
  `root`, `file`, `database`, `sharedpref` and `external` from **both**
  cloud-backup and device-transfer;
- `tool/check_manifest.py` fails the build if any of those three attributes
  regress, so the next person to edit the manifest cannot silently undo it
  (it is run by `ci.yml` and `android-ci.yml`).

The supported backup is the one section 2 describes: an encrypted export the
user runs deliberately, under her own passphrase, to a destination she picks.
A backup she chose is a backup; a backup Google took is a copy.

Two related items are still open, and are recorded here rather than claimed as
done:

1. **`FLAG_SECURE` is on** (it was not), which keeps the app out of the recents
   thumbnail, out of screen recordings and out of `adb screencap`. The one build
   that opts out is the screenshot pipeline, via `-PelaraScreenshots=true`.
2. **The database is still plain SQLite**, per section 4. Physically seizing an
   unlocked phone still reads everything. Nothing in this document should be
   read as saying otherwise.

## 5. What the app must therefore keep saying

- The Privacy and data section states that data is stored on this phone and is
  as safe as the phone is; it does not claim encryption at rest.
- Nothing in the preferences questionnaire implies that a "not shared" answer is
  hidden from the phone's owner.
- If encryption is added later, this document, the in-app text and the README
  are updated in the same change, and the failure-recovery test lands with it.

## 6. Next step if encryption is pursued

1. Write the passphrase setup, unlock and lost-passphrase flows first, as a
   design, not as code.
2. Implement SQLCipher (option D) with a passphrase-derived key (option C),
   keeping a verified plaintext copy until the encrypted database opens and
   the row counts match.
3. Test on a device: fresh install, reopen, wrong passphrase, forgotten
   passphrase, restore from an encrypted backup into an encrypted store, and a
   torn migration (process killed between copy and swap).
4. Only then remove the plaintext copy, and only after a successful read.
