# Unreleased
- [feature] Added conditional conformance to the `Hashable` protocol for the
  `@DocumentID`, `@ExplicitNull`, and `@ServerTimestamp` property wrappers.

- [fixed] Removed support for wrapping `NSDate` in a `@ServerTimestamp`
  property wrapper. This never actually worked because `NSDate` is not
  `Codable`.
- [fixed] Fixed the minimum supported Swift version to be 4.1. This was already
  effectively the case because the code made use of Swift 4.1 features without
  documenting this requirement.

# v0.3
- [fixed] Renamed the misspelled `FirestoreDecodingError.fieldNameConfict` to
  `fieldNameConflict` (#5520).

# v0.2
- Initial public release.
