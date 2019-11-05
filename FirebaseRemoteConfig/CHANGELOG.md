# v4.4.4
- Minor internal project structure changes.

# v4.4.3
- Removed existing usage of an internal deprecated API. (#3993)

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
