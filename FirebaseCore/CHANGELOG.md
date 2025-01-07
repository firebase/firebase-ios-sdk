# Firebase 11.4.2
- [fixed] CocoaPods only release to fix iOS 12 build failure resulting from
  incomplete implementation in the FirebaseCoreInternal CocoaPod.

# Firebase 11.4.1
- [fixed] CocoaPods only release to revert breaking change in
  `FirebaseCoreExtension` SDK. (#13942)

# Firebase 11.4.0
- [fixed] Fixed issue building documentation with some Firebase products. (#13756)

# Firebase 11.0.0
- [changed] **Breaking change**: Firebase's minimum supported versions have
  updated for the following platforms:
    - | Platform  | Firebase 11 |
      | ------------- | ------------- |
      | iOS  | **13.0**  |
      | tvOS  | **13.0**  |
      | macOS  | **10.15**  |
      | watchOS  | 7.0  |
  - FirebaseAnalytics and FirebaseCrashlytics also continue to support iOS 12.0.
- [removed] **Breaking change**: The deprecated Swift extension SDKs for
  Analytics, Firestore, Database, Remote Config and In App Messaging have
  been removed. See
  https://firebase.google.com/docs/ios/swift-migration for migration
  instructions.
- Update underlying FIRLogger implementation from `asl` to `os_log`.
- Remove `FIRLoggerForceSTDERR` configuration option.
- [changed] Move `Timestamp` class into `FirebaseCore`. `FirebaseFirestore.Timestamp`
  was changed to `FirebaseCore.Timestamp`. (#13221)

# Firebase 10.25.0
- [changed] Firebase now requires at least Xcode 15.2. See
  https://developer.apple.com/news/?id=fxu2qp7b for more info.
- [Zip Distribution] Update zip integration instructions with tips for
  preserving symlinks and protecting code signatures.

# Firebase 10.24.0
- Fix validation issue for macOS and macCatalyst XCFrameworks related to
  framework directory structure. (#12587)
- Extend community watchOS support to zip and Carthage distributions. See
  https://firebase.google.com/docs/ios/learn-more#firebase_library_support_by_platform
  for the Firebase products included. (#8731)
- Add code signatures to all of Firebase's binary artifacts (#12238).

# Firebase 10.23.1
- [Swift Package Manager / CocoaPods] Fixes the macOS/Catalyst xcframework
  structure issue in Firebase Analytics blocking submission via Xcode 15.3.

# Firebase 10.23.0
- Fix validation issue for macOS and macCatalyst XCFrameworks. (#12505)

# Firebase 10.22.1
- [Swift Package Manager / CocoaPods] Fix app validation issues on Xcode 15.3
  for those using the `FirebaseAnalyticsOnDeviceConversion` SDK. This issue was
  caused by embedding an incomplete `Info.plist` from a dependency of the SDK.
  (#12441)

# Firebase 10.22.0
- [Swift Package Manager] Firebase now enforces a Swift 5.7.1 minimum version,
  which is aligned with the Xcode 14.1 minimum. (#12350)
- Revert Firebase 10.20.0 change that removed `Info.plist` files from
  static xcframeworks (#12390).
- Added privacy manifests for Firebase SDKs named in
  https://developer.apple.com/support/third-party-SDK-requirements/. Please
  review https://firebase.google.com/docs/ios/app-store-data-collection for
  updated guidance on interpreting Firebase's privacy manifests and completing
  app Privacy Nutrition Labels. (#11490)
- Fixed validation issues in Xcode 15.3 that affected binary distributions
  including Analytics, Firestore (SwiftPM binary distribution), and the
  Firebase zip distribution. (#12441)
- [Zip Distribution] The manual integration instructions found in the
  `Firebase.zip` have been updated for Xcode 15 users. The updated instructions
  call for embedding SDKs dragged in from the `Firebase.zip`. This will enable
  Xcode's tooling to detect privacy manifests bundled within the xcframework.
- [Zip Distribution] Several xcframeworks have been renamed to resolve the above
  Xcode 15.3 validation issues. Please ensure that the following renamed
  xcframeworks are removed from your project when upgrading (#12437, #12447):
    - `abseil.xcframework` to `absl.xcframework`
    - `BoringSSL-GRPC.xcframework` to `openssl_grpc.xcframework`
    - `gRPC-Core.xcframework` to `grpc.xcframework`
    - `gRPC-C++.xcframework` to `grpcpp.xcframework`
    - `leveldb-library.xcframework` to `leveldb.xcframework`
    - `PromisesSwift.xcframework` to `Promises.xcframework`

# Firebase 10.21.0
- Firebase now requires at least CocoaPods version 1.12.0 to enable privacy
  manifest support.

# Firebase 10.20.0
- The following change only applies to those using a binary distribution of
  a Firebase SDK(s): In preparation for supporting Privacy Manifests, each
  platform framework directory within a static xcframework no longer contains
  an `Info.plist` file (#12243).

# Firebase 10.14.0
- For developers building for visionOS, Xcode 15 beta 6 or later is required.

# Firebase 10.13.0
- For developers building for visionOS, Xcode 15 beta 5 or later is required.

# Firebase 10.12.0
- For developers building for visionOS, using products that use the Keychain
  (e.g. FirebaseAuth) may fail to access the keychain on the visionOS
  simulator. To work around this, add the Keychain Sharing capability to the
  visionOS target and explicitly add a keychain group (e.g. the bundle ID).
- Firebase's Swift Package Manager distribution does not support
  Xcode 15 Beta 1. Please use Xcode 15 Beta 2 or later.

# Firebase 10.11.0
- [changed] Improved error reporting for misnamed configuration plist files (#11317).

# Firebase 10.10.0
- [changed] Firebase now requires at least Xcode 14.1.

# Firebase 10.8.1
- [fixed] Swift Package Manager only release to fix a 10.8.0 Firestore issue
  impacting macCatalyst. (#11119)

# Firebase 10.8.0
- Fix new build warnings introduced by Xcode 14.3. (#11059)
- [changed] The Firebase Swift package now requires the Swift 5.6 toolchain (Xcode 13.3) to build.

# Firebase 10.4.0
- Deprecate `androidClientID` and `trackingID` from FirebaseOptions. (#10520)

# Firebase 10.2.0
- Update GTMSessionFetcher dependency specifications to enable support for the compatible
  GTMSessionFetcher 3.x versions.

# Firebase 10.1.0
- [changed] Bitcode is no longer included in Firebase binary distributions. Xcode 14 does not
  support bitcode. tvOS apps using a Firebase binary distribution will now need to use
  Xcode 14. (#10372)

# Firebase 10.0.0
- [changed] **Breaking change**: Firebase's minimum supported versions have
  updated for the following platforms:
  - If using **CocoaPods**:
    - | Platform  | Firebase 9 | Firebase 10 |
      | ------------- | ------------- | ------------- |
      | iOS  | 10.0  | **11.0**  |
      | tvOS  | 10.0  | **12.0**  |
      | macOS  | 10.12  | **10.13**  |
      | watchOS  | 6.0  | 6.0  |
  - If using **Swift Package Manager**:
    - | Platform  | Firebase 9 | Firebase 10 |
      | ------------- | ------------- | ------------- |
      | iOS  | 11.0  | 11.0  |
      | tvOS  | 12.0  | 12.0  |
      | macOS  | 10.12  | **10.13**  |
      | watchOS  | 7.0  | 7.0  |
  - If using **Carthage** or the **Zip** distribution:
    - | Platform  | Firebase 9 | Firebase 10 |
      | ------------- | ------------- | ------------- |
      | iOS  | 11.0  | 11.0  |
      | tvOS  | 11.0  | **12.0**  |
      | macOS  | 10.13  | 10.13  |
      | watchOS  | N/A  | N/A  |
- [changed] **Breaking change**: Update dependency specification for
  GTMSessionFetcher to allow all versions that are >= 2.1 and < 3.0. (#10131)

# Firebase 9.6.0
- [fixed] Mac apps using Firebase products that store SDK data in the keychain
  will no longer prompt the user for permission to access the keychain. This
  requires that Mac apps using Firebase be signed with a provisioning profile
  that has the Keychain Sharing capability enabled. (#9392)
- [fixed] Fixed `Array.Index`-related compile time errors when building with older Swift versions. (#10171)
- [fixed] Update dependency specification for GTMSessionFetcher to allow all 2.x versions. (#10131)

# Firebase 9.5.0
- [fixed] Zip Distribution Fixed Promises module name issue impacting lld builds. (#10071)
- [fixed] Limit dependency GTMSessionFetcher version update to < 2.1.0 to avoid a new deprecation
  warning. (#10123)

# Firebase 9.4.1
- [fixed] Swift Package Manager only release to fix a 9.4.0 tagging issue impacting some users. (#10083)

# Firebase 9.4.0
- [fixed] Fixed rare crash on launch due to out-of-bounds exception in FirebaseCore. (#10025)

# Firebase 9.3.0
- [changed] Discontinue bitcode inclusion in all binary distributions.
- [fixed] Remove GoogleSignInSwiftSupport from Zip and Carthage distributions due to
  infeasibility. The GoogleSignIn distribution continues. (#9937)

# Firebase 9.2.0
- [added] Zip and Carthage distributions now include GoogleSignInSwiftSupport. (#9900)

# Firebase 9.0.0
- [changed] Firebase now requires at least Xcode 13.3.1.
- [deprecated] Usage of the Firebase pod, the Firebase module (`import Firebase`), and `Firebase.h`
  is deprecated. Use the specific Firebase product instead like: `pod 'FirebaseMessaging'` and
  `import FirebaseMessaging`.

## CocoaPods Users
- [changed] **Breaking change**: Podfiles must include `use_frameworks!` or
  `use_frameworks! :linkage => :static`.
- [changed] Objective-C only apps using `use_frameworks! :linkage => :static` may need to add a
  dummy Swift file to their project to avoid linker issues.
- [changed] C++/Objective-C++ clients should use `#import <FirebaseFunctions/FirebaseFunctions-Swift.h>`
  and `#import <FirebaseStorage/FirebaseStorage-Swift.h>` to access Functions and Storage APIs,
  respectively.
- [changed] Beta Swift pods (except `FirebaseInAppMessagingSwift-Beta`) have exited beta and
  are now generally available. The `-beta` version suffix is no longer required. These should
  be removed from your Podfile, and any `import` statements should be changed accordingly.
- [changed] The `FirebaseStorageSwift` and `FirebaseFunctionsSwift` have been merged into
  `FirebaseStorage` and `FirebaseFunctions` respectively and should be removed from your Podfile.

## Swift Package Manager Users
- [changed] `import Firebase` will no longer implicitly
  import Firebase Storage and Firebase Functions APIs. Use `import FirebaseStorage` and
  `import FirebaseFunctions`, respectively. C++/Objective-C++ clients should find alternative
  workarounds at https://forums.swift.org/t/importing-swift-libraries-from-objective-c/56730.
- [changed] Beta Swift libraries (except `FirebaseInAppMessagingSwift-Beta`) have exited beta
  and are now generally available. When upgrading a project that includes one or more of these
  libraries, an error like `Missing package product 'FirebaseSwift-Beta'` will appear. In your
  project's settings, go to "General" and scroll down to `Frameworks, Libraries, and Embedded
  Content`. Select the missing package, and remove it. Then, click the `+` button to add the
  associated library without the `-Beta` suffix. Any `import` statements in your project
  should be changed accordingly.
- [changed] The `FirebaseStorageSwift-Beta` and `FirebaseFunctionsSwift-Beta` libraries have been
  merged into `FirebaseStorage` and `FirebaseFunctions` respectively and should be removed from your
  project following the instructions above.

## Zip and Carthage Users
- [changed] **Breaking change**: Update the minimum supported versions for the zip and Carthage
  distributions to iOS 11.0, tvOS 11.0 and macOS 10.13. (#9633)
- [added] The zip and Carthage distributions now include the Swift extension frameworks. (#7819)
- [changed] Zip file installation instructions have changed. Please see the README embedded in
  the zip file for updated instructions.

# Firebase 8.10.0
- [fixed] Fixed platform availability checks in Swift Package Manager that may prevent code
  completion for Analytics APIs on macOS and tvOS. (#9032)
- [added] Firebase now includes community supported Combine publishers. More details can be found
  [here](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseCombineSwift/README.md). (#7295)

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
  [here](https://github.com/firebase/firebase-ios-sdk/blob/main/SwiftPackageManager.md). (#3136)
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
  instructions](https://github.com/firebase/firebase-ios-sdk/blob/main/Carthage.md#carthage-usage).
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
- [changed] Improve error message for invalid app names. (#2614)
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
