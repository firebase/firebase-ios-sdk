# v4.0.0-beta.1

This Firebase Crashlytics version includes the initial beta release of the Firebase Crashlytics SDK:

 - [feature] The SDK is now open-sourced. Take a look in our [GitHub repository](https://github.com/firebase/firebase-ios-sdk/tree/master/Crashlytics).
 - [feature] Added support for Catalyst (note that Crashlytics still supports tvOS and macOS).
 - [feature] Added new APIs that are more consistent with other Firebase SDKs and more intuitive to use. The new APIs also give your users more control over how you collect their data.
 - [removed] Removed the Fabric API Key. Now, Crashlytics uses the GoogleService-Info.plist file to associate your app with your project. If you linked your app from Fabric and want to upgrade to the new SDK, remove the Fabric API key from your `run` and `upload-symbols` scripts. We also recommend removing the Fabric section from your app's Info.plist (when you upgrade, Crashlytics uses the new configuration you set up in Firebase).
