# Firebase iOS Open Source Development [![Build Status](https://travis-ci.org/firebase/firebase-ios-sdk.svg?branch=master)](https://travis-ci.org/firebase/firebase-ios-sdk)

This repository contains a subset of the Firebase iOS SDK source. It currently
includes FirebaseCore, FirebaseAuth, FirebaseDatabase, FirebaseMessaging,
FirebaseStorage, and Firestore.

Firebase is an app development platform with tools to help you build, grow and
monetize your app. More information about Firebase can be found at
[https://firebase.google.com](https://firebase.google.com).

**Note: This page and repo is for those interested in exploring the internals of
the Firebase iOS SDK. If you're interested in using the Firebase iOS SDK, start at
[https://firebase.google.com/docs/ios/setup](https://firebase.google.com/docs/ios/setup).**

## Context

This repo contains a fully functional development environment for FirebaseCore,
FirebaseAuth, FirebaseDatabase, FirebaseMessaging, and FirebaseStorage. By
following the usage instructions below, they can be developed and debugged with
unit tests, integration tests, and reference samples.

Note, however, that the resulting FirebaseCommunity pod is NOT interoperable with the
official Firebase release pods because of different pod dependency definitions.

Firestore has not yet been integrated with FirebaseCommunity. In the
meantime, it has a self contained Xcode project. See
[Firestore/README.md](Firestore/README.md).

Instructions and a script to build replaceable static library
frameworks at [BuildFrameworks](BuildFrameworks). The
resulting frameworks can be used to replace frameworks delivered by CocoaPods or
the zip distribution for development.

## Usage

```
$ git clone git@github.com:firebase/firebase-ios-sdk.git
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

## Specific Component Instructions
See the sections below for any special instructions for those components.

### Firebase Auth

If you're doing specific Firebase Auth development, see
[AuthSamples/README.md](AuthSamples/README.md) for instructions about
building and running the FirebaseAuth pod along with various samples and tests.

### Firebase Database

To run the Database Integration tests, make your database authentication rules
[public](https://firebase.google.com/docs/database/security/quickstart).

### Firebase Storage

To run the Storage Integration tests, follow the instructions in
[FIRStorageIntegrationTests.m](Example/Storage/Tests/Integration/FIRStorageIntegrationTests.m).

### Firebase Messaging

To use Messaging, include `pod 'FirebaseInstanceID'` in your Podfile, in addition to `pod 'FirebaseCommunity/Messaging'`.

#### Push Notifications

Push notifications can only be delivered to specially provisioned App IDs in the developer portal. In order to actually test receiving push notifications, you will need to:

1. Change the bundle identifier of the sample app to something you own in your Apple Developer account, and enable that App ID for push notifications.
2. You'll also need to [upload your APNs Provider Authentication Key or certificate to the Firebase Console](https://firebase.google.com/docs/cloud-messaging/ios/certs) at **Project Settings > Cloud Messaging > [Your Firebase App]**.
3. Ensure your iOS device is added to your Apple Developer portal as a test device.

#### iOS Simulator

The iOS Simulator cannot register for remote notifications, and will not receive push notifications. In order to receive push notifications, you'll have to follow the steps above and run the app on a physical device.

## Community Supported Efforts

We've seen an amazing amount of interest and contributions to improve the Firebase SDKs, and we are very grateful!  We'd like to empower as many developers as we can to be able to use Firebase and participate in the Firebase community.

Note that if you are using CocoaPods and using the FirebaseCommunity podspec (the one in this repo), you cannot bring in Pods from the official Firebase podspec, because of duplicated symbol conflicts. If you're not using one of the open-source SDKs in this repo for development purposes, we recommend using the regular Firebase pods for the best experience.

To get started using the FirebaseCommunity SDKs, here is a typical Podfile:

```
use_frameworks!

target 'MyAppTarget' do
  platform :ios, '8.0'
  pod 'FirebaseCommunity/Database'
end
```
1. Replace `MyAppTarget` with the name of the target in your Xcode project.
2. Specify the subspec in the pod specification for each Firebase component wanted. Database is
used in the example above. Storage, Auth, and Messaging are other options.

### macOS
FirebaseAuth, FirebaseCore, FirebaseDatabase and FirebaseStorage now compile, run unit tests, and work on macOS, thanks to contributions from the community. There are a few tweaks needed, like ensuring iOS-only or macOS-only code is correctly guarded with checks for `TARGET_OS_IOS` and `TARGET_OS_OSX`.

Keep in mind that macOS is not officially supported by Firebase, and this repository is actively developed primarily for iOS. While we can catch basic unit test issues with Travis, there may be some changes where the SDK no longer works as expected on macOS. If you encounter this, please [file an issue](https://github.com/firebase/firebase-ios-sdk/issues) for it.

## Roadmap

See [Roadmap](ROADMAP.md) for more about the Firebase iOS SDK Open Source
plans and directions.

## Contributing

See [Contributing](CONTRIBUTING.md) for more information on contributing to the Firebase
iOS SDK.

## License

The contents of this repository is licensed under the
[Apache License, version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Your use of Firebase is governed by the
[Terms of Service for Firebase Services](https://firebase.google.com/terms/).
