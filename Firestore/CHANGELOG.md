# Unreleased
- [changed] Removed the includeMetadataChanges property in FIRDocumentListenOptions
  to avoid confusion with the factory method of the same name.
- [changed] Added a commit method that takes no completion handler to FIRWriteBatch.
- [feature] Queries can now be created from an NSPredicate.
- [added] Added SnapshotOptions API to control how DocumentSnapshots return unresolved
  server timestamps.

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
