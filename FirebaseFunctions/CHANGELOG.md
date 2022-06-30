# 9.3.0
- [fixed] Fixed error code generation for HTTP 409 - "already exists". (#9942)

# 9.2.0
- [fixed] Fixed regressions in error code processing introduced in 9.0.0. (#9855)
- [fixed] Importing FirebaseFunctions no longer exposes internal FirebaseCore APIs. (#9884)

# 9.0.0
- [changed] The FirebaseFunctionsSwift library has been removed. All of its APIs are now included
  in the FirebaseFunctions library. Please remove references to FirebaseFunctionsSwift from Podfiles
  and Swift Package Manager configurations. `import FirebaseFunctionsSwift` should be replaced with
  `import FirebaseFunctions`.
- [changed] Backported Callable async/await APIs to iOS 13, etc. (#9483).
- [changed] The global variables `FunctionsErrorDomain` and `FunctionsErrorDetailsKey` are
  restored for Swift only.
- [added] Added a new method `httpsCallable(url:)` to create callables with URLs other than cloudfunctions.net.

# 8.15.0
- [deprecated] The global variables `FIRFunctionsErrorDomain` and `FIRFunctionsErrorDetailsKey` are
  deprecated and will be removed in v9.0.0. (#9569)

# 8.9.0
- [fixed] Add watchOS support for Swift Package Manager (#8864).

# 8.7.0
- [fixed] Add watchOS support (#8499).
- [changed] Don't set the App Check header in the case of App Check error (#8558).

# 8.3.0
- [fixed] Fixed an issue where subclassing Functions was unusable (#8265).

# 8.2.0
- [fixed] Fixed an issue where factory class methods returned a new instance on every invocation, causing emulator settings to not persist between invocations (#7783).

# 8.0.0
- [added] Added abuse reduction features. (#7928)

# 7.7.0
- [fixed] Fixed missing "http://" prefix when using Functions with the emulator. (#7537, #7538)

# 7.2.0
- [added] Made emulator connection API consistent between Auth, Database, Firestore, and Functions (#5916).

# 7.1.0
- [added] Added a constructor to set a custom domain. (#6787)

# 2.9.0
- [changed] Weak dependency on Instance ID replaced by Firebase Messaging. (#6395)

# 2.8.0
- [changed] New public header structure. (#6193)

# 2.7.0
- [changed] Functionally neutral source reorganization. (#5858)

# 2.6.0
- [fixed] Fix internal analyzer issue with error assignment (#4164).

# 2.4.0
- [added] Introduce community support for tvOS and macOS (#2506).

# 2.3.0
- [changed] Change the default timeout for callable functions to 70s (#2329).
- [added] Add a method to change the timeout for a callable (#2329).

# 2.1.0
- [added] Add a constructor to set the region.
- [added] Add a method to set a Cloud Functions emulator origin to use, for testing.

# 2.0.0
- [fixed] Remove FIR prefix on FIRFunctionsErrorCode in Swift.

# 1.0.0
- Initial public release
