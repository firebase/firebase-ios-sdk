# v8.10.0
- [fixed] Fixed URL handling bug when path is a substring of host. (#8874)

# v8.7.0
- [fixed] Fixed Firebase App Check token periodic refresh. (#8544)

# v8.5.0
- [fixed] FirebaseDatabase `getData()` callbacks are now called on the main thread. (#8247)

# v8.0.0
- [added] Added abuse reduction features. (#7928, #7943)

# v7.9.0
- [added] Added community support for watchOS. (#4556)

# v7.7.0
- [fixed] Fix variable length array diagnostics warning (#7460).

# v7.6.0
- [changed] Optimize `FIRDatabaseQuery#getDataWithCompletionBlock` when in-memory active listener cache exists (#7312).
- [fixed] Fixed an issue with `FIRDatabaseQuery#{queryStartingAfterValue,queryEndingBeforeValue}`
  when used in `queryOrderedByKey` queries (#7403).

# v7.5.0
- [added] Implmement `queryStartingAfterValue` and `queryEndingBeforeValue` for FirebaseDatabase query pagination.
- [added] Added `DatabaseQuery#getData` which returns data from the server when cache is stale (#7110).

# v7.2.0
- [added] Made emulator connection API consistent between Auth, Database, Firestore, and Functions (#5916).

# v7.0.0
- [fixed] Disabled a deprecation warning. (#6502)

# v6.6.0
- [feature] The SDK can now infer a default database URL if none is provided in
  the config.

# v6.4.0
- [changed] Functionally neutral source reorganization. (#5861)

# v6.2.2
- [fixed] Addressed crash that prevented the SDK from opening when the versioning file was
  corrupted. (#5686)
- [changed] Added internal HTTP header to the WebChannel connection.


# v6.2.1
- [fixed] Fixed documentation typos. (#5406, #5418)

# v6.2.0
- [feature] Added `ServerValue.increment()` to support atomic field value increments
  without transactions.

# v6.1.4
- [changed] Addressed a performance regression introduced in 6.1.3.

# v6.1.3
- [changed] Internal changes.

# v6.1.2
- [fixed] Addressed an issue with `NSDecimalNumber` case that prevented decimals with
  high precision to be stored correctly in our persistence layer. (#4108)

# v6.1.1
- [fixed] Fixed an iOS 13 crash that occured in our WebSocket error handling. (#3950)

# v6.1.0
- [fixed] Fix Catalyst Build issue. (#3512)
- [feature] The SDK adds support for the Firebase Database Emulator. To connect
  to the emulator, specify "http://<emulator_host>/" as your Database URL
  (via `Database.database(url:)`).
  If you refer to your emulator host by IP rather than by domain name, you may
  also need to specify a namespace ("http://<emulator_host>/?ns=<namespace>"). (#3491)

# v6.0.0
- [removed] Remove deprecated `childByAppendingPath` API. (#2763)

# v5.1.1
- [fixed] Fixed crash in FSRWebSocket. (#2485)

# v5.0.2
- [fixed] Fixed undefined behavior sanitizer issues. (#1443, #1444)

# v4.1.5
- [fixed] Fixes loss of precision for 64 bit numbers on older 32 bit iOS devices with persistence enabled.
- [changed] Addresses CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF warnings that surface in newer versions of Xcode and CocoaPods.

# v4.1.4
- [added] Firebase Database is now community-supported on tvOS.

# v4.1.3
- [changed] Internal cleanup in the firebase-ios-sdk repository. Functionality of the RTDB SDK is not affected.

# v4.1.2
- [fixed] Addresses race condition that can occur during the initialization of empty snapshots.

# v4.1.1
- [fixed] Fixed warnings for callback types with missing argument specifications in Xcode 9.

# v4.1.0
- Added [multi-resource](https://firebase.google.com/docs/database/usage/sharding) support to the database SDK.

# v4.0.3
- [fixed] Fixed a regression in v4.0.2 that affected the storage location of the offline persistent cache. This caused v4.0.2 to not see data written with previous versions.
- [fixed] Fixed a crash in `FIRApp deleteApp` for apps that did not have active database instances.

# v4.0.2
- [fixed] Retrieving a Database instance for a specific `FirebaseApp` no longer returns a stale instance if that app was deleted.
- [changed] Added message about bandwidth usage in error for queries without indexes.

# v4.0.1
- [changed] We now purge the local cache if we can't load from it.
- [fixed] Removed implicit number type conversion for some integers that were represented as doubles after round-tripping through the server.
- [fixed] Fixed crash for messages that were send to closed WebSocket connections.

# v4.0.0
- [changed] Initial Open Source release.

# v3.1.2

- [changed] Removed unnecessary _CodeSignature folder to address compiler
  warning for "Failed to parse Mach-O: Reached end of file while looking for:
  uint32_t".
- [changed] Log a message when an observeEvent call is rejected due to security
  rules.

# v3.1.1

- [changed] Unified logging format.

# v3.1.0

- [feature] Reintroduced the persistenceCacheSizeBytes setting (previously
  available in the 2.x SDK) to control the disk size of Firebase's offline
  cache.
- [fixed] Use of the updateChildValues() method now only cancels transactions
  that are directly included in the updated paths (not transactions in adjacent
  paths). For example, an update at /move for a child node walk will cancel
  transactions at /, /move, and /move/walk and in any child nodes under
  /move/walk. But, it will no longer cancel transactions at sibling nodes,
  such as /move/run.

# v3.0.3

- [fixed] Fixed an issue causing transactions to fail if executed before the
  SDK connects to the Firebase Database backend.
- [fixed] Fixed a race condition where doing a transaction or adding an event
  observer immediately after connecting to the Firebase Database backend could
  result in completion blocks for other operations not getting executed.
- [fixed] Fixed an issue affecting apps using offline disk persistence where
  large integer values could lose precision after an app restart.
