# 11.5.0
- [fixed] Improve token-fetch failure logging with detailed error info. (#13997).

# 11.0.0
- [fixed] Completed Messaging's transition to NSSecureCoding (#12343).

# 10.29.0
- [fixed] Renamed "initWithFileName" internal method that was causing submission issues for some
  users. (#13134).
- [fixed] Fixed the APS Environment key on visionOS. (#13173)

# 10.27.0
- [fixed] Fixed bug preventing Messaging from working with a custom sqlite3
  dependency (#12900).

# 10.23.0
- [fixed] [CocoaPods] Fix "no rule" warning when running `pod install`. (#12511)

# 10.20.0
- [fixed] Fix 10.19.0 regression where the FCM registration token was nil at first app start
  after update from 10.19.0 or earlier. (#12245)

# 10.19.0
- [changed] Adopt NSSecureCoding for internal classes. (#12075)

# 10.12.0
- [changed] Removing fiam scoped tokens set by old FIAM SDK(s) from keychain if exists (b/284207019).

# 10.6.0
- [fixed] Configure flow validates existence of an APNS token before fetching an FCM token (#10742). This also addresses the scenario 1 mentioned in the comment - https://github.com/firebase/firebase-ios-sdk/issues/10679#issuecomment-1402776795

# 10.5.0
- [fixed] Fixed a crash for strongSelf dereference (#10707).

# 10.4.0
- [changed] On app startup, an APNS Token must be provided to FCM SDK before retrieving an FCM Token otherwise an error will be returned as part of the completion.

# 10.3.0
- [changed] Allow notification support on iOS 16 Simulator on Xcode 14 (#9968) (Reference: Xcode 14 Release Notes -> Simulator -> New Features: https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes)

# 10.1.0
- [fixed] App bundle identifier gets incorrectly shortened for watchOS apps created on Xcode 14 (#10147)

# 8.12.0
- [changed] Improved reporting for SQLite errors when failing to open a local database (#8699).

# 8.11.0
- [fixed] Fixed an issue that token is not associated with APNS token during app start. (#8738)

# 8.6.0
- [changed] Removed iOS version check from `FIRMessagingExtensionHelper.h` (#8492).
- [added] Added new API `FIRMessagingExtensionHelper exportDeliveryMetricsToBigQuery` that allows developers to enable notification delivery metrics that exports to BigQuery. (#6181)
- [fixed] Fixed an issue that delete token no longer works. (#8491)

# 8.2.0
- [fixed] Fixed an issue that local scheduled notification is not set correctly due to sound type. (#8172)

# 8.1.0
- [fixed] Fixed an issue that notification open is not logged to Analytics correctly when app is completely shut off. (#7707, #8128).

# 8.0.0
- [changed] Remove the Instance ID dependency from Firebase Cloud Messaging. This is a breaking change for FCM users who use the deprecated Instance ID API to manage registration tokens. Users should migrate to FCM's token APIs by following the migration guide: https://firebase.google.com/docs/projects/manage-installations#fid-iid. (#7836)

# 7.11.0
- [changed] Refactor Messaging to internally not depending on InstanceID, but can co-exist. Will remove InstanceID dependency in the next Firebase breaking change. (#7814)

# 7.7.0
- [fixed] Fixed an issue in which, when checking storage size before writing to disk, the client was checking document folders that were no longer used. (#7480)

# 7.6.0
- [fixed] Fixed build warnings introduced with Xcode 12.5. (#7433)

# 7.1.0
- [fixed] Fixed completion handler issue in `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` method. (#6863)

# 7.0.0
- [changed] Remove the deprecated FCM direct channel API and Upstream send API. (#6430)
- [changed] The `messaging:didReceiveRegistrationToken:` should be able to return a null token. Update the API parameter fcmToken to be nullable. (#5339)
- [fixed] Fixed an issue that downloading an image failed when there's no extension in the file name but MIME type is set. (#6590)

# 4.7.1
- [added] InstanceID is deprecated, add macro to suppress deprecation warning. (#6585)

# 4.7.0
- [added] Added new token APIs to get and delete the default FCM registration token asynchronously. Also added a new `Messaging.delete(completion:)` method that deletes all FCM registration tokens and checkin data. (#6313)

# 4.6.2
- [fixed] Fixed an issue that topic doesn't work in watchOS. (#6160)
- [fixed] Improved Xcode completion of public API completion handlers in Swift. (#6278)

# 4.6.1
- [changed] Remove logic that is executed for iOS 7 and below. (#5835)

# 4.6.0
- [fixed] Fix documentation warning exposed by Xcode 12. (#5876)
- [changed] Functionally neutral updated import references for dependencies. (#5824)

# 4.5.0
- [changed] Use UNNotificationRequest to schedule local notification for local timezone notification for iOS 10 and above. This should also fix the issue that '%' was not properly shown in title and body. (#5667)
- [fixed] Fixed Maltese language key for language targeting. (#5702)

# 4.4.1
- [changed] Updated NSError with a failure reason to give more details on the error. (#5511)

# 4.4.0
- [changed] Changed the location of source under FirebaseMessaging folder to fit the current repository organization. (#5476)

# 4.3.1
- [fixed] Fixed an issue that when a token is deleted, the token refresh notification and delegate is not triggered. (#5338)

# 4.3.0
- [changed] Deprecated FCM direct channel messaging via `shouldEstablishDirectChannel`. Instead, use APNs for downstream message delivery. Add `content_available` key to your payload if you want to continue use legacy APIs, but we strongly recommend HTTP v1 API as it provides full APNs support. The deprecated API will be removed in Firebase 7. (#4710)
- [changed] Deprecated upstream messaging API. For realtime updates, use Cloud Firestore, Realtime Database, or other services. The deprecated API will be removed in Firebase 7. (#4710)
- [fixed] Use secure coding for Messaging's pending topics. (#3686)

# 4.2.1
- [added] Firebase Pod support for watchOS: `pod 'Firebase/Messaging'` in addition to `pod 'FirebaseMessaging'`. (#4807)
- [fixed] Fix FIRMessagingExtensionHelper crash in unit tests when `attachment == nil`. (#4689)
- [fixed] Fix FIRMessagingRmqManager crash when database is removed. This only happens when device has a corrupted database file. (#4771)

# 4.2.0
- [added] Added watchOS support for Firebase Messaging. This enables FCM push notification function on watch only app or independent watch app. (#4016)
- [added] Added a new transitive dependency on the [Firebase Installations SDK](../../FirebaseInstallations/CHANGELOG.md). The Firebase Installations SDK introduces the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com). Developers that use API-restrictions for their API-Keys may experience blocked requests (https://stackoverflow.com/questions/58495985/). A solution is available [here](../../FirebaseInstallations/API_KEY_RESTRICTIONS.md).

# 4.1.10
- [fixed] Fix component startup time. (#4137)

# 4.1.9
- [changed] Moved message queue delete operation to a serial queue to avoid race conditions in unit tests. (#4236)

# 4.1.8
- [changed] Moved reliable message queue database operation off main thread. (#4053)

# 4.1.7
- [fixed] Fixed IID and Messaging container instantiation timing issue. (#4030)
- [changed] Internal cleanup and remove migration logic from document folder to application folder. (#4033, #4045)

# 4.1.6
- [changed] Internal cleanup. (#3857)

# 4.1.5
- [fixed] Mute FCM deprecated warnings with Xcode 11 and min iOS >= 10. (#3857)

# 4.1.4
- [fixed] Fixed notification open event is not logged when scheduling a local timezone message. (#3670, #3638)
- [fixed] Fixed FirebaseApp.delete() results in unusable Messaging singleton. (#3411)

# 4.1.3
- [changed] Cleaned up the documents, unused macros, and folders. (#3490, #3537, #3556, #3498)
- [changed] Updated the header path to pod repo relative. (#3527)
- [fixed] Fixed singleton functionality after a FirebaseApp is deleted and recreated. (#3411)

# 4.1.2
- [fixed] Fixed hang when token is not available before topic subscription and unsubscription. (#3438)

# 4.1.1
- [fixed] Fixed Xcode 11 tvOS build issue - (#3216)

# 4.1.0
- [feature] Adding macOS support for Messaging. You can now send push notification to your mac app with Firebase Messaging.(#2880)

# 4.0.2
- [fixed] Disable data protection when opening the Rmq2PersistentStore. (#2963)

# 4.0.1
- [fixed] Fixed race condition checkin is deleted before writing during app start. This cleans up the corrupted checkin and fixes #2438. (#2860)
- [fixed] Separate APNS proxy methods in GULAppDelegateSwizzler so developers don't need to swizzle APNS related method unless explicitly requested, this fixes #2807. (#2835)
- [changed] Clean up code. Remove extra layer of class. (#2853)

# 4.0.0
- [removed] Remove deprecated `useMessagingDelegateForDirectChannel` property.(#2711) All direct channels (non-APNS) messages will be handled by `messaging:didReceiveMessage:`. Previously in iOS 9 and below, the direct channel messages are handled in `application:didReceiveRemoteNotification:fetchCompletionHandler:` and this behavior can be changed by setting `useMessagingDelegateForDirectChannel` to true. Now that all messages by default are handled in `messaging:didReceiveMessage:`. This boolean value is no longer needed. If you already have set useMessagingDelegateForDirectChannel to YES, or handle all your direct channel messages in `messaging:didReceiveMessage:`. This change should not affect you.
- [removed] Remove deprecated API to connect direct channel. (#2717) Should use `shouldEstablishDirectChannel` property instead.
- [changed] `GULAppDelegateSwizzler` is used for the app delegate swizzling. (#2683)

# 3.5.0
- [added] Add image support for notification. (#2644)

# 3.4.0
- [added] Adding community support for tvOS. (#2428)

# 3.3.2
- [fixed] Replaced `NSUserDefaults` with `GULUserDefaults` to avoid potential crashes. (#2443)

# 3.3.1
- [changed] Internal code cleanup.

# 3.3.0
- [changed] Use the new registerInternalLibrary API to register with FirebaseCore. (#2137)

# 3.2.1
- [fixed] Fixed an issue where messages failed to be delivered to the recipient's time zone. (#1946)

# 3.2.0
- [added] Now you can access the message ID of FIRMessagingRemoteMessage object. (#1861)
- [added] Add a new boolean value useFIRMessagingDelegateForDirectMessageDelivery if you
  want all your direct channel data messages to be delivered in
  FIRMessagingDelegate. If you don't use the new flag, for iOS 10 and above,
  direct channel data messages are delivered in
  `FIRMessagingDelegate messaging:didReceiveMessage:`; for iOS 9 and below,
  direct channel data messages are delivered in Apple's
  `AppDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:`.
  So if you set the useFIRMessagingDelegateForDirectMessageDelivery to true,
  direct channel data messages are delivered in FIRMessagingDelegate across all
  iOS versions. (#1875)
- [fixed] Fix an issue that callback is not triggered when topic name is invalid. (#1880)

# 3.1.1
- [fixed] Ensure NSUserDefaults is persisted properly before app close. (#1646)
- [changed] Internal code cleanup. (#1666)

# 3.1.0
- [fixed] Added support for global Firebase data collection flag. (#1219)
- [fixed] Fixed an issue where Messaging wouldn't properly unswizzle swizzled delegate
  methods. (#1481)
- [fixed] Fixed an issue that Messaging doesn't compile inside app extension. (#1503)

# 3.0.3
- [fixed] Fixed an issue that client should suspend the topic requests when token is not available and resume the topic operation when the token is generated.
- [fixed] Corrected the deprecation warning when subscribing to or unsubscribing from an invalid topic. (#1397)
- [changed] Removed unused heart beat time stamp tracking.

# 3.0.2
- [added] Added a warning message when subscribing to topics with incorrect name formats.
- [fixed] Silenced a deprecation warning in FIRMessaging.

# 3.0.1
- [fixed] Clean up a few deprecation warnings.

# 3.0.0
- [removed] Remove deprecated delegate property `remoteMessageDelegate`, please use `delegate` instead.
- [removed] Remove deprecated method `messaging:didRefreshRegistrationToken:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveRegistrationToken:` instead.
- [removed] Remove deprecated method `applicationReceivedRemoteMessage:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveMessage:` instead.
- [fixed] Fix an issue that data messages were not tracked successfully.

# 2.2.0
- [added] Add new methods that provide completion handlers for topic subscription and unsubscription.

# 2.1.1
- [changed] Improve documentation on the usage of the autoInitEnabled property.

# 2.1.0
- [added] Added a new property autoInitEnabled to enable and disable FCM token auto generation.
- [fixed] Fixed an issue where notification delivery would fail after changing language settings.

# 2.0.5
- [added] Added swizzling of additional UNUserNotificationCenterDelegate method, for
  more accurate Analytics logging.
- [fixed] Fixed a swizzling issue with unimplemented UNUserNotificationCenterDelegate
  methods.

# 2.0.4
- [fixed] Fixed an issue where the FCM token was not associating correctly with an APNs
  device token, depending on when the APNs device token was made available.
- [fixed] Fixed an issue where FCM tokens for different Sender IDs were not associating
  correctly with an APNs device token.
- [fixed] Fixed an issue that was preventing the FCM direct channel from being
  established on the first start after 24 hours of being opened.
- [changed] Clarified a log message about method swizzling being enabled.

# 2.0.3
- [fixed] Moved to safer use of NSAsserts, instead of lower-level `__builtin_trap()`
  method.
- [added] Added logging of the underlying error code for an error trying to create or
  open an internal database file.

# 2.0.2
- [changed] Removed old logic which was saving the SDK version to NSUserDefaults.

# 2.0.1
- [fixed] Fixed an issue where setting `shouldEstablishDirectChannel` in a background
  thread was triggering the Main Thread Sanitizer in Xcode 9.
- [changed] Removed some old logic related to logging.
- [changed] Added some additional logging around errors while method swizzling.

# 2.0.0
- [feature] Introduced an improved interface for Swift 3 developers
- [added] Added new properties and methods to simplify FCM token management
- [added] Added property, APNSToken, to simplify APNs token management
- [added] Added new delegate method to be notified of FCM token refreshes
- [added] Added new property, shouldEstablishDirectChannel, to simplify connecting
  directly to FCM

# 1.2.3

- [fixed] Fixed an issue where custom UNNotificationCenterDelegates may not have been
  swizzled (if swizzling was enabled)
- [fixed] Fixed a issue iOS 8.0 and 8.1 devices using scheduled notifications
- [changed] Improvements to console logging

# 1.2.2

- [fixed] Improved topic subscription logic for more reliable subscriptions.
- [fixed] Reduced memory footprint and CPU usage when subscribing to multiple topics.
- [changed] Better documentation in the public headers.
- [changed] Switched from ProtocolBuffers2 to protobuf compiler.

# 1.2.1

- [changed] Better documentation on the public headers.

# 1.2.0

- [added] Support the UserNotifications framework introduced in iOS 10.
- [added] Add a new API, `-applicationReceivedRemoteMessage:`, to FIRMessaging. This
  allows apps to receive data messages from FCM on devices running iOS 10 and
  above.

# 1.1.1

- [changed] Move FIRMessaging related plists to ApplicationSupport directory.

# 1.1.0

- [changed] Change flag to disable swizzling to *FirebaseAppDelegateProxyEnabled*.
- [changed] `-[FIRMessaging appDidReceiveMessage:]` returns FIRMessagingMessageInfo object.
- [fixed] Minor bug fixes.

# 1.0.2

- [changed] Accept topic names without /topics prefix.
- [fixed] Add Swift annotations to public static accessors.

# 1.0.0

- [feature] New Firebase messaging API.
