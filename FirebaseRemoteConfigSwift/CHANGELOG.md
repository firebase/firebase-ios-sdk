# 10.17.0
- [deprecated] All of the public API from `FirebaseRemoteConfigSwift` can now
  be accessed through the `FirebaseRemoteConfig` module. Therefore,
  `FirebaseRemoteConfigSwift` has been deprecated, and will be removed in a
  future release. See https://firebase.google.com/docs/ios/swift-migration for
  migration instructions.

# 10.1.0
- [fixed] Fix CocoaPods release did not include the RemoteConfigProperty feature. (#10371)

# 10.0.0
- [added] Added a new dynamic property wrapper API that enables developers to configure UI components to automatically updates when new config are activated. (#10155)

# 9.5.0
- [fixed] Fix Codable implementation to handle arrays and dictionaries from plist defaults. (#9980)

# 9.0.0
- [added] **Breaking change:** `FirebaseRemoteConfigSwift` has exited beta and
  is now generally available for use.

# 8.12.0-beta
- Initial public beta release with Codable support. See example usage in
  https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseRemoteConfigSwift/Tests/Codable.swift
  and
  https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseRemoteConfigSwift/Tests/Value.swift. (#6883)
