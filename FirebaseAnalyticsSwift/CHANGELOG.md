# 10.17.0
- [deprecated] All of the public API from `FirebaseAnalyticsSwift` can now
  be accessed through the `FirebaseAnalytics` module. Therefore,
  `FirebaseAnalyticsSwift` has been deprecated, and will be removed in a
  future release. See https://firebase.google.com/docs/ios/swift-migration for
  migration instructions.

# 9.0.0
- [added] **Breaking change:** `FirebaseAnalyticsSwift` has exited beta and is
  now generally available for use.

# 7.9.0-beta
- Initial public beta release. Introduces new SwiftUI friendly APIs for
  screen tracking. To use, add `pod 'FirebaseAnalyticsSwift', '~> 7.9-beta'` to the Podfile or
  add the `FirebaseAnalyticsSwift-Beta` framework in Swift Package Manager, then
  and `import FirebaseAnalyticsSwift` to the source. Please provide feedback about
  these new APIs and suggestions about other potential Swift extensions to
  https://github.com/firebase/firebase-ios-sdk/issues.
