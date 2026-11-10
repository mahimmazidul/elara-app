# Testing policy

This repository is developed in a sandbox with a **2 GB memory ceiling**. The
Dart frontend needs more than that to compile the larger widget suites, so
`flutter test test/` cannot be run to completion locally. Repeatedly trying it
is slow, and — because the compiler is killed rather than the test failing —
it produces a misleading "the Dart compiler exited unexpectedly" error that
has nothing to do with the code under test.

GitHub Actions has the memory to run everything. So the rule is simple:

> **CI is the test environment. The local workspace is for fast, targeted
> debugging.**

## The rules

### During development

1. **Run only the fast, directly relevant test file(s) locally**, for immediate
   debugging:

   ```bash
   flutter test test/providers/cycle_correction_test.dart
   flutter test test/services/ --reporter compact
   ```

2. **Do not repeatedly run the entire `test/` directory** in the temporary
   workspace. It cannot complete there, and each attempt costs several minutes
   before the compiler is killed.

3. **Investigate a slow or hanging test** rather than raising its timeout. A
   test that needs a longer timeout is a test that is waiting on something it
   should not be waiting on. The known cases are recorded below.

4. **Never delete, weaken, or silently skip a test to make a run faster.** If a
   test is wrong, fix the test or the code — not the threshold.

### After each meaningful checkpoint

1. Commit and push the work to the development branch.
2. Let **GitHub Actions run the complete Flutter test suite under `test/`** —
   every file, every push, no exceptions.
3. Run static analysis (`dart analyze --fatal-infos`) and the relevant checks
   in CI.
4. Use sharding (already configured) to keep the wall-clock time reasonable
   without dropping any test.
5. **Inspect the workflow logs and fix failures before merging.** A green badge
   that nobody read is not a check.

### Android-specific changes

Build the APK in GitHub Actions and run the emulator verification. The
`Android CI` workflow builds a debug APK, inspects its package identity and
version, uploads it, and installs *that artifact* on an emulator — so what runs
on the emulator is exactly what was built, not a second compilation.

### When CI is unavailable

If GitHub Actions is unavailable, or fails for an infrastructure reason, **say
so explicitly**. Do not present unverified changes as tested. The workflow run
links and their results are recorded in
[`DEVELOPMENT_PROGRESS.md`](DEVELOPMENT_PROGRESS.md) so that a workspace reset
cannot erase the verification history.

## How the CI suite is organised

| Workflow | Job | What it does |
|---|---|---|
| `ci.yml` | `analyze` | `dart analyze --fatal-infos`; the fail-fast gate |
| `ci.yml` | `plan` | computes the shard plan from the file list |
| `ci.yml` | `test` | runs the whole of `test/`, split into 4 shards |
| `android-ci.yml` | `apk` | analyze + test + debug APK + artifact inspection + upload |
| `android-ci.yml` | `emulator` | installs the uploaded APK on an emulator and records evidence |

The shard plan is **computed from the files that exist**, not written down by
hand:

```bash
mapfile -t files < <(find test -name '*_test.dart' | sort)
for ((i = 0; i < ${#files[@]}; i++)); do
  shard=$((i % SHARDS))
  ...
done
```

Round-robin over the sorted list keeps the shards balanced in size as well as
in count, a new test file is picked up automatically, and a shard that would
contain no files fails the job instead of silently reporting success. There is
no way for a test to be quietly orphaned by a stale list.

## Known environment limits (not test failures)

| Symptom | Cause | What to do |
|---|---|---|
| `Error: The Dart compiler exited unexpectedly` / `No tests ran` on `test/widgets/responsive_test.dart` and `test/widgets/consent_gate_test.dart` | The sandbox OOM-killed the Dart frontend (`dmesg` shows `oom-kill … dart:frontend_s`). | Do not raise a timeout. Run it in CI. |
| `Bad state: Cannot close sink while adding stream` | The same kill, seen while the runner was shutting down. | Same. |
| `504` from `services.gradle.org` or `github.com/.../releases/download/...` | The CDN. | Retry; the build step already retries three times. |

## Checking a change locally

```bash
# The one file you touched.
flutter test test/providers/cycle_correction_test.dart

# A directory of fast, related suites.
flutter test test/services/ --reporter compact

# Everything, on a machine with enough memory.
flutter test --reporter expanded
```

Then push and read the CI logs.
