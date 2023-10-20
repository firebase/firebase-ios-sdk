# 10.17.0
- [deprecated] All of the public API from `FirebaseFirestoreSwift` can now
  be accessed through the `FirebaseFirestore` module. Therefore,
  `FirebaseFirestoreSwift` has been deprecated, and will be removed in a
  future release. See https://firebase.google.com/docs/ios/swift-migration for
  migration instructions.

# 10.12.0
- [added] Added support animations on the `@FirestoreQuery` property wrapper.

# 10.9.0
- [changed] The async `CollectionReference.addDocument(data:)` API now returns
  a discardable result. (#10640)

# 10.4.0
- [fixed] Restore 9.x Codable behavior of encoding `Data` types as an `NSData`
  blob instead of a String.
- [added] Added support for decoding base64-encoded strings when using the
  `blob` `DataEncodingStrategy` for `Codable`s with `Data` types.

# 10.0.0
- [changed] **Breaking Change:** The `DocumentID` constructor from a
  `DocumentReference` is now internal; this does not affect instantiating a
  `@DocumentID` property wrapper for a `DocumentReference`. (#9368)
- [changed] Passing a non-nil value to the `@DocumentID` property wrapper's
  constructor or setter will log a warning and the set value will be ignored.
  (#9368)
- [changed] `Firestore.Encoder` and `Firestore.Decoder` now wraps the shared
  `FirebaseDataEncoder` and `FirebaseDataDecoder` types, which provides new
  customization options for encoding and decoding data to and from Firestore
  into `Codable`s - similar to the options present on `JSONEncoder` and
  `JSONDecoder` from `Foundation`.
- [added] Added a `FirebaseDataEncoder.DateEncodingStrategy` for `Timestamp`s.

# 9.0.0
- [added] **Breaking change:** `FirebaseFirestoreSwift` has exited beta and is
  now generally available for use.

# 8.13.0
- [added] Added support for explicit typing to `DocumentReference.getDocument(as:)`
  and `DocumentSnapshot.data(as:)` to simplify mapping documents (#9101).
- [changed] `DocumentSnapshot.data(as:)` will decode the document to the type
  provided. If you expect that a document might *not exist*, use an optional
  type (e.g. `Book?.self`) to account for this. See
  [the documentation](https://firebase.google.com/docs/firestore/query-data/get-data#custom_objects)
  and this [blog post](https://peterfriese.dev/posts/firestore-codable-the-comprehensive-guide/#mapping-simple-types-using-codable)
  for an in-depth discussion.

# 8.12.1
- [added] Added async wrapper for `CollectionReference.addDocument()` and
  `Firestore.loadBundle()`.

# 8.9.0
- [added] Added `@FirestoreQuery` property wrapper for querying data from a
  Firestore collection.
- [changed] FirebaseFirestoreSwift now requires a minimum iOS version of 11 for
  all distributions.

# 7.7.0
- [feature] Added support for specifying `ServerTimestampBehavior` when
  decoding a `DocumentSnapshot`.

# 0.4
- [feature] Added conditional conformance to the `Hashable` protocol for the
  `@DocumentID`, `@ExplicitNull`, and `@ServerTimestamp` property wrappers.

- [fixed] Removed support for wrapping `NSDate` in a `@ServerTimestamp`
  property wrapper. This never actually worked because `NSDate` is not
  `Codable`.
- [fixed] Fixed the minimum supported Swift version to be 4.1. This was already
  effectively the case because the code made use of Swift 4.1 features without
  documenting this requirement.

# 0.3
- [fixed] Renamed the misspelled `FirestoreDecodingError.fieldNameConfict` to
  `fieldNameConflict` (#5520).

# 0.2
- Initial public release.
