# E2E Testing with FIRAppCheckTestApp

This document provides information on how to configure and run End-to-End (E2E) tests for App Check providers using this sample app.

## Configurability

The app's behavior can be configured using environment variables passed during test execution.

### Environment Variables

Starting with Xcode 13, you can pass environment variables directly to the test runner by prefixing them with `TEST_RUNNER_`. The prefix is stripped when it reaches the test process.

- **`TEST_RUNNER_RECAPTCHA_SITE_KEY`**: The reCAPTCHA Enterprise site key used by the `RecaptchaEnterpriseProvider`.
    - **Access in Code**: Read via `ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"]`.
- **`TEST_RUNNER_APP_CHECK_PROVIDER`**: Specifies which App Check provider factory to use.
    - **Supported Values**: `recaptcha` (default), `debug`.
    - **Access in Code**: Read via `ProcessInfo.processInfo.environment["APP_CHECK_PROVIDER"]`.

### Manual Override

For local debugging and manual testing, you can override the environment variables by setting `manualProviderOverride` in `AppDelegate.swift`:

```swift
let manualProviderOverride: String? = "debug" // Force debug provider
```

## Running Tests

The commands below should be run from the **repository root**.

### Prerequisites
- Ensure you have a local checkout of the `app-check` repository if you are developing it locally. Set `FIREBASE_APP_CHECK_LOCAL_PATH` to point to it.

### Sample Commands

#### Run tests with reCAPTCHA Enterprise provider

```bash
export TEST_RUNNER_RECAPTCHA_SITE_KEY="your_site_key_here"
export TEST_RUNNER_APP_CHECK_PROVIDER="recaptcha"
export FIREBASE_APP_CHECK_LOCAL_PATH="/path/to/your/local/app-check"

xcodebuild test \
  -workspace FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace \
  -scheme FIRAppCheckTestApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

#### Run tests with Debug provider

```bash
export TEST_RUNNER_APP_CHECK_PROVIDER="debug"
export FIREBASE_APP_CHECK_LOCAL_PATH="/path/to/your/local/app-check"

xcodebuild test \
  -workspace FirebaseAppCheck/Apps/FIRAppCheckTestApp/FIRAppCheckTestApp.xcworkspace \
  -scheme FIRAppCheckTestApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
*Note: The Debug provider might require you to register the generated debug token in the Firebase Console for the tests to pass if they interact with live services.*

## Project Structure

- **`FIRAppCheckTestAppTests`**: A hosted unit test target containing the test cases. It runs inside the app process to have access to the full app context.
