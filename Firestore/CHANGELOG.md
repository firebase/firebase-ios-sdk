# Unreleased

# v0.10.0
- [changed] Removed the includeMetadataChanges property in FIRDocumentListenOptions
  to avoid confusion with the factory method of the same name.
- [changed] Added a commit method that takes no completion handler to FIRWriteBatch.
- [feature] Queries can now be created from an NSPredicate.
- [added] Added SnapshotOptions API to control how DocumentSnapshots return unresolved
  server timestamps.
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
