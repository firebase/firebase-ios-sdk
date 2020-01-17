# Firebase Crashlytics SDK

## Development

Follow the subsequent instructions to develop, debug, unit test, and
integration test FirebaseCrashlytics:

### Prereqs

- At least CocoaPods 1.6.0
- Install [cocoapods-generate](https://github.com/square/cocoapods-generate)

### To Develop

- Run `pod gen FirebaseCrashlytics.podspec`
- `open gen/FirebaseCrashlytics/FirebaseCrashlytics.xcworkspace`

OR these two commands can be combined with

- `pod gen FirebaseCrashlytics.podspec --auto-open --gen-directory="gen" --clean`

You're now in an Xcode workspace generate for building, debugging and
testing the FirebaseCrashlytics CocoaPod.

### Running Unit Tests

Open the generated workspace, choose the FirebaseCrashlytics-Unit-unit scheme and press Command-u.
