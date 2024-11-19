# 11.5.0
- [changed] Updated `upload-symbols` to version 3.19, removed all methods require CFRelease and switch to modern classes (#13420).

# 11.4.0
- [fixed] Updated `upload-symbols` to version 3.18 with support for uploading multiple DWARF contents in a dSYM bundle (#13543).
- [fixed] Fixed upload-symbols run script argument order (#13965).

# 10.28.1
- [changed] Reverted "Add SIGTERM support (#12881)" (#13117)

# 10.28.0
- [fixed] Created a new queue for rollouts persistence writes and made sure rollouts logging queue is not nil while dispatching (#12913).

# 10.27.0
- [added] Added support for catching the SIGTERM signal (#12881).
- [fixed] Fixed a hang when persisting Remote Config Rollouts to disk (#12913).

# 10.25.0
- [changed] Removed usages of user defaults API from internal Firebase Sessions
  dependency to eliminate required reason impact.

# 10.24.0
- [fixed] Fix `'FirebaseCrashlytics/FirebaseCrashlytics-Swift.h' file not found`
  errors (#12611).
- [changed] Remove usages of `mach_absolute_time` to reduce required reason impact.

# 10.23.0
- [added] Updated upload-symbols to 13.7 with VisionPro build phase support. (#12306)
- [changed] Added support for Crashlytics to report metadata about Remote Config keys and values.

# 10.22.0
- [fixed] Force validation or rotation of FIDs for FirebaseSessions.
- [changed] Removed calls to statfs in the Crashlytics SDK to comply with Apple Privacy Manifests. This change removes support for collecting Disk Space Free in Crashlytics reports.
- [fixed] Fixed FirebaseSessions crash on startup that occurs in release mode in Xcode 15.3 and other build configurations. (#11403)

# 10.16.0
- [fixed] Fixed a memory leak regression when generating session events (#11725).

# 10.12.0
- [changed] Updated `upload-symbols` to version 3.16 with support for new default build settings in Xcode 15 (#11463)
- [changed] Re-enabled dSYM uploads for Flutter apps building with `--obfuscate` and updated instructions for de-obfuscating Dart stacktraces
- [fixed] `upload-symbols` / `run` now support apps with `User Script Sandboxing` set to `YES` when all input files are present in the build phase. Please see the Pull Request for the full list of input files (#11463)
- [fixed] `upload-symbols` / `run` no longer read from the app's Info.plist and supports apps with `Generate Info.plist File` set to `NO` (#11463)
- [added] Added a `CrashlyticsInputFiles.xcfilelist`. Instead of using "Input Files", developers can specify the path to this file in the Build Phase's "Input File Lists" section of your Crashlytics `run` / `upload-symbols` script to keep it up to date (#11428)

# 10.11.0
- [fixed] Fixed a threading-related hang during initialization in urgent mode (#11216)

# 10.10.0
- [changed] Removed references to deprecated CTCarrier API in FirebaseSessions. (#11144)
- [fixed] Fix Xcode 14.3 Analyzer issue. (#11228)

# 10.9.0
- [fixed] Updated upload-symbols to 3.15. Disabled dSYM uploads for Flutter
  apps building with --obfuscate and added instructions for uploading through
  the Crashlytics dashboard. (#11136)
- [fixed] Fixed a memory leak when generating session events (#11027).

# 10.7.0
- [fixed] Updated upload-symbols to 3.14 with an improvement to upload all dSYM files for Flutter apps

# 10.6.0
- [added] Integrated with Firebase sessions library to enable upcoming features related to session-based crash metrics. If your app uses the Crashlytics SDK, review Firebase's [data disclosure page](https://firebase.google.com/docs/ios/app-store-data-collection) to make sure that your app's privacy details in the App Store are accurate and complete.

# 10.4.0
- [added] Updated Crashlytics to include the Firebase Installation ID for consistency with other products (#10645).

# 8.13.0
- [added] Updated upload-symbols to 3.11 and added logic to process Flutter project information (#9379)
- [fixed] Added native support for ARM / M1 Macs in upload-symbols (#8965)
- [fixed] Fixed an issue where passing nil as a value for a custom key or user ID did not clear the stored value as expected.

# 8.9.0
- [fixed] Fixed an issue where exceptions with `nil` reasons weren't properly recorded (#8671).

# 8.8.0
- [added] Internal SDK updates to test potential future MetricKit support.

# 8.4.0
- [fixed] Bump Promises dependency. (#8365)

# 8.3.0
- [fixed] Add missing dependency that could cause missing symbol build failures. (#8137)

# 8.2.0
- [changed] Incorporated code quality changes around integer overflow, potential race conditions, and reinstalling signal handlers.
- [fixed] Fixed an issue where iOS-only apps running on iPads would report iOS as their OS Name.
- [fixed] Fixed deprecation warning for projects with minimum deployment version iOS 13 and up.

# 8.0.0
- [changed] Added a warning to upload-symbols when it detects a dSYM with hidden symbols.

# 7.10.0
- [changed] Added a warning to upload-symbols when it detects a dSYM without any symbols.

# 7.9.0
- [changed] Updated Firebase pod to allow iOS 9 installation via `pod 'Firebase/Crashlytics'`

# 7.8.0
- [added] Added a new API checkAndUpdateUnsentReportsWithCompletion for updating the crash report from the previous run of the app if, for example, the developer wants to implement a feedback dialog to ask end-users for more information. Unsent Crashlytics Reports have familiar methods like setting custom keys and logs (#7503).
- [changed] Added a limit to the number of unsent reports on disk to prevent disk filling up when automatic data collection is off. Developers can ensure this limit is never reached by calling send/deleteUnsentReports every run (#7619).

# 7.7.0
- [added] Added a new API to allow for bulk logging of custom keys and values (#7302).

# 7.6.0
- [fixed] Fixed an issue where some developers experienced a race condition involving binary image operations (#7459).

# 7.5.0
- [changed] Improve start-up performance by moving some initialization work to a background thread (#7332).
- [changed] Updated upload-symbols to a version that is notarized to avoid macOS security alerts (#7323).
- [changed] Deleting unsent reports with deleteUnsentReports no longer happens on the main thread (#7298).

# 7.4.0
- [changed] Removed obsolete crash reporting mechanism from the SDK (#7076).

# 7.3.0
- [added] Added Crashlytics support for x86 apps running on Apple Silicon via Rosetta 2
- [changed] Decreased Crashlytics CocoaPods minimum deployment target from iOS 10 to iOS 9
- [changed] Removed obsolete API calls from upload-symbols
- [changed] Removed obsolete onboarding calls from the SDK.

# 7.1.0
- [fixed] Fixed an issue where symbol uploads would fail when there are spaces in the project path, particularly in Unity builds (#6789).
- [changed] Added additional logging when settings requests fail with a 404 status to help customers debug onboarding issues (#6847).

# 4.6.2

- [changed] Improved upload-symbols conversion speed. Customers with large dSYMs should see a significant improvement in the time it takes to upload Crashlytics symbols.
- [fixed] Fixed Apple Watch crash related to `sigaction` (#6434).

# 4.6.0

- [added] Added stackFrameWithAddress API for recording custom errors that are symbolicated on the backend (#5975).
- [fixed] Fixed comment typos (#6363).
- [fixed] Remove device information from binary image data crash info entries (#6382).

# 4.5.0

- [fixed] Fixed a compiler warning and removed unused networking code (#6210).
- [fixed] Fixed a crash that occurred rarely when trying to restart a URL session task without a valid request (#5984).
- [added] Introduced watchOS support (#6262).

# 4.3.1

- [fixed] Fixed a segmentation fault that could occur when writing crash contexts to disk (#6048).

# 4.3.0

- [changed] Add dispatch_once for opening sdk log file. (#5904)
- [changed] Functionally neutral updated import references for dependencies. (#5902)

# 4.2.0

- [changed] Removed an unnecessary linker rule for embedding the Info.plist. (#5804)

# 4.1.1

- [fixed] Fixed a crash that could occur if certain plist fields necessary to create Crashlytics records were missing at runtime. Also added some diagnostic logging to make the issue cause more explicit (#5565).

# 4.1.0

- [fixed] Fixed unchecked `malloc`s in Crashlytics (#5428).
- [fixed] Fixed an instance of undefined behavior when loading files from disk (#5454).

# 4.0.0

 - [changed] The Firebase Crashlytics SDK is now generally available.

# 4.0.0-beta.7

 - [changed] Increased network timeout for symbol uploads to improve reliability on limited internet connections. (#5228)

# 4.0.0-beta.6

 - [added] Added a new API to record custom exception models and stacktraces to Crashlytics. This is a replacement for the `recordCustomException` API that existed in the Fabric Crashlytics SDK (#5055)
 - [fixed] Fixed an issue with the `sendUnsentReports` API where reports wouldn't be uploaded until the method was called twice in specific instances (#5060)
 - [changed] Changed Crashlytics to use GoogleDataTransport to upload crashes (#4989)
 - [changed] Changed the origin that Crashlytics uses to register Crash events for Crash Free Users. Ensure you have installed Firebase Analytics version 6.3.1 or above (#5030)

# 4.0.0-beta.5

- [changed] Changed two endpoints in the Firebase Crashlytics SDK with no expected end-user impact (#4953, #4988).

# 4.0.0-beta.4

- [fixed] Fixed symbol collisions with the legacy Fabric Crashlytics SDK and added a warning not to include both (#4753, #4755)
- [fixed] Added crash prevention checks (#4661)

# 4.0.0-beta.3

- [fixed] Fixed an import declaration for installing Crashlytics. Previously, the declaration caused a compile error when you installed using CocoaPods with the `generate_multiple_pods_project` flag set to true (#4786)

# 4.0.0-beta.2

- [fixed] Fixed VeraCode scanner issues for unchecked error conditions (#4669)

# 4.0.0-beta.1

This Firebase Crashlytics version includes the initial beta release of the Firebase Crashlytics SDK:

 - [feature] The SDK is now open-sourced. Take a look in our [GitHub repository](https://github.com/firebase/firebase-ios-sdk/tree/main/Crashlytics).
 - [feature] Added support for Catalyst (note that Crashlytics still supports tvOS and macOS).
 - [feature] Added new APIs that are more consistent with other Firebase SDKs and more intuitive to use. The new APIs also give your users more control over how you collect their data.
 - [removed] Removed the Fabric API Key. Now, Crashlytics uses the GoogleService-Info.plist file to associate your app with your project. If you linked your app from Fabric and want to upgrade to the new SDK, remove the Fabric API key from your `run` and `upload-symbols` scripts. We also recommend removing the Fabric section from your app's Info.plist (when you upgrade, Crashlytics uses the new configuration you set up in Firebase).
