# 11.0.0
- [removed] **Breaking change**: The deprecated `FirebaseInAppMessagingSwift`
  module has been removed. See
  https://firebase.google.com/docs/ios/swift-migration for migration
  instructions.
- [changed] **Breaking Change**: The following Swift API have been renamed:
  - `FIRInAppMessagingDismissType` → `InAppMessagingDismissType`
  - `FIRInAppMessagingDisplayMessageType` → `InAppMessagingDisplayMessageType`
  - `FIRInAppMessagingDisplayTriggerType` → `InAppMessagingDisplayTriggerType`
  - `FIAMDisplayRenderErrorType` → `InAppMessagingDisplayRenderError`
  Note that `InAppMessagingDisplayRenderError` is now a native Swift error and
  can be directly caught (instead of catching an `NSError` and checking the
  error code).

# 10.27.0
- [fixed] Fixed crash at app start that affected CocoaPods users using static
  frameworks (#12882).

# 10.26.0
- [fixed] Fixed crash at app start that affected SwiftPM users (#12882).

# 10.25.0
- [changed] Removed usages of user defaults API to eliminate required reason
  impact.
- [changed] When installing In App Messaging via the zip distribution, its UI
  resource bundle is now embedded within the In App Messaging framework.
  Choose _Embed & Sign_ when integrating the framework. See the zip
  distribution's README.md for more instructions.

# 10.22.0
- [fixed] Fixed an `objc_retain` crash. (#12393)

# 10.17.0
- [deprecated] All of the public API from `FirebaseInAppMessagingSwift` can now
  be accessed through the `FirebaseInAppMessaging` module. Therefore,
  `FirebaseInAppMessagingSwift` has been deprecated, and will be removed in a
  future release. See https://firebase.google.com/docs/ios/swift-migration for
  migration instructions.

# 10.13.0
- [fixed] Fix Firebase tvOS podspec dependency for In App Messaging. (#11569)

# 10.10.0
- [fixed] Crash on InApp message presentation when a CarPlay scene is active (#9376)

# 10.0.0
- [removed] Removed `foo` constant from Swift `InAppMessagingPreviewHelpers` API (#10222).
- [fixed] Changed internal `dataChanged` symbol that triggered App Store warnings (#10276).

# 9.2.0
- [changed] Replaced unarchiveObjectWithFile with unarchivedObjectOfClass to conform to secure coding practices, and implemented NSSecureCoding (#9816).

# 8.12.0
- [fixed] In-App Messaging's test message does not include appData in response. This SDK fix will work once the backend is also updated (#9126).

# 8.11.0
- [fixed] InApp message is shown every new session (#8907).
- [fixed] Duplicate messages can occur when two campaigns are triggered by different events in In-App Messaging (#9070).

# 8.6.0
- [changed] Replaced conditionally-compiled APIs with `API_UNAVAILABLE` annotations on unsupported platforms (#8480).

# 8.5.0
- [added] Added support for unit testing with in-app message data objects (#8351).
- [added] Added support for prototyping custom in-app message views in SwiftUI (#8351).

# 8.4.0
- [fixed] Fixed build issues introduced in Xcode 13 beta 3. (#8401)

# 8.2.0
- [fixed] Fixed missing constraints warnings in default UI storyboard (#8205).

# 8.1.0
- [fixed] Fixed bug where image-only messages had the wrong message type in message callbacks (#8081).

# 7.11.0
- [fixed] Fixed SPM resource inclusion for in-app messages (#7715).

# 7.9.0
- [added] Added support for building custom in-app messages with SwiftUI (#7496).

# 7.7.0
- [fixed] Fixed accessibility experience for in-app messages (#7445).
- [fixed] Fixed conversion tracking for in-app messages with a conversion event but not a button / action URL (#7306).

# 7.5.0
- [fixed] Fixed failed assertion causing app to crash during test on device flow (#7299).

# 7.3.0
- [fixed] Fixed default display bug in apps that don't use `UISceneDelegate` (#6803).

# 7.0.0
- [removed] Removed deprecated elements of in-app messaging API.

# 0.24.0
- [changed] Functionally neutral import and header refactor to enable Swift Package
  Manager support.

# 0.23.0
- [fixed] Fixed an inaccurate doc comment in `InAppMessagingDisplay` (#5972).
- [changed] Functionally neutral source reorganization for preliminary Swift Package Manager support. (#6013)

# 0.22.0
- [changed] Functionally neutral updated import references for dependencies. (#5902)
- [changed] Updated In-App Messaging to consume the Protobuf-less AB Testing SDK (#5890).

# 0.20.2
- [fixed] Fixed log message for in-app messaging test on device flow (#5680).

# 0.20.1
- [fixed] Fixed an issue where clicks were counted for messages with no action URL (#5564).

# 0.19.3
- [fixed] Fixed an issue where GoogleUtilities wasn't explicitly listed as a dependency (#5282).

# 0.19.2
- [fixed] Internal fixes for test apps (#5171).

# 0.19.1
- [fixed] Fixed display issue with banner messages on iPad Pro 11" (#4714).
- [fixed] Fixed 400 errors from backend due to a bug in the Instance ID SDK (#3887).
- [changed] Internal change in in-app message A/B test flow (#5078).

# 0.19.0
- [added] Added SDK support for A/B testing in-app messages.

# 0.17.0
- [added] Added support for data bundles for in-app messages. Data bundles are additional key-value pairs that can be sent along with an in-app message (#4922).

# 0.16.0
- [changed] Consolidated backend and UI SDKs under `FirebaseInAppMessaging`. Developers should now use `pod Firebase/InAppMessaging` in their Podfile.
- [changed] `FIRIAMDefaultDisplayImpl` is no longer public.
- [changed] `FirebaseInAppMessagingDisplay` is now deprecated and should be removed from developers' Podfiles.
- [changed] Minimum iOS version is now 9.0.

# 0.15.6
- [fixed] Issues with nullability in card message (#4435).
- [fixed] Unit test failure with OCMock 3.5.0 (#4420).
- [fixed] Crash in test on device error flow (#4446).

# 0.15.5
- [added] Added support for UIScene based application lifecycle (#3927).

# 0.15.4
- [fixed] Undeprecated initializer for FIRInAppMessagingAction so it can be used going forward in custom UI display (#3545).

# 0.15.2
- [fixed] Fixed issue with messages to be triggered on app launch (#3237).

# 0.15.0
- [added] Added support for card in-app messages (#2947).
- [added] Added direct triggering (via FIAM SDK) of in-app messages (#3081).

# 0.14.1
- [fixed] Fixed an issue with messages not showing up from custom analytics event trigger (#2981).
- [fixed] Fixed crash from sending analytics events with no instance ID (#2988).

# 0.13.0
- [added] Added a feature allowing developers to programmatically register a delegate for updates on in-app engagement (impression, click, display errors).

# 0.12.0
- [changed] Separated UI functionality into a new open source SDK called FirebaseInAppMessagingDisplay.
- [fixed] Respect fetch between wait time returned from API responses.

# 0.11.0
- First Beta Release.
