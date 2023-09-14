# Unreleased
- [deprecated] `FirebaseDatabaseSwift` has been deprecated, and will be
  removed in a future release. All of the public API from
  `FirebaseDatabaseSwift` can now be accessed through the
  `FirebaseDatabase` module. To migrate, delete imports of
  `FirebaseDatabaseSwift` and remove the module as a dependency to your
  project. If applicable, any APIs namespaced with
  `FirebaseDatabaseSwift` can now be namespaced with
  `FirebaseDatabase`. Additionally, if applicable,
  `@testable import FirebaseDatabaseSwift` should be replaced with
  `@testable import FirebaseDatabase`.
# 9.0.0
- [added] **Breaking change:** `FirebaseDatabaseSwift` has exited beta and is
  now generally available for use.

# 8.11.0-beta
- Refactored Codable implementation to share common source with Firebase Functions. This should be
  generally transparent with the exception of custom decoder use cases which may need to be updated. (#8854)

# 8.1.0-beta
- Initial public beta release for Swift Package Manager.

# 8.0.0-beta
- Initial public beta release for CocoaPods.
