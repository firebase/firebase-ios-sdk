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
Then select a scheme and press Command-u to build a component and run its unit tests.
