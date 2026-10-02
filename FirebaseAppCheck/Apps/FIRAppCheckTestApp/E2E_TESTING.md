# E2E Testing with FIRAppCheckTestApp

End-to-end tests for Firebase App Check v12, run inside this sample app against
the real backend and, on a physical device, real App Attest and DeviceCheck.

- [TEST_PLAN.md](TEST_PLAN.md): the full case list (MIG, ATT, COR, REF, DBG,
  DVC, RCP, INT) and which cases this suite automates (section 9).
- [VERSION_DIFFING.md](FIRAppCheckTestAppTests/VERSION_DIFFING.md): running
  the same suite against Firebase v11.

## What's in the test target

`FIRAppCheckTestAppTests` is a hosted test bundle: it runs inside the app
process, so the app's `AppDelegate` configures the default `FirebaseApp` first.

| Suite | Kind | Backend |
| :--- | :--- | :--- |
| Core token lifecycle, Auto-refresh tests, Language interoperability, Legacy storage address parity, Public API contract | Swift Testing | None. Uses scripted providers and fake options. |
| Debug provider tests | Swift Testing | Live, debug token |
| App Attest, DeviceCheck, Recaptcha provider tests | Swift Testing | Live. Hardware tests skip in the Simulator. |
| `AppCheckObjCAPITests` | XCTest, Objective-C | None |
| `FIRAppCheckTestAppTests` | XCTest | Live, through the host app's provider |

Each Swift Testing test's doc comment starts with the TEST_PLAN.md case ID it
covers.

## Prerequisites

1. **`GoogleService-Info.plist`**: download it from the Firebase console and
   place it at `FIRAppCheckTestApp/GoogleService-Info.plist`. It is gitignored;
   never commit it.
2. **Debug token**: a UUID registered for that app under App Check > Apps >
   Manage debug tokens. Debug tokens are registered per Firebase app, so a new
   plist needs its own token.
3. **reCAPTCHA Enterprise site key** for the project.
4. **Device runs only**:
   - A team, bundle ID, and provisioning profile with App Attest enabled,
     matching the plist's `BUNDLE_ID`. Set them in the target's Signing
     settings locally; don't commit them.
   - A DeviceCheck private key uploaded in the console for that team, or the
     DeviceCheck tests fail with HTTP 403.
   - Leave `com.apple.developer.devicecheck.appattest-environment` set to
     `production` in `FIRAppCheckTestApp.entitlements`. App Check rejects
     `development`.

## Configuration values

The app and the tests read these from the process environment.

| Variable | Required for | Notes |
| :--- | :--- | :--- |
| `AppCheckDebugToken` | Debug provider tests, `FIRAppCheckTestAppTests` | Takes precedence over the legacy `FIRAAppCheckDebugToken`. Set only one, or App Check logs a warning for every debug provider it creates. |
| `RECAPTCHA_SITE_KEY` | Recaptcha provider tests; `APP_CHECK_PROVIDER=recaptcha` | |
| `APP_CHECK_PROVIDER` | Optional | Host app's provider: `debug` (default) or `recaptcha`. |

> [!WARNING]
> Never put the debug token or site key in the shared
> `FIRAppCheckTestApp.xcscheme`. Use a personal scheme (below) or the
> command line.

## Running in Xcode

1. Open `FIRAppCheckTestApp.xcodeproj`.
2. **Product > Scheme > Manage Schemes...**, select `FIRAppCheckTestApp`, and
   click **Duplicate**. In the copy, leave **Shared** unchecked so it is stored
   under `xcuserdata/`, which is gitignored.
3. **Edit Scheme > Test > Arguments**. Under **Environment Variables**, add
   `AppCheckDebugToken` and `RECAPTCHA_SITE_KEY`. Alternatively, add them to
   the Run action and check **Use the Run action's arguments and environment
   variables** in the Test action.
4. Pick a simulator or your device and press **⌘U**.

## Running from the command line

Run from the repository root. `xcodebuild` passes variables prefixed with
`TEST_RUNNER_` to the test process with the prefix removed, so the shared
scheme needs no secrets.

Simulator:

```sh
TEST_RUNNER_AppCheckDebugToken=<debug-token> \
TEST_RUNNER_RECAPTCHA_SITE_KEY=<site-key> \
xcodebuild test \
-project FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcodeproj \
-scheme FIRAppCheckTestApp \
-destination 'platform=iOS Simulator,name=iPhone 17'
```

Device (unlocked, with local signing configured):

```sh
TEST_RUNNER_AppCheckDebugToken=<debug-token> \
TEST_RUNNER_RECAPTCHA_SITE_KEY=<site-key> \
xcodebuild test \
-project FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcodeproj \
-scheme FIRAppCheckTestApp \
-destination 'platform=iOS,id=<device-udid>'
```

`xcrun xctrace list devices` lists simulator names and device UDIDs.

## Expected results

| Destination | Passed | Skipped | Skipped tests |
| :--- | ---: | ---: | :--- |
| Simulator | 45 | 6 | Physical-hardware App Attest, DeviceCheck, and reCAPTCHA token tests |
| Device | 47 | 4 | Simulator-only App Attest and DeviceCheck "fails safely" tests |

Anything other than zero failures and these skips needs a look. Common causes:

| Symptom | Likely cause |
| :--- | :--- |
| Debug provider and `FIRAppCheckTestAppTests` fail with HTTP 403 | Debug token missing, or registered for a different Firebase app than the plist. |
| DeviceCheck hardware tests fail with HTTP 403 | No DeviceCheck key uploaded for the signing team. |
| App Attest hardware tests fail | Entitlement not `production`, or App Attest not enabled for the bundle ID. |
| Recaptcha tests fail on `#require` | `RECAPTCHA_SITE_KEY` not set. |

Log lines you can ignore: `[XPC] ... DownloadFailed`, `Hang detected` with a
debugger attached, `GTMSessionFetcher ... was already running`, and the debug
token banner (`I-FAA005001`).

## CI

The `test_app_build` job in `.github/workflows/sdk.appcheck.yml` only builds
the app and test bundle (`build-for-testing`, simulator, no signing). It does
not run tests: CI has no debug token or site key, and App Attest and
DeviceCheck need a signed physical device.

The app target lists `GoogleService-Info.plist` as a resource, so the build
fails if the file is missing. The real plist is gitignored, so the job first
copies the placeholder plist from `FirebaseCore/Tests/Unit/Resources/` into
place. Do the same to reproduce the CI build locally without a real plist.

## Legacy: CocoaPods

The project still has a `Podfile` and workspace, but CocoaPods is being phased
out and that path is not maintained. Use Swift Package Manager as above.
