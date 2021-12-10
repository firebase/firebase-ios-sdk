# Firebase 8.10.0
- [fixed] Fixed platform availability checks in Swift Package Manager that may prevent code
  completion for Analytics APIs on macOS and tvOS. (#9032)
- [added] Firebase now includes community supported Combine publishers. More details can be found
  [here](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseCombineSwift/README.md). (#7295)

# Firebase 8.9.0
- [added] Firebase introduces beta support for tvOS, macOS, and Catalyst.
  watchOS continues to be available with community support. Individual product
  details at
  https://firebase.google.com/docs/ios/learn-more#firebase_library_support_by_platform (#583)
- [changed] The minimum support tvOS version is now 12.0.
- [fixed] Force GoogleUtilities and GoogleDataTransport CocoaPods dependencies
  to be updated to latest minor versions. (#8733)

# Firebase 8.8.1
- [fixed] Swift Package Manager only release to force GoogleUtilities and GoogleDataTransport
  to be updated to latest current bug-fix versions. (#8728)

# Firebase 8.3.1
- [fixed] Swift Package Manager only release to fix an 8.3.0 tagging issue impacting some users. (#8367)

# Firebase 8.2.0
- [fixed] Stop flooding Swift Package Manager projects with Firebase test schemes. (#8167)
- [fixed] Removed "Invalid Exclude" warnings for Swift Package Manager using Xcode 13 beta 1.

# Firebase 8.1.1
- [fixed] Fixed an issue where apps were getting rejected for a formerly-public method name
  removed in iOS 15. Only FirebaseAnalytics is updated for this release. (#8222)

# Firebase 8.0.0
- [removed] The deprecated Firebase InstanceID has been removed. Use Firebase Installations to manage
  app instance and use Firebase Messaging to manage FCM registration token instead. (#7970)
- [changed] The experimental Carthage distribution is temporarily discontinued pending integration
  with the upcoming [Carthage 0.38.0 release](https://github.com/Carthage/Carthage/pull/3152) with
  support for binary xcframeworks. In the meantime, a mix of 7.4.0 and 7.11.0 will be the latest
  Carthage distribution. Use the [zip distribution](https://firebase.google.com/download/ios) as an
  alternative way to get the latest 8.x binary distribution.
- [removed] Build warnings will no longer be generated to warn about missing capabilities resulting
  from not including FirebaseAnalytics in the app. See the Firebase docs instead. (#7487)
- [removed] The `Firebase/AdMob` CocoaPods subspec has been removed. Use the `Google-Mobile-Ads-SDK`
  CocoaPod instead. (#7833)
- [removed] The `Firebase/MLModelInterpreter` CocoaPods subspec has been removed. Use the
 `Firebase/MLModelDownloader` subspec instead.
  CocoaPod instead.
- [removed] The `Firebase/MLVision` CocoaPods subspec has been removed. Use the
  `GoogleMLKit` CocoaPod instead.
- [added] The Swift Package Manager distribution has exited beta and is now generally available for
  use.
- [changed] The Swift Package Manager distribution now requires at least iOS 11.0. The CocoaPods
  distribution continues to support iOS 10.0.
- [changed] The Swift Package Manager distribution now requires at least watchOS 7.0 for products
  that support watchOS. The CocoaPods distribution continues to support watchOS 6.0 with the
  exception of FirebaseDatabase.
- [changed] Migrate `transform:` callsites and introduce breaking version of
  GoogleDataTransport (9.0). (#7899)

# Firebase 7.10.0
- [changed] Update Nanopb to version 0.3.9.8. It fixes a possible security issue. (#7787)

# FirebaseCore 7.7.0
- [changed] Deprecated FirebaseMLModelInterpreter and FirebaseMLVision.
- [added] Introduced FirebaseMLModelDownloader.
- [fixed] Fixed missing doc comment in `FirebaseVersion()`. (#7506)
- [changed] Minimum required Xcode version for Zip and Carthage distributions changed to 12.2 (was 12.0).
- [added] The zip distribution now includes Catalyst arm64 simulator slices. (#7007)

# FirebaseCore 7.6.0
- [fixed] Fixed build warnings introduced with Xcode 12.5. (#7431)

# Firebase 7.5.0
- [fixed] Fixed potential deadlock with objc_copyImageNames call. (#7310)

# Firebase 7.4.0
- [changed] Patch update to nanopb 0.3.9.7 that fixes a memory leak and other issues. (#7090)
- [added] Zip distribution now includes community supported macOS and tvOS libraries. Product
  support detailed
  [here](https://github.com/firebase/firebase-ios-sdk#tvos-macos-watchos-and-catalyst).

# Firebase 7.3.0
- [added] Added FirebaseAppDistribution-Beta product to Swift Package Manager. (#7045)

# Firebase 7.2.0
- [fixed] Reduced `FirebaseApp.configure()` and `+[FIRApp registerInternalLibrary:withName:]` impact on app launch time. (#6902)
- [added] Added arm64 simulator support to support new Apple silicon based Macs.
- [changed] Due to the new arm64 simulator support, Xcode 12 is now required for any binary
  products (Analytics, Performance, zip file distribution).

# Firebase 7.0.0
- [changed] Update minimum iOS version to iOS 10 except for Analytics which is now iOS 9. (#4847)
- [changed] Update minimum macOS version to 10.12.
- [added] Swift Package Manager support for Firebase Messaging. (#5641)
- [added] Swift Package Manager support for Auth, Crashlytics, Messaging, and Storage watchOS
  targets. (#6584)
- [changed] The pods developed in this repo are no longer hard coded to be built as static
  frameworks. Instead, their linkage will be controlled by the Podfile. Use the Podfile
  option `use_frameworks! :linkage => :static` to get the Firebase 6.x linkage behavior. (#2022)
- [changed] Firebase no longer uses the CocoaPods `private_headers` feature to expose internal
  APIs. (#6572)
- [removed] Removed broken `FirebaseOptions()` initializer. Use `init(contentsOfFile:)` or
  `init(googleAppID:gcmSenderID:)` instead. (#6633)
- [changed] All Firebase pods now have the same version. (#6295)
- [changed] In CocoaPods, Firebase betas are now indicated in the version tag. In SwiftPM, beta
  is appended to the product name.
- [changed] The version must now be specified for the two Swift-only Firebase CocoaPods in the
  Podfile like `pod 'FirebaseFirestoreSwift', '~> 7.0-beta'`.
- [added] `FirebaseVersion()` - Swift `FIRFirebaseVersion()` - ObjC API to access the Firebase
  installation version.

# Firebase 6.34.0
- [fixed] Removed warning related to missing Analytics framework for non-iOS builds since the
  framework isn't available on those platforms. (#6500)

# Firebase 6.33.0
- [fixed] Swift Package Manager - Define system framework and system library dependencies. This
  resolves undefined symbol issues for system dependencies. (#6408, #6413)
- [fixed] Swift Package Manager - Fixed build warnings related to minimum iOS version. (#6449)
- [fixed] Enable Firebase pod support for Auth and Crashlytics watchOS platform. (#4558)
- [fixed] Carthage - Some frameworks were missing Info.plist files. (#5562)

# Firebase 6.32.0
- [changed] Swift Package Manager - It's no longer necessary to select the Firebase or
  FirebaseCore products. Their build targets are implicitly selected when choosing any other
  Firebase product. If migrating from 6.31-spm-beta, you may need to remove those targets from
  the `Frameworks, Libraries, and Embedded Content` Build Setting on the General tab.

# Firebase 6.31.1
- [fixed] Sporadic missing FirebaseApp symbol build issue introduced in Firebase 6.28.0. (#6341)

# Firebase 6.31.0 FirebaseCore 6.10.1 -- M78
- [added] Beta release of Swift Package Manager. Details
  [here](https://github.com/firebase/firebase-ios-sdk/blob/master/SwiftPackageManager.md). (#3136)
- [changed] Firebase's dependencies on nanopb are updated from version 0.3.9.5 to
  version 0.3.9.6 (1.30906.0 in CocoaPods).

# v6.10.0 -- M77
- [changed] Functionally neutral public header refactor in preparation for Swift Package
  Manager support. Applies to FirebaseCore, FirebaseABTesting, FirebaseAuth, FirebaseCrashlytics,
  FirebaseDatabase, FirebaseFirestore, FirebaseFunctions, FirebaseInstallations,
  FirebaseRemoteConfig, FirebaseStorage, and GoogleDataTransport.

# v6.9.0 -- M75
- [changed] Added thread safety to `[FIROptions defaultOptions]` method. (#5915)
- [changed] Updated GoogleUtilities and GoogleDataTransport imports. The GoogleDataTransportCCTSupport
  pod/framework should no longer be linked along with Firebase. (#5824)

# v6.8.0 -- M73
- [changed] Functionally neutral refactor to simplify FirebaseCore's header usage and replace
  Interop pods with headers only. This change is the reason most of the Firebase pods have a minor
  version update and why there may not be another specific release note.

# v6.7.1 -- M71
- [fixed] Fixed `FirebaseApp`s `bundleID` verification, allowing exact `bundleID` matches
  for extensions. (#5126)

# v6.7.0 -- M70
- [fixed] Updated nanopb to 0.3.9.5 (across all Firebase pods). This includes a fix for
  [CVE-2020-5235](https://github.com/nanopb/nanopb/security/advisories/GHSA-gcx3-7m76-287p).
  Note that the versioning scheme for the nanopb CocoaPod has changed;
  see https://github.com/google/nanopb-podspec for more details. (#5191)

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
