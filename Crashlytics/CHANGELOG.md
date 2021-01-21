# Unreleased
- [changed] Improve start-up performance by moving some initialization work to a background thread (#7332).
- [changed] Updated upload-symbols to a version that is notarized to avoid macOS security alerts (#7323).

# v7.4.0
- [changed] Removed obsolete crash reporting mechanism from the SDK (#7076).

# v7.3.0
- [added] Added Crashlytics support for x86 apps running on Apple Silicon via Rosetta 2
- [changed] Decreased Crashlytics CocoaPods minimum deployment target from iOS 10 to iOS 9
- [changed] Removed obsolete API calls from upload-symbols
- [changed] Removed obsolete onboarding calls from the SDK.

# v7.1.0
- [fixed] Fixed an issue where symbol uploads would fail when there are spaces in the project path, particularly in Unity builds (#6789).
- [changed] Added additional logging when settings requests fail with a 404 status to help customers debug onboarding issues (#6847).

# v4.6.2

- [changed] Improved upload-symbols conversion speed. Customers with large dSYMs should see a significant improvement in the time it takes to upload Crashlytics symbols.
- [fixed] Fixed Apple Watch crash related to `sigaction` (#6434).

# v4.6.0

- [added] Added stackFrameWithAddress API for recording custom errors that are symbolicated on the backend (#5975).
- [fixed] Fixed comment typos (#6363).
- [fixed] Remove device information from binary image data crash info entries (#6382).

# v4.5.0

- [fixed] Fixed a compiler warning and removed unused networking code (#6210).
- [fixed] Fixed a crash that occurred rarely when trying to restart a URL session task without a valid request (#5984).
- [added] Introduced watchOS support (#6262).

# v4.3.1

- [fixed] Fixed a segmentation fault that could occur when writing crash contexts to disk (#6048).

# v4.3.0

- [changed] Add dispatch_once for opening sdk log file. (#5904)
- [changed] Functionally neutral updated import references for dependencies. (#5902)

# v4.2.0

- [changed] Removed an unnecessary linker rule for embedding the Info.plist. (#5804)

# v4.1.1

- [fixed] Fixed a crash that could occur if certain plist fields necessary to create Crashlytics records were missing at runtime. Also added some diagnostic logging to make the issue cause more explicit (#5565).

# v4.1.0

- [fixed] Fixed unchecked `malloc`s in Crashlytics (#5428).
- [fixed] Fixed an instance of undefined behavior when loading files from disk (#5454).

# v4.0.0

 - [changed] The Firebase Crashlytics SDK is now generally available.

# v4.0.0-beta.7

 - [changed] Increased network timeout for symbol uploads to improve reliability on limited internet connections. (#5228)

# v4.0.0-beta.6

 - [added] Added a new API to record custom exception models and stacktraces to Crashlytics. This is a replacement for the `recordCustomException` API that existed in the Fabric Crashlytics SDK (#5055)
 - [fixed] Fixed an issue with the `sendUnsentReports` API where reports wouldn't be uploaded until the method was called twice in specific instances (#5060)
 - [changed] Changed Crashlytics to use GoogleDataTransport to upload crashes (#4989)
 - [changed] Changed the origin that Crashlytics uses to register Crash events for Crash Free Users. Ensure you have installed Firebase Analytics version 6.3.1 or above (#5030)

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
