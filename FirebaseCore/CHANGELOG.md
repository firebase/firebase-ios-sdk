# v6.7.0 -- M70
- [fixed] Updated the nanopb version dependency across Firebase to 0.3.9.5 that
  includes a vulnerability fix. To properly manage nanopb versions, Firebase has
  switched to a new versioning scheme in which the nanopb CocoaPods
  version 1.300905.0 maps to nanopb version 0.3.9.5. Full details at
  https://github.com/google/nanopb-podspec. (#5191)

# v6.6.7 -- M69
- [fixed] Fixed Carthage installation failures involving `Protobuf.framework`.
  `Protobuf.framework` is now separately installable via adding
  `FirebaseProtobufBinary.json` to the Cartfile. Full details in the [Carthage usage
  instructions](https://github.com/firebase/firebase-ios-sdk/blob/master/Carthage.md#carthage-usage).
  (#5276)

# v6.6.6 -- M68
- [fixed] Fixed unincluded umbrella header warnings in Carthage and zip distributions
  introduced in Firebase 6.21.0. (#5209)

# v6.6.5 -- M67
- [changed] The zip distribution is now comprised of xcframeworks instead of
  frameworks. This provides a binary distribution for the community supported
  Firebase for Catalyst. See the zip's README for additional details.

- [fixed] The FirebaseCoreDiagnostic.framework in the Carthage distribution
  now includes an Info.plist. (#4917)

- [changed] The arm64e slice is no longer included the zip
  distribution's xcframeworks. The slice will be removed from the remaining
  frameworks in a subsequent release. We will restore once arm64e is
  officially supported by Apple.

# v6.6.4 -- M66
- [changed] Added an Apple platform flag (ios/macos/watchos/etc.) to `firebaseUserAgent`.
  The information will be used to support product decisions related to Apple platforms,
  e.g. prioritizing watchOS support, etc. (#4939)

# v6.6.3 -- M65
- [fixed] Fix Zip Builder module map generation that could cause linker missing
  symbol errors in the 6.14.0 through 6.16.0 binary release distributions. (#4819)

# v6.6.1 -- M63
- [changed] Minimum required Xcode version changed to 10.3 (was 10.1).

# v6.6.0 -- M62
- [changed] Reorganized directory structure.
- [changed] The following SDKs introduce a new transitive dependency on the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com):
  - Analytics
  - Cloud Messaging
  - Remote Config
  - In-App Messaging
  - A/B Testing
  - Performance Monitoring
  - ML Kit
  - Instance ID

The Firebase Installations SDK introduces the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com). Developers that use API-restrictions for their API-Keys may experience blocked requests (https://stackoverflow.com/questions/58495985/). A solution is available [here](../../FirebaseInstallations/API_KEY_RESTRICTIONS.md). (#4533)

# v6.5.0 -- M61
- [added] Updated the binary distributions to include arm64e slices. See
  https://developer.apple.com/documentation/security/preparing_your_app_to_work_with_pointer_authentication.
  Support for the open source libraries is now included in the zip and Carthage
  distributions. All libraries now support building for arm64e except the MLKit
  ones who's support is TBD. (#4110)

- [changed] The directory structure of the zip distribution has changed to include
  full name of each Firebase pod name in the directory structure. For example, the former
  `Storage` directory is now `FirebaseStorage`.

- [changed] Speed up initialization by lazily registering for the user agent. (#1306)

- [added] Added a Swift usage flag to `firebaseUserAgent`. The information will
  be used to support product decisions related to Swift, e.g. adding a Swift specific
  API, SDKs, etc. (#4448)

# v6.4.0 -- M60
- [changed] Administrative minor version update to prepare for an upcoming Firebase pod
  open source.

# v6.3.3 -- M59
- [changed] Carthage and zip file distributions are now built with Xcode 11.0.
  The Carthage and zip file distributions no longer support Xcode 10.3 and below.

# v6.3.2 -- M58
- [fixed] Fix container instantiation timing, IID startup. (#4030)
- [changed] Open-sourced Firebase pod. This enables `import Firebase` module
  support for tvOS and macOS. (#4021)

# v6.3.1 -- M57
- [fixed] Fixed race condition in component container. (#3967, #3924)

# v6.3.0 -- M56
- [changed] Transitive GoogleDataTransport dependency incremented to v2.0.0. (#3729)
- [fixed] Fixed "expiclitlySet" typo. (#3853)

# v6.2.0 -- M53
- [added] Added AppKit dependency on macOS and UIKit dependency on iOS and tvOS. (#3459)
- [added] Added support for Firebase Segmentation. (#3430)
- [changed] Moved core diagnostics log to app launch when core data collection is enabled. (#3437)
- [changed] Open-sourced the Firebase Core Diagnostics SDK. (#3129)

# 2019-07-18 -- v6.1.0 -- M52
- [added] `FIROptions.appGroupID` property added to configure the App Group identifier required to share
  data between the application and the application extensions. (#3293)

# 2019-05-21 -- v6.0.1 -- M48
- [changed] Allowed `FirebaseApp` name to accept any alpha-numeric character instead of only ASCII. (#2609)

# 2019-05-07 -- v6.0.0 -- M47
- [changed] Added support for CocoaPods 1.7.x `:generate_multiple_pod_projects` feature. (#2751)
- [removed] Remove FIRAnalyticsConfiguration from Public header. Use from FirebaseAnalytics. (#2728)
- [changed] Remove runtime warning for missing analytics in favor of one at build time. (#2734)

# 2019-04-02 -- v5.4.1 -- M46
- [changed] Avoid using NSRegularExpression in FIRApp.
- [changed] Improve error meessage for invalid app names. (#2614)
- [changed] FIRApp thread safety fixes. (#2639)

# 2019-03-19 -- v5.4.0 -- M45
- [changed] Allow Bundle IDs that have a valid prefix to enable richer extension support. (#2515)
- [changed] Deprecated `FIRAnalyticsConfiguration` API in favor of new methods on the Analytics SDK.
  Please call the new APIs directly: Enable/disable Analytics with `Analytics.setAnalyticsCollectionEnabled(_)`
  and modify the session timeout interval with `Analytics.setSessionTimeoutInterval(_)`.

# 2019-01-22 -- v5.2.0 -- M41
- [changed] Added a registerInternalLibrary API. Now other Firebase libraries register with FirebaseCore
  instead of FirebaseCore needing all of its clients' versions built in.
  Firebase 5.16.0 makes this transition for FirebaseAnalytics, FirebaseAuth, FirebaseDatabase,
  FirebaseDynamicLinks, FirebaseFirestore, FirebaseFunctions, FirebaseInstanceID, FirebaseMessaging,
  and FirebaseStorage.

# 2018-12-18 -- v5.1.10 -- M40
- [changed] Removed some internal authentication methods on FIRApp which are no longer used thanks to the interop platform.

# 2018-10-31 -- v5.1.7 -- M37
- [fixed] Fixed static analysis warning for improper `nil` comparison. (#2034)
- [changed] Assign the default app before posting notifications. (#2024)
- [changed] Remove unnecessary notification flag. (#1993)
- [changed] Wrap diagnostics notification in collection flag check. (#1979)

# 2018-08-28 -- v5.1.2 -- M32
- [fixed] Clarified wording in `FirebaseAnalytics not available` log message. (#1653)

# 2018-07-31 -- v5.1.0 -- M30
- [feature] Added a global data collection flag to use when individual product flags are not set. (#1583)

# 2018-06-19 -- v5.0.4 -- M28
- [fixed] Fixed a thread sanitizer error (#1390)
- [fixed] Updated FirebaseCore.podspec so that it works with cocoapods-packager. (#1378)

# 2018-05-29 -- v5.0.2 -- M26
- [changed] Delayed library registration call from `+load` to `+initialize`. (#1305)

# 2018-05-15 -- v5.0.1 -- M25.1
- [fixed] Eliminated duplicate symbol in CocoaPods `-all_load build` (#1223)

# 2018-05-08 -- v5.0.0 -- M25
- [changed] Removed `UIKit` import from `FIRApp.h`.
- [changed] Removed deprecated methods.

# 2018-03-06 -- v4.0.16 -- M22
- [changed] Addresses CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF warnings that surface in newer versions of Xcode and CocoaPods.

# 2018-01-18 -- v4.0.14 -- M21.1
- [changed] Removed AppKit dependency for community macOS build.

# 2017-11-30 -- v4.0.12 -- M20.2
- [fixed] Removed `FIR_SWIFT_NAME` macro, replaced with proper `NS_SWIFT_NAME`.

# 2017-11-14 -- v4.0.11 -- M20.1
- [feature] Added `-FIRLoggerForceSTDERR` launch argument flag to force STDERR
  output for all Firebase logging

# 2017-08-25 -- v4.0.6 -- M18.1
- [changed] Removed unused method

# 2017-08-09 -- v4.0.5 -- M18.0
- [changed] Log an error for an incorrectly configured bundle ID instead of an info
  message.

# 2017-07-12 -- v4.0.4 -- M17.4
- [changed] Switched to using the https://cocoapods.org/pods/nanopb pod instead of
  linking nanopb in (preventing linker conflicts).

# 2017-06-06 -- v4.0.1 -- M17.1
- [fixed] Improved diagnostic messages for Swift

# 2017-05-17 -- v4.0.0 -- M17
- [changed] Update FIROptions to have a simpler constructor and mutable properties
- [feature] Swift naming update, FIR prefix dropped
- [changed] Internal cleanup for open source release
