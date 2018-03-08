# Unreleased

# v0.10.3
- [fixed] Fixed a regression in the 4.10.0 Firebase iOS SDK release that
  prevented the SDK from communicating with the backend before successfully
  authenticating via Firebase Authentication or after unauthenticating and
  re-authenticating. Reads and writes would silently be executed locally
  but not sent to the backend.

# v0.10.2
- [changed] When you delete a FirebaseApp, the associated Firestore instances
  are now also deleted (#683).
- [fixed] Fixed race conditions in streams that could be exposed by rapidly
  toggling the network from enabled to disabled and back (#772) or encountering
  a failure from the server (#835).
- [fixed] Addressed warnings shown by the latest versions of Xcode and CocoaPods.

# v0.10.1
- [fixed] Fixed a regression in Firebase iOS release 4.8.1 that could in certain
  cases result in an "OnlineState should not affect limbo documents." assertion
  crash when the client loses its network connection.
- [fixed] It's now possible to pass a nil completion block to WriteBatch.commit (#745).

# v0.10.0
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

# v0.9.4
- [changed] Firestore no longer has a direct dependency on FirebaseAuth.
- [fixed] Fixed a crash when using path names with international characters
  with persistence enabled.
- [fixed] Addressed race condition during the teardown of idle streams (#490).

# v0.9.3
- [changed] Improved performance loading documents matching a query.
- [changed] Cleanly shut down idle write streams.

# v0.9.2
- [changed] Firestore now retries requests more often before considering a client offline.
- [changed] You can now use FieldValue.delete() with SetOptions.merge().

# v0.9.1
- [fixed] Fixed validation of nested arrays to allow indirect nesting.

# v0.9.0
- [fixed] Add an NS_SWIFT_NAME for FIRSnapshotMetadata and FIRListenerRegistration.
- [fixed] Fixed retain cycle in DocumentReference.getDocument(completion:).

# v0.8.0
- Initial public release.
