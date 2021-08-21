# 8.5.0-beta
- Added four APIs to augment automatically generated `async/await` APIs. See
  details via Xcode completion and at the
  [source](https://github.com/firebase/firebase-ios-sdk/blob/96d60a6d472b6fed1651d5e7a0e7495230c220ec/FirebaseStorageSwift/Sources/AsyncAwait.swift).
  Feedback appreciated about Firebase and `async/await`. (#8289)

# v0.1
- Initial public beta release. Extends the Storage Reference API with the Swift
  Result type for all APIs that return an optional value and optional Error.
  To use, add `pod 'FirebaseStorageSwift'` to the Podfile and
  `import FirebaseStorageSwift` to the source. Please provide feedback about
  these new APIs and suggestions about other potential Swift extensions to
  https://github.com/firebase/firebase-ios-sdk/issues.
