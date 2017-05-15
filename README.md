# Firebase iOS Open Source Development

This repository contains a subset of the Firebase iOS SDK source. It currently
includes FirebaseCore, FirebaseAuth, FirebaseDatabase, FirebaseMessaging, and
FirebaseStorage.

The code here is only for those interested in the SDK internals or those
interested in contributing to Firebase.

General Firebase information can be found at [https://firebase.google.com](https://firebase.google.com).

## Usage

```
$ git clone git@github.com:FirebasePrivate/firebase-ios-sdk.git
$ cd firebase-ios-sdk/Example
$ pod update
$ open Firebase.xcworkspace
```
### Running Unit Tests

Select a scheme and press Command-u to build a component and run its unit tests.

### Running Sample Apps
In order to run the sample apps and integration tests, you'll need valid
`GoogleService-Info.plist` files for those samples. The Firebase Xcode project contains dummy plist files without real values, but can be replaced with real plist files. To get your own `GoogleService-Info.plist` files:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project, if you don't already have one
3. For each sample app you want to test, create a new Firebase app with the sample app's bundle identifier (e.g. `com.google.Database-Example`)
4. Download the resulting `GoogleService-Info.plist` and replace the appropriate dummy plist file (e.g. in [Example/Database/App/](Example/Database/App/));

Some sample apps like Firebase Messaging ([Example/Messaging/App](Example/Messaging/App)) require special Apple capabilities, and you will have to change the sample app to use a unique bundle identifier that you can control in your own Apple Developer account.

See the sections below for any special instructions for those SDKs.

## Firebase Auth

If you're doing specific Firebase Auth development, see
[AuthSamples/README.md](AuthSamples/README.md) for instructions about
building and running the FirebaseAuth pod along with various samples and tests.

## Firebase Database

To run the Database Integration tests, make your database authentication rules
[public](https://firebase.google.com/docs/database/security/quickstart).

## Firebase Storage

To run the Storage Integration tests, follow the instructions in
[FIRStorageIntegrationTests.m](Example/Storage/Tests/Integration/FIRStorageIntegrationTests.m).

## Firebase Messaging

### Push Notifications

Push notifications can only be delivered to specially provisioned App IDs in the developer portal. In order to actually test receiving push notifications, you will need to: 

1. Change the bundle identifier of the sample app to something you own in your Apple Developer account, and enable that App ID for push notifications.
2. You'll also need to [upload your APNs Provider Authentication token or certificate to the Firebase Console](https://firebase.google.com/docs/cloud-messaging/ios/certs) at **Project Settings > Cloud Messaging > [Your Firebase App]**.
3. Ensure your iOS device is added to your Apple Developer portal as a test device.

### iOS Simulator

The iOS Simulator cannot register for remote notifications, and will not receive push notifications. In order to receive push notifications, you'll have to follow the steps above and run the app on a physical device.
