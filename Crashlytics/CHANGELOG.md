
# v4.0.0-beta.6

 - [added] Added a new API to record custom exception models and stacktraces to Crashlytics. This is a replacement for the `recordCustomException` API that existed in the Fabric Crashlytics SDK (#5055)
 - [fixed] Fixed an issue with the `sendUnsentReports` API where reports wouldn't be uploaded until the method was called twice in specific instances (#5060)
 - [changed] Changed the origin that Crashlytics uses to register Crash events for Crash Free Users. Ensure you have installed Firebase Analytics version x.x.x or above (#5030)

# v4.0.0-beta.5

- [changed] Changed two endpoints in the Firebase Crashlytics SDK with no expected end-user impact (#4953, #4988).

# v4.0.0-beta.4

- [fixed] Fixed symbol collisions with the legacy Fabric Crashlytics SDK and added a warning not to include both (#4753, #4755)
- [fixed] Added crash prevention checks (#4661)

# v4.0.0-beta.3

- [fixed] Fixed an import declaration for installing Crashlytics. Previously, the declaration caused a compile error when you installed using CocoaPods with the `generate_multiple_pods_project` flag set to true (#4786)

# v4.0.0-beta.2

- [fixed] Fixed VeraCode scanner issues for unchecked error conditions (#4669)

# v4.0.0-beta.1

This Firebase Crashlytics version includes the initial beta release of the Firebase Crashlytics SDK:

 - [feature] The SDK is now open-sourced. Take a look in our [GitHub repository](https://github.com/firebase/firebase-ios-sdk/tree/master/Crashlytics).
 - [feature] Added support for Catalyst (note that Crashlytics still supports tvOS and macOS).
 - [feature] Added new APIs that are more consistent with other Firebase SDKs and more intuitive to use. The new APIs also give your users more control over how you collect their data.
 - [removed] Removed the Fabric API Key. Now, Crashlytics uses the GoogleService-Info.plist file to associate your app with your project. If you linked your app from Fabric and want to upgrade to the new SDK, remove the Fabric API key from your `run` and `upload-symbols` scripts. We also recommend removing the Fabric section from your app's Info.plist (when you upgrade, Crashlytics uses the new configuration you set up in Firebase).
