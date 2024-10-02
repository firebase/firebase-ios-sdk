# 11.1.0
- [fixed] Fix a potential data race in Storage initialization. (#13369)

# 11.0.0
- [fixed] Updated error handling to support both Swift error enum handling and NSError error
  handling. Some of the Swift enums have additional parameters which may be a **breaking** change.
  There are additional NSError's for completeness, but nothing related to NSError handling is
  breaking. (#13071, #10889, #13114)

# 10.24.0
- [fixed] `putFile` and `putFileAsync` now work in app extensions. A background session
   configuration is not used when uploading from an app extension (#12579).

# 10.11.0
- [added] Add progress tracking capability for `putDataAsync`, `putFileAsync`, and
  `writeAsync`. (#10574)

# 10.10.0
- [fixed] Fixed potential memory leak of Storage instances. (#11248)

# 10.7.0
- [added] Provide server errors via the `NSUnderlyingErrorKey`.

# 10.5.0
- [added] Added Storage API to limit upload chunk size. (#10137)
- [fixed] Run `pod update` or `File -> Packages -> Update to latest Packages` to update the `GTMSessionFetcher` dependency to at least version `3.1.0`.
  This fixes an issue where it infinitely retries when FirebaseStorage returns a 500 response.

# 10.3.0
- [fixed] Use dedicated serial queue for Storage uploads and downloads instead of a (concurrent) global queue.
  Fixes regression introduced in 10.0.0. (#10487)

# 10.2.0
- [fixed] Fixed an issue where using Storage with more than one FirebaseApp instance caused non-default Storage instances to deadlock (#10463).
- [fixed] Fixed a race condition where a download size could exceed the value of the `maxSize` parameter. (#10358)

# 10.1.0
- [fixed] Fixed a 10.0.0 regression where metadata passed to `putFile` was not properly initialized. (#10353)
- [fixed] Fixed a 10.0.0 regression handling an empty JSON metadata field from the emulator. (#10370)

# 10.0.0
- [changed] FirebaseStorage is now completely implemented in Swift. Swift-specific API improvements
  are planned for subsequent releases. (#9963)
- [added] New API `open func reference(for url: URL) throws -> StorageReference` equivalent to
  `open func reference(forURL url: String) -> StorageReference` except it throws instead of
  erroring. (#6974)
- [changed] The `FirebaseStorageInternal` CocoaPod has been discontinued.
- [changed] Deprecate the `storageReference` property of `StorageMetadata`. It had never been implemented
  and always returned `nil`.
- [changed] Storage APIs that previously threw an Objective-C exception now generate a Swift
  `fatalError`.
- [changed] Storage now requires at least version 2.1 of its GTMSessionFetcher dependency.
- [changed] The localized description for `unknown` errors is now more descriptive.

# 9.2.0
- [fixed] Importing FirebaseStorage no longer exposes internal FirebaseCore APIs. (#9884)

# 9.0.0
- [changed] The FirebaseStorageSwift library has been removed. All of its APIs are now included
  in the FirebaseStorage library. Please remove references to FirebaseStorageSwift from Podfiles and
  Swift Package Manager configurations. `import FirebaseStorageSwift` should be replaced with
  `import FirebaseStorage`.
- [changed] Backported `StorageReference` async/await APIs to iOS 13, etc. (#9483).
- [changed] The global variable `StorageErrorDomain` is restored for Swift only.

# 8.15.0
- [deprecated] The global variable `FIRStorageErrorDomain` is deprecated and will
  be removed in a future release (#9569).

# 8.5.0
- [fixed] Fixed an issue where Storage could not connect to local emulators using
  http (#8389).
- [added] Added four APIs to augment automatically generated `async/await` APIs. See
  details via Xcode completion and at the
  [source](https://github.com/firebase/firebase-ios-sdk/blob/96d60a6d472b6fed1651d5e7a0e7495230c220ec/FirebaseStorageSwift/Sources/AsyncAwait.swift).
  Feedback appreciated about Firebase and `async/await`. (#8289)

# 8.3.0
- [changed] Removed usage of a deprecated GTMSessionFetcher method (#8294).

# 8.2.0
- [changed] Instances are now cached. Repeated invocations of `Storage.storage()`
  return the same instance and retain the same settings.

# 8.0.0
- [added] Added `FirebaseStorage.useEmulator()`, which allows the Storage SDK to
  connect to the Cloud Storage for Firebase emulator.
- [added] Added abuse reduction features. (#7928)

# 7.4.0
- [fixed] Prevent second `listAll` callback. (#7197)

# 7.3.0
- [fixed] Verify block is still alive before calling it in task callbacks. (#7051)

# 7.1.0
- [fixed] Remove explicit MobileCoreServices library linkage from podspec. (#6850)

# 7.0.0
- [changed] The global variable `FIRStorageVersionString` is deleted.
  `FirebaseVersion()` or `FIRFirebaseVersion()` should be used instead.
- [fixed] Fixed an issue with the List API that prevented listing of locations
  that contain the "+" sign.
- [changed] Renamed `list(withMaxResults:)` to `list(maxResults:)` in the Swift
  API.
- [fixed] Fixed an issue that caused longer than expected timeouts for users
  that specified custom timeouts.

# 3.8.1
- [fixed] Fixed typo in doc comments (#6485).

# 3.8.0
- [changed] Add error for attempt to upload directory (#5750)
- [changed] Functionally neutral source reorganization. (#5851)

# 3.7.0
- [fixed] Fixed a crash when listAll() was called at the root location. (#5772)
- [added] Added a check to FIRStorageUploadTask's `putFile:` to check if the passed in `fileURL` is a directory, and provides a clear error if it is. (#5750)

# 3.6.1
- [fixed] Fix a rare case where a StorageTask would call its completion callbacks more than
  once. (#5245)

# 3.6.0
- [added] Added watchOS support for Firebase Storage. (#4955)

# 3.5.0
- [changed] Reorganized directory structure (#4573).

# 3.4.2
- [fixed] Internal changes to address -Wunused-property-ivar violation (#4281).

# 3.4.1
- [fixed] Fix crash in FIRStorageUploadTask (#3750).

# 3.4.0
- [fixed] Ensure that users don't accidentally invoke `Storage()` instead of `Storage.storage()`.
  If your code calls the constructor of Storage directly, we will throw an assertion failure,
  instead of crashing the process later as the instance is used (#3282).

# 3.3.0
- [added] Added `StorageReference.list()` and `StorageReference.listAll()`, which allows developers to list the files and folders under the given StorageReference.

# 3.2.1
- [fixed] Fixed crash when URL passed to `StorageReference.putFile()` is `nil` (#2852).

# 3.1.0
- [fixed] `StorageReference.putFile()` now correctly propagates error if file to upload does not exist (#2458, #2350).

# 3.0.3
- [changed] Storage operations can now be scheduled and controlled from any thread (#1302, #1388).
- [fixed] Fixed an issue that prevented uploading of files whose names include semicolons.

# 3.0.2
- [changed] Migrate to use FirebaseAuthInterop interfaces to access FirebaseAuth (#1660).

# 3.0.1
- [fixed] Fixed potential `EXC_BAD_ACCESS` violation in the internal logic for processing finished downloads (#1565, #1747).

# 3.0.0
- [removed] Removed `downloadURLs` property on `StorageMetadata`. Use `StorageReference.downloadURL(completion:)` to obtain a current download URL.
- [changed] The `maxOperationRetryTime` timeout now applies to calls to `StorageReference.getMetadata(completion:)` and `StorageReference.updateMetadata(completion:)`. These calls previously used the `maxDownloadRetryTime` and `maxUploadRetryTime` timeouts.

# 2.2.0
- [changed] Deprecated `downloadURLs` property on `StorageMetadata`. Use `StorageReference.downloadURL(completion:)` to obtain a current download URL.

# 2.1.3
- [changed] Addresses CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF warnings that surface in newer versions of Xcode and CocoaPods.

# 2.1.2
- [added] Firebase Storage is now community-supported on tvOS.

# 2.1.1
- [changed] Internal cleanup in the firebase-ios-sdk repository. Functionality of the Storage SDK is not affected.

# 2.1.0
- [added] Added 'md5Hash' to FIRStorageMetadata.

# 2.0.2
- [changed] Custom FIRStorageMetadata can now be cleared by setting individual properties to 'nil'.

# 2.0.1
- [fixed] Fixed crash in FIRStorageDownloadTask that was caused by invoking callbacks that where no longer active.
- [changed] Added 'size' to the NSDictionary representation of FIRStorageMetadata.

# 2.0.0
- [changed] Initial Open Source release.

# 1.0.6

- [fixed] Fixed crash when user-provided callbacks were nil.
- [changed] Improved upload performance under spotty connectivity.

# 1.0.5

- [fixed] Snapshot data is now always from the requested snapshot, rather than
  the most recent snapshot.
- [fixed] Fixed an issue with downloads that were not properly pausing.

# 1.0.4

- [fixed] Fixed an issue causing us to not respect the developer-specified
  timeouts for initial up- and download requests.
- [fixed] Fixed uploading issues with filenames that contain the '+' character.
