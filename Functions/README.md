# Cloud Functions for Firebase iOS SDK

## To run unit tests

Choose the FirebaseFunctions_Tests scheme and press Command-u.

## To run integration tests

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
5.  Choose the FirebaseFunctions_IntegrationTests scheme and press Command-u.
6.  When you are finished, you can press any key to stop the backend.
