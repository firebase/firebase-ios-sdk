# FirebaseCore API baselines

These files record FirebaseCore's public API so that changes to it are caught
in review. They guard the reimplementation of FirebaseCore in Swift, which must
keep the public Swift and Objective-C APIs unchanged.

| File | Contents |
|---|---|
| `swift/<platform>.json` | `swift-api-digester` dump of the Swift view of the `FirebaseCore` module, per platform. |
| `swift/FirebaseCore.swiftinterface` | The same API as readable Swift (iOS), for reviewers. |
| `objc/FirebaseCore.symbols.json` | Normalized `clang -extract-api` symbol graph of the Objective-C public headers. |
| `metadata.json` | The toolchain that generated the baselines. |
| `allowlist.json` | Reviewed, intentional differences. |
| `coverage.json` | Line coverage of FirebaseCore by the Swift unit tests (`CoreSwiftUnit`), per file and in total. |

## Checking

```sh
DEVELOPER_DIR=/Applications/Xcode_26.4.app/Contents/Developer \
  scripts/core_api/core_api.py check
```

Use the Xcode recorded in `metadata.json`, which is the Xcode that the
`api-baselines` job in `.github/workflows/sdk.core.yml` uses. The Swift view of
an API can differ between compiler versions. That job uploads the current API
as the `core-api-current` artifact, which can replace these files after an
approved change.

`check` fails if a declaration is removed, renamed, or changes type,
optionality, `@Sendable`, or deprecation, and also if a declaration is added.
Objective-C method nullability isn't compared directly, because `clang
-extract-api` drops it. The Swift gate covers it, because the Swift view shows
nullability as optionality.

## Changing the API

FirebaseCore's public API shouldn't change. If a change has been reviewed and
approved:

* For a small, known difference, add an entry to `allowlist.json` with a
  `pattern` that matches the reported line and a `reason`.
* Otherwise regenerate the baselines with `scripts/core_api/core_api.py update`
  and include the regenerated files in the same pull request.

## Line coverage

The Swift unit tests in `FirebaseCore/Tests/SwiftSuite` (the `CoreSwiftUnit`
target) are the oracle for the Swift reimplementation, so they must keep
covering FirebaseCore at least as well as they cover the Objective-C
implementation. `coverage.json` records their line coverage on macOS of
`FirebaseCore/Sources` and `FirebaseCore/Internal/Sources`, per file and in
total, and the toolchain that measured it.

```sh
scripts/core_api/coverage.py check
```

`check` runs `CoreSwiftUnit` with `xcodebuild test -enableCodeCoverage YES`
and fails if total line coverage dropped by more than 0.5 points. It reads the
line counts with `llvm-cov export` from the run's `Coverage.profdata`, because
`xccov` leaves out the `FirebaseCore/Internal` Swift files. It copies the
`CoreSwiftUnit` scheme from `scripts/spm_test_schemes` if it isn't in
`.swiftpm` yet, and removes the copy afterward. Use `--derived-data-path` and
`--cloned-source-packages-path` to reuse a build and its package checkouts,
and `--xcodebuild-arg` (repeatable) to pass other arguments to xcodebuild.
`scripts/core_api/run_tsan.sh` runs the same suite with ThreadSanitizer, takes
the same paths, passes other arguments to xcodebuild, and fails on a test
failure or a ThreadSanitizer report.

The `swift-unit-tsan-coverage` job in `.github/workflows/sdk.core.yml` runs
both, and uploads the measured coverage as the `core-coverage-current`
artifact. After an approved change, update the baseline with
`scripts/core_api/coverage.py update`, or replace `coverage.json` with that
artifact.

The current baseline was recorded locally with Xcode 26.5. It's to be replaced
with the `core-coverage-current` artifact from the next CI run, which uses
the Xcode 26.4 that the job selects, as was done for the API baselines.
Coverage can differ slightly between toolchains, and `check` notes when the
toolchains differ. Measure with heartbeat storage writable,
as on CI; in a sandbox the heartbeat tests are skipped, so coverage is lower.

The gate compares total coverage only. When Swift files replace the
Objective-C files, the per-file numbers stop being comparable: the files have
different names and line counts. Add the Swift implementation's source
directories to `SOURCE_DIRS` in `coverage.py`, and check that the total doesn't
drop. The per-file differences are printed for reference.

For comparison, the Objective-C unit tests (`CoreUnit`, without
`FIRHeartbeatLoggerTests`) covered 77.9% of the lines in `FirebaseCore/Sources`
when the baseline was recorded. That number isn't gated.
