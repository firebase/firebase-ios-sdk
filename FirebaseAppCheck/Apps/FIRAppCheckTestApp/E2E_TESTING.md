# E2E Testing with FIRAppCheckTestApp

This document provides information on how to configure and run End-to-End (E2E)
tests for App Check providers using this sample app.

## Configurability

The app's behavior can be configured using environment variables passed during
test execution.

### Environment Variables

Starting with Xcode 13, you can pass environment variables directly to the
test runner by prefixing them with `TEST_RUNNER_`. The prefix is stripped when
it reaches the test process.

- **`TEST_RUNNER_RECAPTCHA_SITE_KEY`**: The reCAPTCHA Enterprise site key used
  by the `AppCheckRecaptchaEnterpriseProvider`.
    - **Access in Code**: Read via
      `ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"]`.
- **`TEST_RUNNER_APP_CHECK_PROVIDER`**: Specifies which App Check provider
  factory to use.
    - **Supported Values**: `recaptcha` (default), `debug`.
    - **Access in Code**: Read via
      `ProcessInfo.processInfo.environment["APP_CHECK_PROVIDER"]`.

### Manual Override

For local debugging and manual testing, you can override the environment
variables by setting `manualProviderOverride` in `AppDelegate.swift`:

```swift
let manualProviderOverride: String? = "debug"
```

## Running Tests

The commands below should be run from the **repository root**.

### Prerequisites
- Ensure you have a local checkout of the `app-check` repository if you are
  developing it locally. Set `FIREBASE_APP_CHECK_LOCAL_PATH` to point to it.

### Sample Commands

#### Run tests with reCAPTCHA Enterprise provider

```bash
export TEST_RUNNER_RECAPTCHA_SITE_KEY="your_site_key_here"
export TEST_RUNNER_APP_CHECK_PROVIDER="recaptcha"
export FIREBASE_APP_CHECK_LOCAL_PATH="/path/to/your/local/app-check"
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1)

xcodebuild test \
  -workspace FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace \
  -scheme FIRAppCheckTestApp \
  -destination "platform=iOS Simulator,id=$SIM_ID"
```

#### Run tests with Debug provider

```bash
export TEST_RUNNER_APP_CHECK_PROVIDER="debug"
export FIREBASE_APP_CHECK_LOCAL_PATH="/path/to/your/local/app-check"
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1)

xcodebuild test \
  -workspace FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace \
  -scheme FIRAppCheckTestApp \
  -destination "platform=iOS Simulator,id=$SIM_ID"
```
*Note: The Debug provider might require you to register the generated debug token in the Firebase Console for the tests to pass if they interact with live services.*

### Running and Testing in Xcode

If you prefer to use the Xcode UI instead of `xcodebuild`, follow these steps
to configure the environment:

#### 1. Resolve Local Dependency
If you are using a local checkout of the `app-check` repository, Xcode must be
launched from the terminal with the `FIREBASE_APP_CHECK_LOCAL_PATH` environment
variable set so that Swift Package Manager can resolve it correctly.

Run the following command from the repository root:
```bash
open --env FIREBASE_APP_CHECK_LOCAL_PATH=/path/to/your/local/app-check FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace
```

#### 2. Configure Provider and Site Key
You have two options to configure the provider when running or testing in Xcode:

**Option A: Via Manual Override in Code (Easiest for Running the App)**
If you just want to quickly run the app with a specific provider without
changing scheme settings:
1.  Open `AppDelegate.swift`.
2.  Locate `manualProviderOverride` in `application(_:didFinishLaunchingWithOptions:)`.
3.  Set it to your desired provider:
    ```swift
    let manualProviderOverride: String? = "recaptcha"
    ```
    *Note: Remember to revert this change before committing.*

**Option B: Via Xcode Scheme (Recommended for Tests)**
This avoids modifying code and works for both running and testing.
1.  In Xcode, go to **Product > Scheme > Edit Scheme...** (or press `⌘<`).
2.  Select the **Run** or **Test** action in the left sidebar, depending on
    what you are doing.
3.  Go to the **Arguments** tab.
4.  In the **Environment Variables** section, add:
    *   `APP_CHECK_PROVIDER`: Set to `recaptcha` or `debug`.
    *   `RECAPTCHA_SITE_KEY`: Set to your reCAPTCHA site key (required for
        `recaptcha`).

### Running and Testing with CocoaPods

If you prefer to use the CocoaPods workflow instead of SPM:

#### 0. Clean Up State (Optional but Recommended)
If you are switching from the SPM workflow or encounter issues, it is
recommended to clean up the CocoaPods state first:
```bash
pod deintegrate FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcodeproj
rm -rf FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace
rm -f FirebaseAppCheck/Apps/FIRAppCheckTestApp/Podfile.lock
```

#### 1. Install Dependencies
To ensure a clean update and avoid conflicts with local development paths or
stale state, it is recommended to remove the existing `Pods` directory and
`Podfile.lock` before updating.

Run the following command from the repository root:
```bash
rm -rf FirebaseAppCheck/Apps/FIRAppCheckTestApp/Pods
rm -f FirebaseAppCheck/Apps/FIRAppCheckTestApp/Podfile.lock
FIREBASE_APP_CHECK_LOCAL_PATH="/path/to/your/local/app-check" pod update --repo-update --project-directory=FirebaseAppCheck/Apps/FIRAppCheckTestApp/
```

#### 2. Open Workspace
Open the generated CocoaPods workspace instead of the project file:
```bash
open FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace
```

#### 3. Remove SPM Dependencies (If needed)
By default, the project file is configured for SPM. To avoid duplicate symbol
issues or conflicting resolutions when using CocoaPods:
1.  In Xcode, select the project in the file navigator.
2.  Select the project file at the top (not a target).
3.  Go to the **Package Dependencies** tab.
4.  Remove the `firebase-ios-sdk` or `app-check` package references if they
    appear there.
5.  Also, select the `FIRAppCheckTestApp` target, go to the **General** tab,
    and scroll down to **Frameworks, Libraries, and Embedded Content**.
6.  Remove any SPM-resolved frameworks from this list.

#### 4. Configure and Run
You can configure the provider and site key either via the Xcode Scheme or by
passing environment variables to `xcodebuild`.

**Via Xcode Scheme:**
Follow the instructions in **[Running and Testing in Xcode](#running-and-testing-in-xcode)**.

**Via `xcodebuild` (Command Line):**
Run the following command from the repository root, replacing the site key with
your own:
```bash
export TEST_RUNNER_RECAPTCHA_SITE_KEY="your_site_key_here"
export TEST_RUNNER_APP_CHECK_PROVIDER="recaptcha"
SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1)

xcodebuild test \
  -workspace FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace \
  -scheme FIRAppCheckTestApp \
  -destination "platform=iOS Simulator,id=$SIM_ID"
```
*(Note: See [Running Tests](#running-tests) for how to dynamically find a valid
simulator destination).*

## Project Structure

- **`FIRAppCheckTestAppTests`**: A hosted unit test target containing the test cases. It runs inside the app process to have access to the full app context.
