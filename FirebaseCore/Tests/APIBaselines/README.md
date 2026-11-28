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
| `binary_link.json` | What the prebuilt Analytics binaries use from FirebaseCore. See [the binary link gate](#the-binary-link-gate). |

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

The current baseline is the `core-coverage-current` artifact from CI, with the
Xcode 26.4 that the job selects. It matched the earlier local measurements with
Xcode 26.5 and 27.2 exactly.
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

## The binary link gate

The prebuilt `FirebaseAnalytics` and `GoogleAppMeasurement` binaries were
compiled against FirebaseCore's internal API and can't be rebuilt.
`binary_link.json` records what they use from FirebaseCore:

* `symbols`: the binaries' undefined Firebase symbols, by the product that
  provides them, such as `_FIRFirebaseVersion` and `_OBJC_CLASS_$_FIRApp`.
* `selectors`: Objective-C selectors that the binaries use and FirebaseCore
  implements, apart from `NSObject` ones. Each must be covered by the runtime
  ABI contract in `FirebaseCore/Tests/RuntimeABI/FIRCoreRuntimeABITests.m`.
* `names`: names that the binaries look up as strings at run time, such as
  `FIRConfiguration` and `FIRAnalyticsConfigurationSetEnabledNotification`.
  Names that are FirebaseCore classes or protocols, or strings in its sources,
  are listed under `FirebaseCore` and must be pinned by a FirebaseCore test.

Two checks use it. `.github/workflows/sdk.core.binary-link.yml` runs both,
with FirebaseCore linked statically and dynamically, when FirebaseCore, these
checks or `Package.swift` (which pins the binaries' versions) change, and
nightly.

* The `CoreAnalyticsLink` test target links FirebaseCore with the real
  binaries, configures the default app and checks that Analytics registers
  with FirebaseCore, provides its interop component, starts, and follows the
  data collection switch. `scripts/core_api/binary_link` runs the same test
  with FirebaseCore built as dynamic libraries. The test reads Analytics'
  console messages back from the log, so it doesn't need the network, but it
  fails if a sandbox stops the process from reading its own log.
* `scripts/core_api/check_binary_link.py check` compares the binaries with
  `binary_link.json`, and checks that the FirebaseCore builds export every
  symbol the binaries need.

```sh
scripts/setup_spm_tests.sh  # Puts the CoreAnalyticsLink scheme in place.
xcodebuild test -scheme CoreAnalyticsLink -destination 'platform=macOS' \
  -enableCodeCoverage NO -derivedDataPath .build/binary-link-static
(cd scripts/core_api/binary_link &&
  xcodebuild test -scheme CoreBinaryLink-Package -destination 'platform=macOS' \
    -enableCodeCoverage NO -derivedDataPath ../../../.build/binary-link-dynamic)
scripts/core_api/check_binary_link.py check \
  --workspace-state .build/binary-link-static/SourcePackages/workspace-state.json \
  --static .build/binary-link-static/Build/Products/Debug \
  --dynamic .build/binary-link-dynamic/Build/Products/Debug \
  --dynamic-client .build/binary-link-dynamic/Build/Products/Debug/CoreAnalyticsLinkDynamic.xctest/Contents/MacOS/CoreAnalyticsLinkDynamic
```

Code coverage must be off, because the dynamic libraries are linked without
the profiling runtime. With Xcode 27 or later, `swift build --target
CoreAnalyticsLink` followed by `xcrun xctest
.build/out/Products/Debug/CoreAnalyticsLink.xctest` also works, in both
packages, and `--static`/`--dynamic` then take the `.build/out/Products/Debug`
directories.

`scripts/core_api/check_binary_link.py list` prints what each binary uses.
When the binaries are updated, review what changed and regenerate
`binary_link.json` with `update` and the same `--static` and `--dynamic`
options. Don't regenerate it to make a FirebaseCore change pass: a symbol,
selector or name that the binaries use must stay.
