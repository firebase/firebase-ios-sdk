# Firebase & Combine Sample

This sample demonstrates how to use Firebase's Combine APIs.

## How to use

### Set up a Firebase project

1. Create a new Firebase project via the [Firebase console](https://console.firebase.google.com/)
2. Enable the required Firebase services in the Firebase project you created in step 1
   * Firebase Authentication
      * Enable Anonymous Auth
3. Register this demo app as an iOS project
4. Download `GoogleServices-Info.plist` and drag it into your project (it's easiest if you place it just next to `Info.plist`)


### Enable Combine

Currently, Combine support for Firebase is still under development, which is why we haven't enabled the respective Swift Package Manager products yet. You need to do so yourself:

In `Package.swift`, find the following lines:

```swift
    // TODO: Re-enable after API review passes.
    // .library(
    //   name: "FirebaseCombineSwift-Beta",
    //   targets: ["FirebaseCombineSwift"]
    // ),
    // .library(
    //   name: "FirebaseAuthCombineSwift-Beta",
    //   targets: ["FirebaseAuthCombineSwift"]
    // ),
    // .library(
    //   name: "FirebaseFunctionsCombineSwift-Beta",
    //   targets: ["FirebaseFunctionsCombineSwift"]
    // ),
    // .library(
    //   name: "FirebaseStorageCombineSwift-Beta",
    //   targets: ["FirebaseStorageCombineSwift"]
    // ),
```

 and uncomment them:
 ```swift
    // TODO: Re-enable after API review passes.
    .library(
      name: "FirebaseCombineSwift-Beta",
      targets: ["FirebaseCombineSwift"]
    ),
    .library(
      name: "FirebaseAuthCombineSwift-Beta",
      targets: ["FirebaseAuthCombineSwift"]
    ),
    .library(
      name: "FirebaseFunctionsCombineSwift-Beta",
      targets: ["FirebaseFunctionsCombineSwift"]
    ),
    .library(
      name: "FirebaseStorageCombineSwift-Beta",
      targets: ["FirebaseStorageCombineSwift"]
    ),
 ```

 The app should now compile.