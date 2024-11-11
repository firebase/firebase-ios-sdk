# 11.5.0
- [fixed] Replaced usage of the deprecated `UIApplication.keyWindow` property
  with `UIWindow.isKeyWindow`; this API is also available on visionOS. Note that
  this fix will not be in the 11.5.0 zip and Carthage distributions, but will be
  included from 11.6.0 onwards. (#14048)

# 11.4.0
- [fixed] Fix a crash related to thread sanitization on FPRNetworkTrace class (#13581).

# 10.28.0
- Fix Crash from InstrumentUploadTaskWithStreamedRequest (#12983).
- Replace SystemConfiguration with a more recent network monitoring API by Apple (#13079).

# 10.25.0
- [changed] Removed usages of user defaults API to eliminate required reason impact.

# 10.18.0
- [fixed] Fix a Xcode 15.1 build warning (#12027).

# 10.17.0
- [fixed] Fix a second Xcode 15 runtime warning (#11821).

# 10.16.0
- [fixed] Fixed a memory leak regression when generating session events (#11725).
- [fixed] Fix Xcode 15 runtime warning (#11821).

# 10.12.0
- [fixed] Make Firebase performance compatible with Xcode15.
- [changed] Removed the capability to access Carrier information of the device since that API is deprecated by Apple.

# 10.11.0
- [fixed] Fixed a bug to disable data collection if the data collection was disabled before Firebase application was configured.

# 10.9.0
- [fixed] Fixed a memory leak when generating session events (#11027).

# 10.6.0
- [added] Integrated with Firebase sessions library and replaced the session information associated with performance metrics with session details provided by the Firebase sessions library. If your app uses the Performance Monitoring SDK, review Firebase's [data disclosure page](https://firebase.google.com/docs/ios/app-store-data-collection) to make sure that your app's privacy details in the App Store are accurate and complete.
- [changed] Changed definition of sessions, as Performance Monitoring now depends on the new Firebase sessions SDK.

# 9.3.0
- [changed] Update the console logging URL to troubleshooting page.

# 8.15.0
- Remove the unused code for pre-warm detection.

# 8.14.0
- [fixed] Record the request payload size for POST/PUT requests.

# 8.13.0
- [fixed] Make pre-warming identification more reliable by moving the pre-warm check to the earliest phase of app start.

# 8.12.0
- [fixed] Attempted to fix an issue where app start trace durations are not reliable on iOS 15. App start measurements are now made only for cold app starts (without pre-warming) (#9026).

# 8.10.0
- Fix a crash related to FPRSessionDetails. (#8691)
- Fix heap-buffer overflow when encoding sessions. (#8849)

# 8.8.0
- Create a random number of delay for remote config fetch during app starts.
- Fix log spamming when Firebase Performance is disabled. (#8423, #8577)
- Fix heap-buffer overflow when decoding strings. (#8628)

# 8.6.1
- Fix the case where the event were dropped for missing a critical field in the event.

# 8.6.0
- Add Firebase Performance support for Swift Package Manager. (#6528)
- Fix a crash due to a race condition. (#8485)

# 8.2.0
- Update log messages with proper log levels.
- Fix empty values in `network_info.request_completed_time_us` field from the [data schema](https://firebase.google.com/docs/perf-mon/bigquery-export#detailed_data_schema).
- Fix a crash on FPRSessionDetails. (#8139)

# 8.1.0
- Firebase Performance logs now contain URLs to see the performance data on the Firebase console.

# 7.8.0
- Deprecate Clearcut event transport mechanism.
- Enable dynamic framework support. (#7569)
- Remove the warning to include Firebase Analytics as Perf does not depend on Analytics (#7487)
- Fix the crash on gauge manager due to race condition. (#7535)

# 7.7.0
- Add community supported tvOS.

# 7.6.0
- [fixed] Fixed build warnings introduced with Xcode 12.5. (#7435)

# 7.4.0
- Make FirebasePerformance open source.
- Remove GoogleToolboxForMac and GTMSessionFetcher dependencies.

# 7.3.0
- Add blocklist for GoogleDataTransport upload URLs.
- Update the event transport mechanism to open sourced GoogleDataTransport.

# 7.2.0
- Add Xcode simulator support for new Apple silicon based Macs.

# 7.0.1
- Remove the KVO based measurement of network performance #6734.

# 7.0.0
- Fix issue related to crashes on specific kind of network requests #6713.
- Fixed issue related to race condition on Firebase Remote Config initialization #6287.
- Update Firebase dependencies to be latest and greatest.

# 3.3.1
- Make the SDK iOS 14 compatible.

# 3.3.0
- Rolled forward previous changes from in-house event log dispatch mechanism to [GoogleDataTransport](https://cocoapods.org/pods/GoogleDataTransport) after fixing client timestamp issue.
- Updated the Logging message for 'Trace' and 'Network Requests' (see [Public Docs](https://firebase.google.com/docs/perf-mon/get-started-ios#step_3_optional_view_log_messages_for_performance_events)).
- Resolved a long standing issue which stopped network request trace from being dispatched on Simulator.

# 3.2.0
- Migrating from Clearcut SDK (internal log dispatch mechanism) to
  [GoogleDataTransport](https://cocoapods.org/pods/GoogleDataTransport) SDK, but
  send events to the same Clearcut Backend.

# 3.1.11
- Integrate with the newer version of Firebase Installations and remove the
  dependency with Firebase InstanceID SDK.

# 3.1.10
- Fix a crash related to fetching cached config values from RC. (#4400, #4399)

# 3.1.9
- Integrate with the newer version of FirebaseInstanceId SDK that uses Firebase
  Installation Service.

# 3.1.8
- Dropped insanely long app start traces
- Fixed monitoring NSURLSession based network requests that were not captured
  starting iOS 13.

# 3.1.7
- Introduce a caching layer for remote config to avoid deadlock when fetching
  configs realtime.

# 3.1.6
- Cleanup the dependencies with Phenotype.

# 3.1.5
- Fixed a crash during app start on iOS 13 devices.
- SDK Enhancements - Move configs to remote config.

# 3.1.4
- Capture app start durations for 12.x versions.

# 3.1.3
- Updates the dependency on Firebase Remote Config.

# 3.1.2
- Fixes issue where NSURLConnection based network requests made from KVO-d
  NSOperation do not complete.
- Fixes issues related to main thread checker.

# 3.1.1
- Fixes an iOS 13 beta crash caused by a race condition with Remote Config.

# 3.1.0
- Adapt FirePerf to work with recent version of Remote Config.
- Fix the bug to honor the dataCollectionEnabled flag.

# 3.0.0
- Remove the deprecated counter APIs.

# 2.2.4
- Crash fixes and code cleanups.

# 2.2.3
- Resolve potential symbol conflicts.

# 2.2.2
- Crash fixes and code cleanups.

# 2.2.1
- Bug fixes and enhancements.

# 2.2.0
- Introduce the feature "Sessions".
- Bug fixes.

# 2.1.2
- Use the newer version of swizzler.

# 2.1.1
- Fix the SDK to reduce the bandwidth consumption for the user.

# 2.1.0
- Fixed few crashes in the SDK.
- Depend on open source version of GoogleUtilities/Swizzler library.
- Added conformance to Firebase global data collection switch.

# 2.0.1
- Fix the crash related to screen traces.
- Improve SDK startup time.
- Fix the crash related to AVAssetDownloadTask.

# 2.0.0
- Exit from beta into GA.
- Automatic screen traces to report on screen rendering performance.
- Added API for setting, incrementing and getting metrics.
- Deprecated the API to increment and decrement counters - please use the new
  metrics API instead.

# 1.1.3
- Fixed a multithreading crash.

# 1.1.2
- Fix the crash related to redirection requests with AFNetworking.
- Other bug fixes.

# 1.1.1
- Bug fixes.

# 1.1.0
- Added API for tagging traces with custom attributes.
- Added API for manually recording network traces.

- Bug fixes.

# 1.0.7
- Network requests made using NSURLConnection are now instrumented.
- Bug fixes.

# 1.0.6
- Infrastructure changes to help diagnose SDK issues more easily.

# 1.0.5
- Symbol collisions with GoogleMobileVision have been addressed.
- The SDK should now not crash if Crittercism is also being used.
- Safety limits enforced on the number of events dispatched over a period of time.

# 1.0.4
- Bug fixes.
- Trace and counter name limits have been set to 100 characters.

# 1.0.3
- Xcode 9 thread sanitizer fixes.

# 1.0.2
- Bug fixes.

# 1.0.1
- Removed dependency on farmhash to prevent symbol collisions.
- The name of the Trace will now be printed if an exception is thrown when
  creating one.

# 1.0.0
- Initial release in Google I/O 2017.
