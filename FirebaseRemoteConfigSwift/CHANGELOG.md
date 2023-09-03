# Unreleased
- [changed] `FirebaseRemoteConfigSwift` has been merged into
  `FirebaseRemoteConfig`, and will be deprecated in a future release. Depending
  on `FirebaseRemoteConfigSwift` is therefore no longer required to access
  Firebase Remote Config's Swift-only APIs. To migrate ahead of the
  deprecation, remove your project's dependency on `FirebaseRemoteConfigSwift`
  and any imports of `FirebaseRemoteConfigSwift` within your source code.
  From now on, depending on (and importing) `FirebaseRemoteConfig` should be
  sufficient to access Firebase Remote Config's Swift-only APIs.

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
