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

### Updating crash report proto

If the crash report proto needs to be updated, follow these instructions -
- Prerequisite installations:
    - `gem (update|install) cocoapods cocoapods-generate`
    - `brew install protobuf nanopb-generator`
    - `easy_install protobuf python`
- Update `ProtoSupport/Protos/crashlytics.proto` with the new changes
- Depending on the type of fields added/removed, also update `ProtoSupport/Protos/crashlytics.options`.
 `CALLBACK` type fields in crashlytics.nanopb.c needs to be changed to `POINTER`
 (through the options file). Known field types that require an entry in crashlytics.options are
 `strings`, `repeated` and `bytes`.
- Run `generate_project.sh` to update the nanopb .c/.h files.

### Running Unit Tests

Open the generated workspace, choose the FirebaseCrashlytics-Unit-unit scheme and press Command-u.
