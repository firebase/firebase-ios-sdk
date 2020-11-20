# Unreleased -- 7.0.0
- [changed] Deprecated private `-[FIRInstanceID appInstanceID:]` method was removed. (#4486)
- [fixed] Fixed an issue that APNS token is not sent in token request when there's a delay of getting the APNS token from Apple. (#6553)

# 2020-09 -- 4.7.0
- [deprecated] Deprecated InstanceID. For app instance identity handling, use FirebaseInstallations. For FCM registration token handling, use FirebaseMessaging. (#6585)

# 2020-08 -- 4.6.0
- [added] Added a new notification listening token refresh from Messaging and update the token cache in InstanceID. (#6286)
- [fixed] Fixed an issue that token refresh notification is not triggered when use `tokenWithAuthorizedEntity:scope:options:handler` to get token. (#6286)

# 2020-07 -- 4.5.1
- [changed] Remove FIRInstanceIDURLQueryItem in favor of NSURLQueryItem. (#5835)

# 2020-07 -- 4.5.0
- [changed] Functionally neutral updated import references for dependencies. (#5824)

# 2020-06 -- 4.4.0
- [changed] Standardize FirebaseCore import headers. (#5758)

# 2020-04 -- 4.3.4
- [changed] Internal cleanup and remove repetitive local notification. (#5339)

# 2020-03 -- 4.3.3
- [fixed] Fixed provisioning profile location for catalyst. (#5048)
- [fixed] Fixed crash when passing a nil handler to deleteToken request. (#5247)
- [changed] Remove obsolete logic to improve performance and reduce keychain operations. (#5211, #5237)

# 2020-02 -- 4.3.2
- [changed] Removed unused files (#4881).

# 2020-02 -- 4.3.1
- [changed] Stop collecting logging ID as it is not used anymore.(#4444)

# 2020-01 -- 4.3.0
- [added] Added watchOS support for InstanceID (#4016)
- [added] Added a new dependency on the [Firebase Installations SDK](../../FirebaseInstallations/CHANGELOG.md). The Firebase Installations SDK introduces the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com). Developers that use API-restrictions for their API-Keys may experience blocked requests (https://stackoverflow.com/questions/58495985/). A solution is available [here](../../FirebaseInstallations/API_KEY_RESTRICTIONS.md). (#4533)

# 2019-12 -- 4.2.8
- [changed] Added heartbeat support for InstanceID (#4323)
- [fixed] Fixed the documentations on a few random generation and hash methods to clarify its use case to avoid confusions. (#4469, #4444, #4326)

# 2019-11-05 -- 4.2.7
- [fixed] Fixed a crash in `checkTokenRefreshPolicyWithIID:` and ensure `tokenWithAuthorizedEntity:scope:options:handler` method is refreshing token if token is not freshed any more. (#4167)
- [changed] Updated deprecated keychain access level. (#4172)

# 2019-10-22 -- 4.2.6
- [fixed] Fixed InstanceID initialization timing issue (#4030).
- [changed] Added check to see if token and IID are inconsistent (#4025).
- [changed] Removed migration logic from document folder to application folder (#4033).

# 2019-10-08 -- 4.2.5
- [fixed] Fixed private header imports (#3796).

# 2019-09-23 -- 4.2.4
- [changed] Moved two headers from internal to private for Remote Config open sourcing (#3621).

# 2019-08-20 -- 4.2.3
- [fixed] Fixed a crash that could occur if InstanceID was shut down when fetching a new instance ID (#3439).

# 2019-07-12 -- 4.2.2
- [changed] Removed a call to a deprecated logging method (#3333).

# 2019-07-09 -- 4.2.1
- [fixed] Fixed an issue where fetching an instance ID wouldn't invoke the callback handler if the instance ID had not changed. (#3229)

# 2019-06-18 -- 4.2.0
- [added] Added macOS support for InstanceID (#2880)
- [fixed] Corrected timezone proto key (#3132)

# 2019-06-04 -- 4.1.1
- [fixed] Fixed a crash in token fetching. Removed debug assertion that is only for develop build. (#3018)

# 2019-05-21 -- 4.1.0
- [fixed] Fixed a race condition where checkin was deleted before writing during app start, causing notifications to not be delivered correctly. (#2438)
- [fixed] Fixed a keychain migration crash. (#2731)
- [changed] Remove reflection call to get checkin info from Firebase Messaging. (#2825)

# 2019-05-07 -- 4.0.0
- [removed] Remove deprecated `token` method. Use `instanceIDWithHandler:` instead. (#2741)
- [changed] Send `firebaseUserAgent` with a register request (#2679)

# 2019-04-02 -- v3.8.1
- [fixed] Fixed handling the multiple calls of instanceIDWithHandler. (#2445)
- [fixed] Fixed a race condition where token kept getting refreshed at app start. (#2438)

# 2019-03-19 -- v3.8.0
- [added] Adding community support for tvOS. (#2428)
- [added] Adding Firebase info to checkin. (#2509)
- [fixed] Fixed a crash in FIRInstanceIDCheckinService. (#2548)

# 2019-03-05 -- v3.7.0
- [feature] Open source Firebase InstanceID. (#186)

# 2019-02-20 -- v3.5.0
- [changed] Always update keychain access control when adding new keychain to ensure it won't be blocked when device is locked. (#1399)

# 2019-01-22 -- v3.4.0
- [changed] Move all keychain write operations off the main thread. (#1399)
- [changed] Make keychain operations asynchronous where possible (given the current APIs)
- [changed] Avoid redundant keychain operations when it's been queried and cached before.

# 2018-10-25 -- v3.3.0
- [fixed] Fixed a crash caused by keychain operation when accessing default access group. (#1399, #1393)
- [changed] Remove internal APIs that are no longer used.

# 2018-09-25 -- v3.2.2
- [fixed] Fixed a crash caused by NSUserDefaults being called on background thread.

# 2018-08-14 -- v3.2.1
- [fixed] Fixed an issue that checkin is not cached properly when app first started. (#1561)

# 2018-07-31 -- v3.2.0
- [added] Added support for global Firebase data collection flag. (#1219)
- [changed] Improved message tracking sent by server API.
- [fixed] Fixed an issue that InstanceID doesn't compile in app extensions, allowing its
dependents like remote config to be working inside the app extensions.

# 2018-06-19 -- v3.1.1
- [fixed] Ensure the checkin and tokens are refreshed if firebase project changed.
- [fixed] Fixed an issue that checkin should be turned off when FCM's autoInitEnabled flag is off.

# 2018-06-12 -- v3.1.0
- [added] Added a new API to fetch InstanceID and Token with a completion handler. The completion handler returns a FIRInstanceIDResult with a instanceID and a token properties.
- [deprecated] Deprecated the token method.
- [added] Added support to log a new customized label provided by developer.

# 2018-05-08 -- v3.0.0
- [removed] Removed deprecated method `setAPNSToken:type` defined in FIRInstanceID, please use `setAPNSToken:type` defined in FIRMessaging instead.
- [removed] Removed deprecated enum `FIRInstanceIDAPNSTokenType` defined in FIRInstanceID, please use `FIRMessagingAPNSTokenType` defined in FIRMessaging instead.
- [fixed] Fixed an issue that FCM scheduled messages were not tracked successfully.

# 2018-03-06 -- v2.0.10
- [changed] Improved documentation on InstanceID usage for GDPR.
- [fixed] Improved the keypair handling during GCM to FCM migration. If you are migrating from GCM to FCM, we encourage you to update to this version and above.

# 2018-02-06 -- v2.0.9
- [fixed] Improved support for language targeting for FCM service. Server updates happen more efficiently when language changes.
- [fixed] Improved support for FCM token auto generation enable/disable functions.

# 2017-12-11 -- v2.0.8
- [fixed] Fixed a crash caused by a reflection call during logging.
- [changed] Updating server with the latest parameters and deprecating old ones.

# 2017-11-27 -- v2.0.7
- [fixed] Improve identity reset process, ensuring all information is reset during Identity deletion.

# 2017-11-06 -- v2.0.6
- [changed] Make token refresh weekly.
- [fixed] Fixed a crash when performing token operation.

# 2017-10-11 -- v2.0.5
- [added] Improved support for working in shared Keychain environments.

# 2017-09-26 -- v2.0.4
- [fixed] Fixed an issue where the FCM token was not associating correctly with an APNs
  device token, depending on when the APNs device token was made available.
- [fixed] Fixed an issue where FCM tokens for different Sender IDs were not associating
  correctly with an APNs device token.
- [fixed] Fixed an issue that was preventing the FCM direct channel from being
  established on the first start after 24 hours of being opened.

# 2017-09-13 -- v2.0.3
- [fixed] Fixed a race condition where a token was not being generated on first start,
  if Firebase Messaging was included and the app did not register for remote
  notifications.

# 2017-08-25 -- v2.0.2
- [fixed] Fixed a startup performance regression, removing a call which was blocking the
  main thread.

# 2017-08-07 -- v2.0.1
- [fixed] Fixed issues with token and app identifier being inaccessible when the device
  is locked.
- [fixed] Fixed a crash if bundle identifier is nil, which is possible in some testing
  environments.
- [fixed] Fixed a small memory leak fetching a new token.
- [changed] Moved to a new and simplified token storage system.
- [changed] Moved to a new queuing system for token fetches and deletes.
- [changed] Simplified logic and code around configuration and logging.
- [changed] Added clarification about the 'apns_sandbox' parameter, in header comments.

# 2017-05-08 -- v2.0.0
- [added] Introduced an improved interface for Swift 3 developers
- [deprecated] Deprecated some methods and properties after moving their logic to the
  Firebase Cloud Messaging SDK
- [fixed] Fixed an intermittent stability issue when a debug build of an app was
  replaced with a release build of the same version
- [fixed] Removed swizzling logic that was sometimes resulting in developers receiving
  a validation notice about enabling push notification capabilities, even though
  they weren't using push notifications
- [fixed] Fixed a notification that would sometimes fire twice in quick succession
  during the first run of an app

# 2017-03-31 -- v1.0.10

- [changed] Improvements to token-fetching logic
- [fixed] Fixed some warnings in Instance ID
- [fixed] Improved error messages if Instance ID couldn't be initialized properly
- [fixed] Improvements to console logging

# 2017-01-31 -- v1.0.9

- [fixed] Removed an error being mistakenly logged to the console.

# 2016-07-06 -- v1.0.8

- [changed] Don't store InstanceID plists in Documents folder.

# 2016-06-19 -- v1.0.7

- [fixed] Fix remote-notifications warning on app submission.

# 2016-05-16 -- v1.0.6

- [fixed] Fix CocoaPod linter issues for InstanceID pod.

# 2016-05-13 -- v1.0.5

- [fixed] Fix Authorization errors for InstanceID tokens.

# 2016-05-11 -- v1.0.4

- [changed] Reduce wait for InstanceID token during parallel requests.

# 2016-04-18 -- v1.0.3

- [changed] Change flag to disable swizzling to *FirebaseAppDelegateProxyEnabled*.
- [fixed] Fix incessant Keychain errors while accessing InstanceID.
- [fixed] Fix max retries for fetching IID token.

# 2016-04-18 -- v1.0.2

- [changed] Register for remote notifications on iOS8+ in the SDK itself.
