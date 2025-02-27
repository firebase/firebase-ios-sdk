# 11.9.0
- [fixed] Mark internal `fetchSession` property as `atomic` to prevent a concurrency
  related crash. (#14449)

# 11.8.0
- [fixed] Mark completion handlers as Sendable in RemoteConfig class.
  Some completions handlers were missed in the 11.7.0 update. (#14257)

# 11.7.0
- [fixed] Mark ConfigUpdateListenerRegistration Sendable. (#14215)
- [fixed] Mark completion handlers as Sendable in RemoteConfig class. (#14257)
- [feature] Added support for custom signal targeting in Remote Config. Use
  `setCustomSignals` API for setting custom signals and use them to build
  custom targeting conditions in Remote Config. (#13976)

# 11.5.0
- [fixed] Mark two internal properties as `atomic` to prevent concurrency
  related crash. (#13898)

# 11.0.0
- [fixed] RemoteConfigValue stringValue is now `nonnull`. This may break some builds. (#10870)
- [removed] **Breaking change**: The deprecated `FirebaseRemoteConfigSwift`
  module has been removed. See
  https://firebase.google.com/docs/ios/swift-migration for migration
  instructions.

  # 10.25.0
- [fixed] Fixed bug preventing Remote Config from working with a custom sqlite3
  dependency (#10884).

# 10.23.0
- [changed] Add support for other Firebase products to integrate with Remote Config.

# 10.17.0
- [feature] The `FirebaseRemoteConfig` module now contains Firebase Remote
  Config's Swift-only APIs that were previously only available via the
  `FirebaseRemoteConfigSwift` extension SDK. See the
  `FirebaseRemoteConfigSwift` release note from this release for more details.

# 10.12.0
- [fixed] Fix issue of real-time listeners not being properly removed. (#11458)
- [fixed] Fix real-time fetches not being able to fetch the latest template due to an in-progress fetch. (#11465)
- [changed] Internal improvements to support Remote Config real-time updates. (#11485)

# 10.7.0
- [feature] Added support for real-time config updates. Use the new `addOnConfigUpdateListener` API to get
  real-time updates. Existing [`fetch`](https://firebase.google.com/docs/reference/swift/firebaseremoteconfig/api/reference/Classes/RemoteConfig#fetch)
  and [`activate`](https://firebase.google.com/docs/reference/swift/firebaseremoteconfig/api/reference/Classes/RemoteConfig#activate)
  APIs aren't affected by this change. To learn more, see
  [Get started with Firebase Remote Config](https://firebase.google.com/docs/remote-config/get-started?platform=ios#add-real-time-listener).

# 9.3.0
- [changed] Arrays and Dictionaries are now supported when initializing defaults from a
  plist. (#8306)
- [fixed] Activate calls will only update experiment data for `firebase` namespace to ensure correct experiment exposures. (#9972)

# 9.0.0
- [changed] The `remoteConfig()` singleton now throws an exception when called before
  `FirebaseApp.configure()`. (#8640)

# 8.10.0
- [fixed] Fixed cached config not loading if device is locked. (#8807)

# 8.0.0
- [fixed] Fixed throttling issue when fetch fails due to no network. (#6628)
- [fixed] Fixed issue where sometimes the local config returned is empty. (#7424)

# 7.10.0
- [changed] Throw exception if projectID is missing from FirebaseOptions. (#7725)

# 7.9.0
- [added] Enabled community supported watchOS build in Swift Package Manager. (#7696)
- [fixed] Don't generate missing Analytics warning on Catalyst. (#7693)

# 7.8.0
- [fixed] Store fetch metadata per namespace to address activation issues. (#7179)
- [fixed] Only update experiment data for `firebase` namespace fetch requests to ensure correct experiment exposures. (#7604)

# 7.7.0
- [added] Added community support for watchOS. (#7481)

# 7.6.0
- [fixed] Fixed build warnings introduced with Xcode 12.5. (#7432)

# 7.5.0
- [fixed] Fixed bug that was incorrectly flagging ABT experiment payloads as invalid. (#7184)
- [changed] Standardize support for Firebase products that integrate with Remote Config. (#7094)

# 7.1.0
- [changed] Add support for other Firebase products to integrate with Remote Config. (#6692)

# 7.0.0
- [changed] Updated `lastFetchTime` field to readonly. (#6567)
- [changed] Functionally neutral change to stop using a deprecated method in the AB Testing API. (#6543)
- [fixed] Updated `numberValue` to be nonnull to align with current behavior. (#6623)
- [removed] Removed deprecated APIs `isDeveloperModeEnabled`, `initWithDeveloperModeEnabled:developerModeEnabled`, `activateWithCompletionHandler:completionHandler`, `activateFetched`, `configValueForKey:namespace`, `configValueForKey:namespace:source`, `allKeysFromSource:namespace`, `keysWithPrefix:namespace`, `setDefaults:namespace`, `setDefaultsFromPlistFileName:namespace`, `defaultValueForKey:namespace`. (#6637)
- [fixed] Completion handler for `fetchAndActivateWithCompletionHandler` is now run on the main thread. (#5897)
- [fixed] Fixed database creation on tvOS. (#6612)
- [changed] Updated public API documentation to no longer reference removed APIs. (#6641)
- [fixed] Updated `activateWithCompletion:` to use completion handler for experiment updates. (#3687)

# 4.9.1
- [fixed] Fix an `attempt to insert nil object` crash in `fetchWithExpirationDuration:`. (#6522)

# 4.9.0
- [fixed] Fixed `FirebaseApp.delete()` related crash in `RC Config Fetch`. (#6123)

# 4.8.0
- [changed] Functionally neutral source reorganization for preliminary Swift Package Manager support. (#6013)

# 4.7.0
- [changed] Functionally neutral updated import references for dependencies. (#5824)
- [changed] Updated Remote Config to consume the Protobuf-less AB Testing SDK (#5890).

# 4.6.0
- [changed] Removed typedefs from public API method signatures to improve Swift API usage from Xcode. (#5748)

# 4.5.0
- [changed] Updated `fetchAndActivateWithCompletionHandler:` implementation to activate asynchronously. (#5617)
- [fixed] Remove undefined class via removing unused proto generated source files. (#4334)
- [added] Add an URLSession Partial Mock to enable testing without a backend. (#5633)
- [added] Added activate API that returns a callback with an additional `bool` parameter indicating
  if the config has changed or not. The new API does not error if the console is unchanged. The old
  activate API with only an error parameter is deprecated and will be removed at the next major
  release. (#3586)

# 4.4.11
- [fixed] Fixed a bug where settings updates weren't applied before fetches. (#4740)
- [changed] Updated public API documentation for 4.4.10 change from FirebaseInstanceID to
  FirebaseInstallations. (#5561)

# 4.4.10
- [changed] Internal code changes - migrate to using the FIS SDK. (#5096)
- [changed] Include both CFBundleString and CFBundleShortVersionString in the outgoing fetch requests.

# 4.4.9
- [changed] Internal code changes. (#4934)

# 4.4.8
- [fixed] Fixed a bug (#4677, #4734) where Remote Config does not work after a restore of a previous backup of the device. (#4896).

# 4.4.7
- [fixed] Fixed a crash that could occur when attempting a remote config fetch before a valid Instance ID was available. (#4622)
- [fixed] Fixed an issue where config fetch would sometimes fail with a duplicate fetch error when no other fetches were in progress. (#3802)
- [changed] Fetch calls will now fail if a valid instance ID is not obtained by the Remote Config SDK.

# 4.4.6
- [fixed] Fix the return status code when app is offline. (#4100)
- [changed] Internal code cleanup. (#4297, #4403, #4379)
- [added] Added a new transitive dependency on the [Firebase Installations SDK](../FirebaseInstallations/CHANGELOG.md). The Firebase Installations SDK introduces the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com). Developers that use API-restrictions for their API-Keys may experience blocked requests (https://stackoverflow.com/questions/58495985/). A solution is available [here](../FirebaseInstallations/API_KEY_RESTRICTIONS.md).

# 4.4.5
- [changed] Remote Config no longer re-activates the current config on fetch if it receives no changes from the backend. (#4260)

# 4.4.4
- Minor internal project structure changes.

# 4.4.3
- Removed existing usage of an internal deprecated API. (#3993)

# 4.4.2
- Fixed issue for outdated values for deleted config keys (#3745).

# 4.4.1
- Fix docs issue. (#3846)

# 4.3.0
- Open source. (TBD)
- Community macOS (#1674) and tvOS support.
- Catalyst build support.

# 4.2.2
- Bug fix for a crash seen by some users (#3508)
- Internal changes and stability improvements.

# 4.2.1
- Bug fix for a crash seen by some users. (#3344)

# 4.2.0
- Improved shared instance initialization sequence during 'FirebaseApp.configure()'.

# 4.1.0
- Async initialization with new API for ensuring initialization completed with completion handler.
- Support for multiple active instances of Remote Config in the same app (Analytics only supported with default Firebase app instance).
 - All Remote Config API with explicit namespace are deprecated.
- New fetchAndActivate API to perform both fetch and activation upon a successful fetch in a single API call with async completion.
- New property in the FIRRemoteConfigValue class for reading value of a param as a jsonValue.
- developerModeEnabled is now deprecated. Use minimumFetchInterval or call fetchWithExpirationDuration: to force a fetch to the Remote Config backend.
- New config settings for minimumFetchInterval and fetch timeout.
- Async activate API with completion handler.

# 4.0.0
- FirebaseAnalytics is no longer a hard dependency in the RemoteConfig pod. If you were installing Remote Config via pod ''Firebase/RemoteConfig'', you should add 'pod 'Firebase/Analytics'' to the Podfile to maintain full RemoteConfig functionality. If you previously have 'pod 'Firebase/Core'' in the Podfile, no change is necessary. No major changes to functionality.

# 3.1.0
- Internal changes to support the new # of Firebase Performance SDK.

# 3.0.2
- Bug fixes.

# 3.0.1
- Bug fix for a memory leak bug. (#488)


# 3.0.0
- Change the designated initializer for FIRRemoteConfigSettings to return a nonnull FIRRemoteConfigSettings object.

# 2.1.3
- Improve documentation on GDPR usage.

# 2.1.2
- Improve language targeting. Simplied Chinese (zh_hans) and Traditional Chinese (Taiwan) (zh_TW) language targeting should also be more accurate.

# 2.1.1
- Fix an issue that throttle rate drops during developer mode.
- Replaced FIR_SWIFT_NAME with NS_SWIFT_NAME.

# 2.1.0
- Add ABTesting feature to allow developers to run experiments using Remote Config.

# 2.0.3
- Resolved an issue that config values are not updating correctly when targeted by a user property condition.

# 2.0.2
- Fix an issue that prevent app from crashing when main bundle ID is missing. Also notify developers remote config might not work if main bundle ID is missing.

# 2.0.1
- Add a warning message if a plist file can't be found when setting default values from it.
- Internal clean up removing code for testing that is no longer used.

# 2.0.0
- Change Swift API names to better align with Swift convention.
- Change Error message to debug message when getting InstanceID operation is in progress as this is an expected behavior.

# 1.3.4
- Fix the issue with Remote Config getting an incorrect configuration when user configured multiple projects.
- Fix the issue with existing users getting empty config results.

# 1.3.3
- Switches to the new Protobuf from ProtocolBuffers2.

# 1.3.2
Resolved Issues:
- Fix an issue that activateFetched called when app starts will remove cached results.
- Fix an issue that multiple fetches without activateFetched will not get recent changes.

# 1.3.1
Resolved Issues:
- Better documentation on the public headers.

# 1.3.0
Features:
-  Support user property targeting for analytics abilities.

Resolved Issues:
- Fix critical crashes due to concurrent fetches, make it more thread safe.

# 1.2.0
Features:
- Add two new API methods to allow developers to get all the keys based on a key prefix.

Resolved Issues:
- Fix a crash issue during fetching config.
- Clarify the confusion on the documents of activateFetched method.
- Correct the cast error in the comment of remoteConfig method.

# 1.1.1
Initial release in Google I/O 2016.
