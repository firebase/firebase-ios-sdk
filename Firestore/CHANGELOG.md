# 11.6.0
- [fixed] Add conditional `Sendable` conformance so `ServerTimestamp<T>` is
  `Sendable` if `T` is `Sendable`. (#14042)

# 11.4.0
- [changed] Prepare Firestore cache to support session token.

# 11.3.0
- [changed] Improve efficiency of memory persistence when processing a large number of writes. (#13572)

# 11.2.0
- [fixed] Marked all public classes with only readonly properties as `Sendable` to address
  Swift Concurrency Check warning. (#12666)

# 11.1.0
- [feature] Add `VectorValue` type support.

# 11.0.0
- [removed] **Breaking change**: The deprecated `FirebaseFirestoreSwift` module
  has been removed. See
  https://firebase.google.com/docs/ios/swift-migration for migration
  instructions.
- [changed] **Breaking change**: LRU Garbage Collector is now the default GC for memory cache, eager GC is now
  opt-in (via MemoryCacheSettings(garbageCollectorSettings: MemoryEagerGCSettings())) instead of the default one.
- [changed] Move `Timestamp` class into `FirebaseCore`. `FirebaseFirestore.Timestamp`
  was changed to `FirebaseCore.Timestamp`. (#13221)
- [changed] Update gRPC dependency to 1.65.

# 10.25.0
- [fixed] Allow blob of data with zero length. (#11773, #12620)
- [changed] Passing a non-nil value to the `@DocumentID` property wrapper's
  setter no longer logs a warning since it discouraged valid patterns,
  e.g., updating the document ID after the document is created in Firestore. (#12756)

# 10.24.0
- [feature] Enable queries with range & inequality filters on multiple fields. (#12416)

# 10.23.0
- [feature] Enable snapshot listener option to retrieve data from local cache only. (#12370)
- [fixed] Update gRPC dependency to 1.62.* (#12098, #12021)
- [feature] Firestore's binary Swift Package Manager distribution uses
  XCFrameworks with code signatures (#12238).

# 10.22.0
- [fixed] Fix the flaky offline behaviour when using `arrayRemove` on `Map` object. (#12378)

# 10.21.0
- Add an error when trying to build Firestore's binary SPM distribution for
  visionOS (#12279). See Firestore's 10.12.0 release note for a supported
  workaround.

# 10.19.0
- [fixed] Made an optimization to the synchronization logic for resumed queries
  to only re-download locally-cached documents that are known to be out-of-sync. (#12044)

# 10.18.0
- [fixed] Fix Firestore build for visionOS on Xcode 15.1. (#12023)

# 10.17.0
- [feature] Add support for sum and average aggregate queries.
- [feature] The `FirebaseFirestore` module now contains Firebase Firestore's
  Swift-only APIs that were previously only available via the
  `FirebaseFirestoreSwift` extension SDK. See the
  `FirebaseFirestoreSwift` release note from this release for more details.

# 10.16.0
- [fixed] Fixed an issue where Firestore's binary SwiftPM distribution would
  not link properly when building a target for testing. This issue affected
  Xcode 15 Beta 5 and later (#11656).
- [fixed] Downgrade the CocoaPods grpc dependency back to 1.44.0 (from 1.50.1)
  to fix a crash on iOS 12 devices that was introduced in the Firebase Apple SDK
  10.10.0 when the grpc dependency was upgraded (#11509).

# 10.15.0
- [feature] Add the option to allow the SDK to create cache indexes automatically to
  improve query execution locally. (#11596)

# 10.12.0
- [feature] Implemented an optimization in the local cache synchronization logic
  that reduces the number of billed document reads when documents were deleted
  on the server while the client was not actively listening to the query
  (e.g. while the client was offline). (#11457)
- [added] Developers using Firestore on **visionOS** must use a source
  Firestore distribution rather than the default binary distribution. To do
  this, quit Xcode and open the desired project from the command line
  with the `FIREBASE_SOURCE_FIRESTORE` environment variable:
  ```
  open --env FIREBASE_SOURCE_FIRESTORE /path/to/project.xcodeproj
  ```
  To go back to using the binary distribution of Firestore, quit Xcode and
  open Xcode like normal, without the environment variable. (#11492)

# 10.11.0
- [feature] Expose MultiDb API for public preview. (#10465)
- [fixed] Fixed a compilation warning related to integer casting. (#11332)
- [fixed] Allow initializing FIRLocalCacheSettings with unlimited size. (#11405)

# 10.9.0
- [feature] Add new cache config API to customize SDK cache settings.
- [feature] Add LRU garbage collector as an option to memory cache.

# 10.8.0
- [feature] Change Firestore's Swift Package Manager distribution from source
  to binary to reduce the time it takes to add the Firebase package and to
  build the Firestore SDK (#6564).
- [fixed] Fixed SSL symbol collision issue affecting SwiftPM users. (#6869)

# 10.7.0
- [feature] Add support for disjunctions in queries (`OR` queries).
- [fixed] Fixed stack overflow caused by deeply nested server timestamps.

# 10.6.0
- [fixed] Fix a potential high memory usage issue.

# 10.5.0
- [fixed] Add @discardableResult to addDocument API for easy handling unused return value. (#10640)

# 10.4.0
- [fixed] Fix an issue that stops some performance optimization being applied (#10579).

# 10.3.0
- [feature] Add MultiDb support.
- [fixed] Fix App crashed when there are nested data structures inside IN
  Filter (#10507).

# 10.2.0
- [fixed] Fix FAILED_PRECONDITION when writing to a deleted document in a
  transaction (#10431).
- [fixed] Fixed data race in credentials provider (#10393).
- [fixed] Fix Firestore failing to raise initial snapshot from empty local cache
  result (#10437).

# 10.0.0
- [feature] Added `Query.count()`, which fetches the number of documents in the
  result set without actually downloading the documents (#10246).
- [fixed] Fixed compiler warning about `@param comparator` (#10226).

# 9.6.0
- [added] Expose client side indexing feature with `FIRFirestore.setIndexConfigurationFromJSON` and
  `FIRFirestore.setIndexConfigurationFromStream` (#10090).
- [fixed] Fixed high CPU usage whenever Firestore was in use (#10168).

# 9.5.0
- [fixed] Fixed an intermittent crash if `ListenerRegistration::Remove()` was
  invoked concurrently (#10065).
- [fixed] Fixed a crash if multiple large write batches with overlapping
  documents were executed where at least one batch performed a delete operation
  (#9965).

# 9.4.0
- [fixed] Fixed a crash during app start (#9985, #10018).

# 9.2.0
- [feature] Added `TransactionOptions` to control how many times a transaction
  will retry commits before failing (#9838).

# 9.0.0
- [fixed] Fixed CMake build errors when building with Xcode 13.3.1 (#9702).
- [fixed] **Breaking change:** Fixed an issue where returning `nil` from the
  update closure when running a transaction caused a crash in Swift by removing
  the auto-generated `async throw`ing method from the `FirebaseFirestore`
  module. In order to use the `async throw`ing transaction method, add the
  `FirebaseFirestoreSwift` module dependency to your build target (#9426).

# 8.15.0
- [changed] Potentially fixed a crash during application exit caused by an
  assertion about ordering documents by missing fields (#9258).
- [changed] Add more details to the assertion failure in Query::Comparator() to
  help with future debugging (#9258).

# 8.14.0
- [fixed] Fixed compiler warnings in `local_serializer.cc` about "implicit
  conversion loses integer precision" that were introduced in 8.13.0 (#9430).

# 8.12.1
- [changed] Add more details to the assertion failure in OrderBy::Compare() to
  help with future debugging (#9258).

# 8.11.0
- [fixed] Fixed an issue that can result in incomplete Query snapshots when an
  app is backgrounded during query execution.

# 8.9.1
- [fixed] Fixed a bug in the AppCheck integration that caused the SDK to respond
  to unrelated notifications (#8895).

# 8.9.0
- [added] Added support for Firebase AppCheck.
- [fixed] Fix a crash if `[FIRTransaction getDocument]` was called after
  `[FIRFirestore terminateWithCompletion]` (#8760).
- [fixed] Fixed a performance issue due to repeated schema migrations
  at app startup (#8791).

# 8.6.0
- [changed] Internal refactor to improve serialization performance.
- [changed] `DocumentSnapshot` objects consider the document's key and data for
  equality comparison, but ignore the internal state and internal version.

# 8.4.0
- [fixed] Fixed handling of Unicode characters in log and assertion messages
  (#8372).

# 8.2.0
- [changed] Passing in an empty document ID, collection group ID, or collection
  path will now result in a more readable error (#8218).

# 7.9.0
- [feature] Added support for Firestore Bundles via
  `FIRFirestore.loadBundle`, `FIRFirestore.loadBundleStream` and
  `FIRFirestore.getQueryNamed`. Bundles contain pre-packaged data produced
  with the Server SDKs and can be used to populate Firestore's cache
  without reading documents from the backend.

# 7.7.0
- [fixed] Fixed a crash that could happen when the App is being deleted and
  there's an active listener (#6909).
- [fixed] Fixed a bug where local cache inconsistencies were unnecessarily
  being resolved (#7455).

# 7.5.0
- [changed] A write to a document that contains FieldValue transforms is no
  longer split up into two separate operations. This reduces the number of
  writes the backend performs and allows each WriteBatch to hold 500 writes
  regardless of how many FieldValue transformations are attached.
- [fixed] Fixed an issue where using `FieldValue.arrayRemove()` would only
  delete the first occurrence of an element in an array in a latency
  compensated snapshots.

# 7.3.0
- [fixed] Fixed a crash that could happen when the SDK encountered invalid
  data during garbage collection (#6721).

# 7.2.0
- [added] Made emulator connection API consistent between Auth, Database,
  Firestore, and Functions (#5916).

# 7.1.0
- [changed] Added the original query data to error messages for Queries that
  cannot be deserizialized.
- [fixed] Remove explicit MobileCoreServices library linkage from podspec
  (#6850).
- [fixed] Removed excess validation of null and NaN values in query filters.
  This more closely aligns the SDK with the Firestore backend, which has always
  accepted null and NaN for all operators, even though this isn't necessarily
  useful.

# 7.0.0
- [changed] **Breaking change:** Removed the `areTimestampsInSnapshotsEnabled`
  setting. Timestamp fields that read from a `FIRDocumentSnapshot` now always
  return `FIRTimestamp` objects. Use `FIRTimestamp.dateValue` to convert to
  `NSDate` if required.
- [fixed] Fixed a memory leak introduced in 1.18.0 that may manifest when
  serializing queries containing equality or non-equality comparisons.

# 1.19.0
- [changed] Internal improvements for future C++ and Unity support. Includes a
  breaking change for the Firestore C++ Alpha SDK, but does not affect
  Objective-C or Swift users.
- [changed] Added new internal HTTP headers to the gRPC connection.

# 1.18.0
- [feature] Added `whereField(_:notIn:)` and `whereField(_:isNotEqualTo:)` query
  operators. `whereField(_:notIn:)` finds documents where a specified field’s
  value is not in a specified array. `whereField(_:isNotEqualTo:)` finds
  documents where a specified field's value does not equal the specified value.
  Neither query operator will match documents where the specified field is not
  present.

# 1.17.1
- [fixed] Fix gRPC documentation warning surfaced in Xcode (#6340).

# 1.17.0
- [changed] Internal improvements for future C++ and Unity support.

# 1.16.4
- [changed] Rearranged public headers for future Swift Package Manager support.
  This should have no impact existing users of CocoaPods, Carthage, or zip file
  distributions.

# 1.16.3
- [changed] Internal improvements for future C++ and Unity support.

# 1.16.2
- [fixed] Fixed a configuration issue where listeners were no longer being
  called back on the main thread by default.

# 1.16.1
- [fixed] Removed a delay that may have prevented Firestore from immediately
  establishing a network connection if a connectivity change occurred while
  the app was in the background (#5783).
- [fixed] Fixed a rare crash that could happen if the garbage collection
  process for old documents in the cache happened to run during a LevelDB
  compaction (#5881).

# 1.16.0
- [fixed] Fixed an issue that may have prevented the client from connecting
  to the backend immediately after a user signed in.

# 1.15.0
- [changed] Internal improvements for future C++ and Unity support. Includes a
  breaking change for the Firestore C++ Alpha SDK, but does not affect
  Objective-C or Swift users.

# 1.14.0
- [changed] Internal improvements for future C++ and Unity support. Includes a
  breaking change for the Firestore C++ Alpha SDK, but does not affect
  Objective-C or Swift users.

# 1.13.0
- [changed] Firestore now limits the number of concurrent document lookups it
  will perform when resolving inconsistencies in the local cache
  (https://github.com/firebase/firebase-js-sdk/issues/2683).
- [changed] Upgraded gRPC-C++ to 1.28.0 (#4994).
- [fixed] Firestore will now send Auth credentials to the Firestore Emulator
  (#5072).

# 1.12.1
- [changed] Internal improvements for future C++ and Unity support.

# 1.12.0
- [changed] Internal improvements for future C++ and Unity support. Includes a
  breaking change for the Firestore C++ Alpha SDK, but does not affect
  Objective-C or Swift users.

# 1.11.2
- [fixed] Fixed the FirebaseFirestore podspec to properly declare its
  dependency on the UIKit framework on iOS and tvOS.

# 1.11.1
- [fixed] Firestore should now recover its connection to the server more
  quickly after returning from the background (#4905).

# 1.11.0
- [changed] Improved performance of queries with large result sets.

# 1.10.2
- [changed] Internal improvements.

# 1.10.1
- [changed] Internal improvements.

# 1.10.0
- [feature] Firestore previously required that every document read in a
  transaction must also be written. This requirement has been removed, and
  you can now read a document in a transaction without writing to it.
- [changed] Improved the performance of repeatedly executed queries when
  persistence is enabled. Recently executed queries should see dramatic
  improvements. This benefit is reduced if changes accumulate while the query
  is inactive. Queries that use the `limit()` API may not always benefit,
  depending on the accumulated changes.
- [changed] Changed the location of Firestore's locally stored data from the
  Documents folder to Library/Application Support, hiding it from users of apps
  that share their files with the iOS Files app. **Important**: After a user's
  data is migrated, downgrading to an older version of the SDK will cause the
  user to appear to lose data, since older versions of the SDK can't read data
  from the new location (#843).

# 1.9.0
- [feature] Added a `limit(toLast:)` query operator, which returns the last
  matching documents up to the given limit.

# 1.8.3
- [changed] Internal improvements.

# 1.8.2
- [changed] Internal improvements.

# 1.8.1
- [fixed] Firestore no longer loads its TLS certificates from a bundle, which
  fixes crashes at startup when the bundle can't be loaded. This fixes a
  specific case where the bundle couldn't be loaded due to international
  characters in the application name. If you're manually tracking dependencies,
  you can now remove `gRPCCertificates-Cpp.bundle` from your build. (#3951).

# 1.8.0
- [changed] Removed Firestore's dependency on the `Protobuf` CocoaPod. If
  you're manually tracking dependencies, you may be able to remove it from your
  build (note, however, that other Firebase components may still require it).
- [changed] Added a dependency on the `abseil` CocoaPod. If you're manually
  tracking dependencies, you need to add it to your build.

# 1.7.0
- [feature] Added `whereField(_:in:)` and `whereField(_:arrayContainsAny:)` query
  operators. `whereField(_:in:)` finds documents where a specified field’s value
  is IN a specified array. `whereField(_:arrayContainsAny:)` finds documents
  where a specified field is an array and contains ANY element of a specified
  array.
- [changed] Firestore SDK now uses Nanopb rather than the Objective-C Protobuf
  library for parsing protos. This change does not affect visible behavior of
  the SDK in any way. While we don't anticipate any issues, please [report any
  issues with network behavior or
  persistence](https://github.com/firebase/firebase-ios-sdk/issues/new) that you
  experience.

# 1.6.1
- [fixed] Fixed a race condition that could cause a segmentation fault during
  client initialization.

# 1.6.0
- [feature] Added an `addSnapshotsInSyncListener()` method to
  `FIRFirestore` that notifies you when all your snapshot listeners are
  in sync with each other.

# 1.5.1
- [fixed] Fixed a memory access error discovered using the sanitizers in Xcode
  11.

# 1.5.0
- [changed] Transactions now perform exponential backoff before retrying.
  This means transactions on highly contended documents are more likely to
  succeed.
- [feature] Added a `waitForPendingWrites()` method to `FIRFirestore` class
  which allows users to wait on a promise that resolves when all pending
  writes are acknowledged by the Firestore backend.
- [feature] Added a `terminate()` method to `FIRFirestore` which terminates
  the instance, releasing any held resources. Once it completes, you can
  optionally call `clearPersistence()` to wipe persisted Firestore data
  from disk.

# 1.4.5
- [fixed] Fixed a crash that would happen when changing networks or going from
  online to offline. (#3661).

# 1.4.4
- [changed] Internal improvements.

# 1.4.3
- [changed] Transactions are now more flexible. Some sequences of operations
  that were previously incorrectly disallowed are now allowed. For example,
  after reading a document that doesn't exist, you can now set it multiple
  times successfully in a transaction.

# 1.4.2
- [fixed] Fixed an issue where query results were temporarily missing documents
  that previously had not matched but had been updated to now match the query
  (https://github.com/firebase/firebase-android-sdk/issues/155).
- [fixed] Fixed an internal assertion that was triggered when an update
  with a `FieldValue.serverTimestamp()` and an update with a
  `FieldValue.increment()` were pending for the same document.
- [fixed] Fixed the `oldIndex` and `newIndex` values in `DocumentChange` to
  actually be `NSNotFound` when documents are added or removed, respectively
  (#3298).
- [changed] Failed transactions now return the failure from the last attempt,
  instead of `ABORTED`.

# 1.4.1
- [fixed] Fixed certificate loading for non-CocoaPods builds that may not
  include bundle identifiers in their frameworks or apps (#3184).

# 1.4.0
- [feature] Added `clearPersistence()`, which clears the persistent storage
  including pending writes and cached documents. This is intended to help
  write reliable tests (https://github.com/firebase/firebase-js-sdk/issues/449).

# 1.3.2
- [fixed] Firestore should now recover its connection to the server more
  quickly after being on a network suffering from total packet loss (#2987).
- [fixed] Changed gRPC-C++ dependency to 0.0.9 which adds support for using it
  concurrently with the Objective-C gRPC CocoaPod. This fixes certificate
  errors you might encounter when trying to use Firestore and other Google
  Cloud Objective-C APIs in the same project.

# 1.3.1
- [fixed] Disabling garbage collection now avoids even scheduling the
  collection process. This can be used to prevent crashes in the background when
  using `NSFileProtectionComplete`. Note that Firestore does not support
  operating in this mode--nearly all API calls will cause crashes while file
  protection is enabled. This change just prevents a crash when Firestore is
  idle (#2846).

# 1.3.0
- [feature] You can now query across all collections in your database with a
  given collection ID using the `Firestore.collectionGroup()` method.
- [feature] Added community support for tvOS.

# 1.2.1
- [fixed] Fixed a use-after-free bug that could be observed when using snapshot
  listeners on temporary document references (#2682).

# 1.2.0
- [feature] Added community support for macOS (#434).
- [fixed] Fixed the way gRPC certificates are loaded on macOS (#2604).

# 1.1.0
- [feature] Added `FieldValue.increment()`, which can be used in
  `updateData(_:)` and `setData(_:merge:)` to increment or decrement numeric
  field values safely without transactions.
- [changed] Improved performance when querying over documents that contain
  subcollections (#2466).
- [changed] Prepared the persistence layer to support collection group queries.
  While this feature is not yet available, all schema changes are included
  in this release.

# 1.0.2
- [changed] Internal improvements.

# 1.0.1
- [changed] Internal improvements.

# 1.0.0
- [changed] **Breaking change:** The `areTimestampsInSnapshotsEnabled` setting
  is now enabled by default. Timestamp fields that read from a
  `FIRDocumentSnapshot` will be returned as `FIRTimestamp` objects instead of
  `NSDate` objects. Update any code that expects to receive an `NSDate` object.
  See [the reference
  documentation](https://firebase.google.com/docs/reference/ios/firebasefirestore/api/reference/Classes/FIRFirestoreSettings#/c:objc(cs)FIRFirestoreSettings(py)timestampsInSnapshotsEnabled)
  for more details.
- [changed] **Breaking change:** `FIRTransaction.getDocument()` has been changed
  to return a non-nil `FIRDocumentSnapshot` with `exists` equal to `false` if
  the document does not exist (instead of returning a nil
  `FIRDocumentSnapshot`).  Code that includes `if (snapshot) { ... }` must be
  changed to `if (snapshot.exists) { ... }`.
- [fixed] Fixed a crash that could happen when the app is shut down after
  a write has been sent to the server but before it has been received on
  a listener (#2237).
- [changed] Firestore no longer bundles a copy of the gRPC certificates, now
  that the gRPC-C++ CocoaPod includes them. CocoaPods users should be updated
  automatically. Carthage users should follow the [updated
  instructions](https://github.com/firebase/firebase-ios-sdk/blob/main/Carthage.md)
  to get `gRPCCertificates.bundle` from the correct location.

# 0.16.1
- [fixed] Offline persistence now properly records schema downgrades. This is a
  forward-looking change that allows all subsequent versions to safely downgrade
  to this version. Some other versions might be safe to downgrade to, if you can
  determine there haven't been any schema migrations between them. For example,
  downgrading from v0.16.1 to v0.15.0 is safe because there have been no schema
  changes between these releases.
- [fixed] Fixed an issue where gRPC would crash if shut down multiple times
  (#2146).

# 0.16.0
- [changed] Added a garbage collection process to on-disk persistence that
  removes older documents. This is enabled by default, and the SDK will attempt
  to periodically clean up older, unused documents once the on-disk cache passes
  a threshold size (default: 100 MB). This threshold can be configured by
  setting `FIRFirestoreSettings.cacheSizeBytes`. It must be set to a minimum of
  1 MB. The garbage collection process can be disabled entirely by setting
  `FIRFirestoreSettings.cacheSizeBytes` to `kFIRFirestoreCacheSizeUnlimited`.

# 0.15.0
- [changed] Changed how the SDK handles locally-updated documents while syncing
  those updates with Cloud Firestore servers. This can lead to slight behavior
  changes and may affect the `SnapshotMetadata.hasPendingWrites` metadata flag.
- [changed] Eliminated superfluous update events for locally cached documents
  that are known to lag behind the server version. Instead, the SDK buffers
  these events until the client has caught up with the server.
- [changed] Moved from Objective-C gRPC framework to gRPC C++. If you're
  manually tracking dependencies, the `gRPC`, `gRPC-ProtoRPC`, and
  `gRPC-RxLibrary` frameworks have been replaced with `gRPC-C++`. While we
  don't anticipate any issues, please [report any issues with network
  behavior](https://github.com/firebase/firebase-ios-sdk/issues/new) you
  experience. (#1968)

# 0.14.0
- [fixed] Fixed compilation in C99 and C++11 modes without GNU extensions.

# 0.13.6
- [changed] Internal improvements.

# 0.13.5
- [changed] Some SDK errors that represent common mistakes (such as permission
  denied or a missing index) will automatically be logged as a warning in
  addition to being surfaced via the API.

# 0.13.4
- [fixed] Fixed an issue where the first `get()` call made after being offline
  could incorrectly return cached data without attempting to reach the backend.
- [changed] Changed `get()` to only make one attempt to reach the backend before
  returning cached data, potentially reducing delays while offline.
- [fixed] Fixed an issue that caused Firebase to drop empty objects from calls
  to `setData(..., merge:true)`.

# 0.13.3
- [changed] Internal improvements.

# 0.13.2
- [fixed] Fixed an issue where changes to custom authentication claims did not
  take effect until you did a full sign-out and sign-in. (#1499)
- [changed] Improved how Firestore handles idle queries to reduce the cost of
  re-listening within 30 minutes.

# 0.13.1
- [fixed] Fixed an issue where `get(source:.Cache)` could throw an
  "unrecognized selector" error if the SDK has previously cached the
  non-existence of the document (#1632).

# 0.13.0
- [feature] Added `FieldValue.arrayUnion()` and `FieldValue.arrayRemove()` to
  atomically add and remove elements from an array field in a document.
- [feature] Added `whereField(_:arrayContains:)` query filter to find
  documents where an array field contains a specific element.
- [fixed] Fixed compilation with older Xcode versions (#1517).
- [fixed] Fixed a performance issue where large write batches with hundreds of
  changes would take a long time to read and write and consume excessive memory.
  Large write batches should now see no penalty.
- [fixed] Fixed a performance issue where adding a listener for a large
  (thousands of documents) collection would take a long time in offline mode
  (#1477).
- [fixed] Fixed an issue that could cause deleted documents to momentarily
  re-appear in the results of a listener, causing a flicker (#1591).

# 0.12.6
- [fixed] Fixed an issue where queries returned fewer results than they should,
  caused by documents that were cached as deleted when they should not have
  been (#1548). Some cache data is cleared and so clients may use extra
  bandwidth the first time they launch with this version of the SDK.

# 0.12.5
- [changed] Internal improvements.

# 0.12.4
- [fixed] `setData` methods taking `mergeFields:` arguments can now delete
  fields using `FieldValue.delete()`.
- [fixed] Firestore will now recover from auth token expiration when the system
  clock is wrong.
- [fixed] Fixed compilation with older Xcode versions (#1366).

# 0.12.3
- [changed] Internal improvements.

# 0.12.2
- [fixed] Fixed an issue where `FirestoreSettings` would accept a concurrent
  dispatch queue, but this configuration would trigger an assertion failure.
  Passing a concurrent dispatch queue should now work correctly (#988).

# 0.12.1
- [changed] Internal improvements.

# 0.12.0
- [changed] Replaced the `DocumentListenOptions` object with a simple boolean.
  Instead of calling
  `addSnapshotListener(options: DocumentListenOptions.includeMetadataChanges(true))`
  call `addSnapshotListener(includeMetadataChanges:true)`.
- [changed] Replaced the `QueryListenOptions` object with simple booleans.
  Instead of calling
  `addSnapshotListener(options:
      QueryListenOptions.includeQueryMetadataChanges(true)
          .includeDocumentMetadataChanges(true))`
  call `addSnapshotListener(includeMetadataChanges:true)`.
- [changed] `QuerySnapshot.documentChanges()` is now a method which optionally
  takes `includeMetadataChanges:true`. By default even when listening to a
  query with `includeMetadataChanges:true` metadata-only document changes are
  suppressed in `documentChanges()`.
- [changed] Replaced the `SetOptions` object with a simple boolean. Instead of
  calling `setData(["a": "b"], options: SetOptions.merge())` call
  `setData(["a": "b"], merge: true)`.
- [changed] Replaced the `SnapshotOptions` object with direct use of the
  `FIRServerTimestampBehavior` on `DocumentSnapshot`. Instead of calling
  `data(SnapshotOptions.serverTimestampBehavior(.estimate))` call
  `data(serverTimestampBehavior: .estimate)`. Changed `get` similarly.
- [changed] Added ability to control whether DocumentReference.getDocument() and
  Query.getDocuments() should fetch from server only, cache only, or attempt
  server and fall back to the cache (which was the only option previously, and
  is now the default.)
- [feature] Added new `mergeFields:(NSArray<id>*)` override for `set()`
  which allows merging of a reduced subset of fields.

# 0.11.0
- [fixed] Fixed a regression in the Firebase iOS SDK release 4.11.0 that could
  cause `getDocument()` requests made while offline to be delayed by up to 10
  seconds (rather than returning from cache immediately).
- [feature] Added a new `Timestamp` class to represent timestamp fields,
  currently supporting up to microsecond precision. It can be passed to API
  methods anywhere a system Date is currently accepted. To make
  `DocumentSnapshot`s read timestamp fields back as `Timestamp`s instead of
  Dates, you can set the newly added property `areTimestampsInSnapshotsEnabled`
  in `FirestoreSettings` to `true`. Note that the current behavior
  (`DocumentSnapshot`s returning system Dates) will be removed in a future
  release. Using `Timestamp`s avoids rounding errors (system Date is stored as
  a floating-point value, so the value read back from a `DocumentSnapshot`
  might be slightly different from the value written).

# 0.10.4
- [changed] If the SDK's attempt to connect to the Cloud Firestore backend
  neither succeeds nor fails within 10 seconds, the SDK will consider itself
  "offline", causing getDocument() calls to resolve with cached results, rather
  than continuing to wait.
- [fixed] Fixed a race condition after calling `enableNetwork()` that could
  result in a "Mutation batchIDs must be acknowledged in order" assertion crash.
- [fixed] Fixed undefined symbols in the absl namespace (#898).

# 0.10.3
- [fixed] Fixed a regression in the 4.10.0 Firebase iOS SDK release that
  prevented the SDK from communicating with the backend before successfully
  authenticating via Firebase Authentication or after unauthenticating and
  re-authenticating. Reads and writes would silently be executed locally
  but not sent to the backend.

# 0.10.2
- [changed] When you delete a FirebaseApp, the associated Firestore instances
  are now also deleted (#683).
- [fixed] Fixed race conditions in streams that could be exposed by rapidly
  toggling the network from enabled to disabled and back (#772) or encountering
  a failure from the server (#835).
- [fixed] Addressed warnings shown by the latest versions of Xcode and CocoaPods.

# 0.10.1
- [fixed] Fixed a regression in Firebase iOS release 4.8.1 that could in certain
  cases result in an "OnlineState should not affect limbo documents." assertion
  crash when the client loses its network connection.
- [fixed] It's now possible to pass a nil completion block to WriteBatch.commit (#745).

# 0.10.0
- [changed] Removed the includeMetadataChanges property in FIRDocumentListenOptions
  to avoid confusion with the factory method of the same name.
- [changed] Added a commit method that takes no completion handler to FIRWriteBatch.
- [feature] Queries can now be created from an NSPredicate.
- [feature] Added SnapshotOptions API to control how DocumentSnapshots return unresolved
  server timestamps.
- [feature] Added `disableNetwork()` and `enableNetwork()` methods to
  `Firestore` class, allowing for explicit network management.
- [changed] For non-existing documents, DocumentSnapshot.data() now returns `nil`
  instead of throwing an exception. A non-nullable QueryDocumentSnapshot is
  introduced for Queries to reduce the number of nil-checks in your code.
- [changed] Snapshot listeners (with the `includeMetadataChanges` option
  enabled) now receive an event with `snapshot.metadata.isFromCache` set to
  `true` if the SDK loses its connection to the backend. A new event with
  `snapshot.metadata.isFromCache` set to false will be raised once the
  connection is restored and the query is in sync with the backend again.
- [fixed] Multiple offline mutations now properly reflected in retrieved
  documents. Previously, only the last mutation would be visible. (#643)
- [fixed] Fixed a crash in `closeWithFinaleState:` that could be triggered by
  signing out when the app didn't have a network connection.

# 0.9.4
- [changed] Firestore no longer has a direct dependency on FirebaseAuth.
- [fixed] Fixed a crash when using path names with international characters
  with persistence enabled.
- [fixed] Addressed race condition during the teardown of idle streams (#490).

# 0.9.3
- [changed] Improved performance loading documents matching a query.
- [changed] Cleanly shut down idle write streams.

# 0.9.2
- [changed] Firestore now retries requests more often before considering a client offline.
- [changed] You can now use FieldValue.delete() with SetOptions.merge().

# 0.9.1
- [fixed] Fixed validation of nested arrays to allow indirect nesting.

# 0.9.0
- [fixed] Add an NS_SWIFT_NAME for FIRSnapshotMetadata and FIRListenerRegistration.
- [fixed] Fixed retain cycle in DocumentReference.getDocument(completion:).

# 0.8.0
- Initial public release.
