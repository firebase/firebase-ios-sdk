# Unreleased
- Removed support for wrapping `NSDate` in a `@ServerTimestamp` property
  wrapper. This never actually worked because `NSDate` is not `Codable`.

# v0.3
- Renamed the misspelled `FirestoreDecodingError.fieldNameConfict` to
  `fieldNameConflict` (#5520).

# v0.2
- Initial public release.
