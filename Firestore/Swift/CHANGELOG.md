# Unreleased
- Removed support for wrapping `NSDate` in a `@ServerTimestamp` property
  wrapper. This never actually worked because `NSDate` is not `Codable`.
- Fixed the minimum supported Swift version to be 4.1. This was already
  effectively the case because the code made use of Swift 4.1 features without
  documenting this requirement.

# v0.3
- Renamed the misspelled `FirestoreDecodingError.fieldNameConfict` to
  `fieldNameConflict` (#5520).

# v0.2
- Initial public release.
