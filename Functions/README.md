# Cloud Functions for Firebase iOS SDK

## Development

Follow the subsequent instructions to develop, debug, unit test, and
integration test FirebaseFunctions:

### Prereqs

- At least CocoaPods 1.10.0
- Install [cocoapods-generate](https://github.com/square/cocoapods-generate)

### To Develop

- Run `pod gen FirebaseFunctions.podspec --local-sources=./`
- `open gen/FirebaseFunctions/FirebaseFunctions.xcworkspace`

OR these two commands can be combined with

- `pod gen FirebaseFunctions.podspec --auto-open --gen-directory="gen" --clean`

You're now in an Xcode workspace generate for building, debugging and
testing the FirebaseFunctions CocoaPod.

### Running Unit Tests

Choose the FirebaseFunctions-Unit-unit scheme and press Command-u.

## Running Integration Tests

Before running the integration tests, you'll need to start a backend emulator
for them to talk to.

1.  Make sure you have `npm` installed.
2.  Run the backend startup script: `Backend/start.sh`
    It will use `npm install` to automatically download the libraries it needs
    to run the [Cloud Functions Local Emulator](https://cloud.google.com/functions/docs/emulator).
    The first time you run it, it will ask for a projectId.
    You can put anything you like. It will be ignored.
3.  Create the workspace in Functions/Example with `pod install`.
4.  `open FirebaseFunctions.xcworkspace`
5.  Choose the FirebaseFunctions-Unit-integration scheme and press Command-u.
6.  When you are finished, you can press any key to stop the backend.
