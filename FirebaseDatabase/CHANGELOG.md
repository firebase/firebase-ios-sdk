# 11.2.0
- [fixed] Fix temporary disconnects when the app goes inactive. The issue was
  introduced in 10.27.0. (#13529)

# 11.0.0
- [removed] **Breaking change**: The deprecated `FirebaseDatabaseSwift`
  module has been removed. See
  https://firebase.google.com/docs/ios/swift-migration for migration
  instructions.
- [removed] Socket Rocket has been removed from the implementation. There should
  be no impact on functionality. (#13100)

# 10.27.0
- [changed] Update internal socket implementation to use `NSURLSessionWebSocket` where
  available. (#12883)

# 10.25.0
- [changed] Removed usages of user defaults API to eliminate required reason impact.

# 10.17.0
- [feature] The `FirebaseDatabase` module now contains Firebase Database's
  Swift-only APIs that were previously only available via the
  `FirebaseDatabaseSwift` extension SDK. See the
  `FirebaseDatabaseSwift` release note from this release for more details.

# 10.0.0
- [deprecated] Deprecated `FirebaseDatabase` on watchOS 9 and above.
  watchOS users should instead use the Database REST API directly (#19272).

# 9.6.0
- [fixed] Fix priority inversion issue exposed by Xcode 14. (#10130)

# 9.3.0
- [fixed] Fix `reference(withPath:)` race condition crash. (#7885)

# 8.12.0
- [fixed] **Breaking change:** Mark `getData()` snapshot as nullable to fix Swift API. (#9655)

# 8.11.0
- [fixed] Race condition crash in FUtilities.m. (#9096)
- [fixed] FNextPushId 'successor' crash. (#8790)

# 8.10.0
- [fixed] Fixed URL handling bug when path is a substring of host. (#8874)

# 8.7.0
- [fixed] Fixed Firebase App Check token periodic refresh. (#8544)

# 8.5.0
- [fixed] FirebaseDatabase `getData()` callbacks are now called on the main thread. (#8247)

# 8.0.0
- [added] Added abuse reduction features. (#7928, #7943)

# 7.9.0
- [added] Added community support for watchOS. (#4556)

# 7.7.0
- [fixed] Fix variable length array diagnostics warning (#7460).

# 7.6.0
- [changed] Optimize `FIRDatabaseQuery#getDataWithCompletionBlock` when in-memory active listener cache exists (#7312).
- [fixed] Fixed an issue with `FIRDatabaseQuery#{queryStartingAfterValue,queryEndingBeforeValue}`
  when used in `queryOrderedByKey` queries (#7403).

# 7.5.0
- [added] Implmement `queryStartingAfterValue` and `queryEndingBeforeValue` for FirebaseDatabase query pagination.
- [added] Added `DatabaseQuery#getData` which returns data from the server when cache is stale (#7110).

# 7.2.0
- [added] Made emulator connection API consistent between Auth, Database, Firestore, and Functions (#5916).

# 7.0.0
- [fixed] Disabled a deprecation warning. (#6502)

# 6.6.0
- [feature] The SDK can now infer a default database URL if none is provided in
  the config.

# 6.4.0
- [changed] Functionally neutral source reorganization. (#5861)

# 6.2.2
- [fixed] Addressed crash that prevented the SDK from opening when the versioning file was
  corrupted. (#5686)
- [changed] Added internal HTTP header to the WebChannel connection.

# 6.2.1
- [fixed] Fixed documentation typos. (#5406, #5418)

# 6.2.0
- [feature] Added `ServerValue.increment()` to support atomic field value increments
  without transactions.

# 6.1.4
- [changed] Addressed a performance regression introduced in 6.1.3.

# 6.1.3
- [changed] Internal changes.

# 6.1.2
- [fixed] Addressed an issue with `NSDecimalNumber` case that prevented decimals with
  high precision to be stored correctly in our persistence layer. (#4108)

# 6.1.1
- [fixed] Fixed an iOS 13 crash that occurred in our WebSocket error handling. (#3950)

# 6.1.0
- [fixed] Fix Catalyst Build issue. (#3512)
- [feature] The SDK adds support for the Firebase Database Emulator. To connect
  to the emulator, specify "http://<emulator_host>/" as your Database URL
  (via `Database.database(url:)`).
  If you refer to your emulator host by IP rather than by domain name, you may
  also need to specify a namespace ("http://<emulator_host>/?ns=<namespace>"). (#3491)

# 6.0.0
- [removed] Remove deprecated `childByAppendingPath` API. (#2763)

# 5.1.1
- [fixed] Fixed crash in FSRWebSocket. (#2485)

# 5.0.2
- [fixed] Fixed undefined behavior sanitizer issues. (#1443, #1444)

# 4.1.5
- [fixed] Fixes loss of precision for 64 bit numbers on older 32 bit iOS devices with persistence enabled.
- [changed] Addresses CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF warnings that surface in newer versions of Xcode and CocoaPods.

# 4.1.4
- [added] Firebase Database is now community-supported on tvOS.

# 4.1.3
- [changed] Internal cleanup in the firebase-ios-sdk repository. Functionality of the RTDB SDK is not affected.

# 4.1.2
- [fixed] Addresses race condition that can occur during the initialization of empty snapshots.

# 4.1.1
- [fixed] Fixed warnings for callback types with missing argument specifications in Xcode 9.

# 4.1.0
- Added [multi-resource](https://firebase.google.com/docs/database/usage/sharding) support to the database SDK.

# 4.0.3
- [fixed] Fixed a regression in v4.0.2 that affected the storage location of the offline persistent cache. This caused v4.0.2 to not see data written with previous versions.
- [fixed] Fixed a crash in `FIRApp deleteApp` for apps that did not have active database instances.

# 4.0.2
- [fixed] Retrieving a Database instance for a specific `FirebaseApp` no longer returns a stale instance if that app was deleted.
- [changed] Added message about bandwidth usage in error for queries without indexes.

# 4.0.1
- [changed] We now purge the local cache if we can't load from it.
- [fixed] Removed implicit number type conversion for some integers that were represented as doubles after round-tripping through the server.
- [fixed] Fixed crash for messages that were send to closed WebSocket connections.

# 4.0.0
- [changed] Initial Open Source release.

# 3.1.2
- [changed] Removed unnecessary _CodeSignature folder to address compiler
  warning for "Failed to parse Mach-O: Reached end of file while looking for:
  uint32_t".
- [changed] Log a message when an observeEvent call is rejected due to security
  rules.

# 3.1.1
- [changed] Unified logging format.

# 3.1.0
- [feature] Reintroduced the persistenceCacheSizeBytes setting (previously
  available in the 2.x SDK) to control the disk size of Firebase's offline
  cache.
- [fixed] Use of the updateChildValues() method now only cancels transactions
  that are directly included in the updated paths (not transactions in adjacent
  paths). For example, an update at /move for a child node walk will cancel
  transactions at /, /move, and /move/walk and in any child nodes under
  /move/walk. But, it will no longer cancel transactions at sibling nodes,
  such as /move/run.

# 3.0.3
- [fixed] Fixed an issue causing transactions to fail if executed before the
  SDK connects to the Firebase Database backend.
- [fixed] Fixed a race condition where doing a transaction or adding an event
  observer immediately after connecting to the Firebase Database backend could
  result in completion blocks for other operations not getting executed.
- [fixed] Fixed an issue affecting apps using offline disk persistence where
  large integer values could lose precision after an app restart.
