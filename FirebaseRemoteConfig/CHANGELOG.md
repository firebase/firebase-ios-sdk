# Unreleased
- [changed] Enabled Firebase ABTesting to be a soft dependency. To use enable ABTesting,
  make sure to include `Firebase/ABTesting` in the Podfile. This will be required at the next
  major release.

# v4.9.0
- [fixed] Fixed `FirebaseApp.delete()` related crash in `RC Config Fetch`. (#6123)

# v4.8.0
- [changed] Functionally neutral source reorganization for preliminary Swift Package Manager support. (#6013)

# v4.7.0
- [changed] Functionally neutral updated import references for dependencies. (#5824)
- [changed] Updated Remote Config to consume the Protobuf-less AB Testing SDK (#5890).

# v4.6.0
- [changed] Removed typedefs from public API method signatures to improve Swift API usage from Xcode. (#5748)

# v4.5.0
- [changed] Updated `fetchAndActivateWithCompletionHandler:` implementation to activate asynchronously. (#5617)
- [fixed] Remove undefined class via removing unused proto generated source files. (#4334)
- [added] Add an URLSession Partial Mock to enable testing without a backend. (#5633)
- [added] Added activate API that returns a callback with an additional `bool` parameter indicating
  if the config has changed or not. The new API does not error if the console is unchanged. The old
  activate API with only an error parameter is deprecated and will be removed at the next major
  release. (#3586)

# v4.4.11
- [fixed] Fixed a bug where settings updates weren't applied before fetches. (#4740)
- [changed] Updated public API documentation for 4.4.10 change from FirebaseInstanceID to
  FirebaseInstallations. (#5561)

# v4.4.10
- [changed] Internal code changes - migrate to using the FIS SDK. (#5096)
- [changed] Include both CFBundleString and CFBundleShortVersionString in the outgoing fetch requests.

# v4.4.9
- [changed] Internal code changes. (#4934)

# v4.4.8
- [fixed] Fixed a bug (#4677, #4734) where Remote Config does not work after a restore of a previous backup of the device. (#4896).

# v4.4.7
- [fixed] Fixed a crash that could occur when attempting a remote config fetch before a valid Instance ID was available. (#4622)
- [fixed] Fixed an issue where config fetch would sometimes fail with a duplicate fetch error when no other fetches were in progress. (#3802)
- [changed] Fetch calls will now fail if a valid instance ID is not obtained by the Remote Config SDK.

# v4.4.6
- [fixed] Fix the return status code when app is offline. (#4100)
- [changed] Internal code cleanup. (#4297, #4403, #4379)
- [added] Added a new transitive dependency on the [Firebase Installations SDK](../FirebaseInstallations/CHANGELOG.md). The Firebase Installations SDK introduces the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com). Developers that use API-restrictions for their API-Keys may experience blocked requests (https://stackoverflow.com/questions/58495985/). A solution is available [here](../FirebaseInstallations/API_KEY_RESTRICTIONS.md).

# v4.4.5
- [changed] Remote Config no longer re-activates the current config on fetch if it receives no changes from the backend. (#4260)

# v4.4.4
- Minor internal project structure changes.

# v4.4.3
- Removed existing usage of an internal deprecated API. (#3993)

# v4.4.2
- Fixed issue for outdated values for deleted config keys (#3745).

# v4.4.1
- Fix docs issue. (#3846)

# v4.3.0
- Open source. (TBD)
- Community macOS (#1674) and tvOS support.
- Catalyst build support.

# v4.2.2
- Bug fix for a crash seen by some users (#3508)
- Internal changes and stability improvements.

# v4.2.1
- Bug fix for a crash seen by some users. (#3344)

# v4.2.0
- Improved shared instance initialization sequence during 'FirebaseApp.configure()'.

# v4.1.0
- Async initialization with new API for ensuring initialization completed with completion handler.
- Support for multiple active instances of Remote Config in the same app (Analytics only supported with default Firebase app instance).
 - All Remote Config API with explicit namespace are deprecated.
- New fetchAndActivate API to perform both fetch and activation upon a successful fetch in a single API call with async completion.
- New property in the FIRRemoteConfigValue class for reading value of a param as a jsonValue.
- developerModeEnabled is now deprecated. Use minimumFetchInterval or call fetchWithExpirationDuration: to force a fetch to the Remote Config backend.
- New config settings for minimumFetchInterval and fetch timeout.
- Async activate API with completion handler.

# v4.0.0
- FirebaseAnalytics is no longer a hard dependency in the RemoteConfig pod. If you were installing Remote Config via pod ''Firebase/RemoteConfig'', you should add 'pod 'Firebase/Analytics'' to the Podfile to maintain full RemoteConfig functionality. If you previously have 'pod 'Firebase/Core'' in the Podfile, no change is necessary. No major changes to functionality.

# v3.1.0
- Internal changes to support the new # vof Firebase Performance SDK.

# v3.0.2
- Bug fixes.

# v3.0.1
- Bug fix for a memory leak bug. (#488)


# v3.0.0
- Change the designated initializer for FIRRemoteConfigSettings to return a nonnull FIRRemoteConfigSettings object.

# v2.1.3
- Improve documentation on GDPR usage.

# v2.1.2
- Improve language targeting. Simplied Chinese (zh_hans) and Traditional Chinese (Taiwan) (zh_TW) language targeting should also be more accurate.

# v2.1.1
- Fix an issue that throttle rate drops during developer mode.
- Replaced FIR_SWIFT_NAME with NS_SWIFT_NAME.

# v2.1.0
- Add ABTesting feature to allow developers to run experiments using Remote Config.

# v2.0.3
- Resolved an issue that config values are not updating correctly when targeted by a user property condition.

# v2.0.2
- Fix an issue that prevent app from crashing when main bundle ID is missing. Also notify developers remote config might not work if main bundle ID is missing.

# v2.0.1
- Add a warning message if a plist file can't be found when setting default values from it.
- Internal clean up removing code for testing that is no longer used.

# v2.0.0
- Change Swift API names to better align with Swift convention.
- Change Error message to debug message when getting InstanceID operation is in progress as this is an expected behavior.

# v1.3.4
- Fix the issue with Remote Config getting an incorrect configuration when user configured multiple projects.
- Fix the issue with existing users getting empty config results.

# v1.3.3
- Switches to the new Protobuf from ProtocolBuffers2.

# v1.3.2
Resolved Issues:
- Fix an issue that activateFetched called when app starts will remove cached results.
- Fix an issue that multiple fetches without activateFetched will not get recent changes.

# v1.3.1
Resolved Issues:
- Better documentation on the public headers.

# v1.3.0
Features:
-  Support user property targeting for analytics abilities.

Resolved Issues:
- Fix critical crashes due to concurrent fetches, make it more thread safe.

# v1.2.0
Features:
- Add two new API methods to allow developers to get all the keys based on a key prefix.

Resolved Issues:
- Fix a crash issue during fetching config.
- Clarify the confusion on the documents of activateFetched method.
- Correct the cast error in the comment of remoteConfig method.

# v1.1.1
Initial release in Google I/O 2016.
