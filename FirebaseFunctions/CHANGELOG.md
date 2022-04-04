# v8.15.0
- [deprecated] The global variables `FIRFunctionsErrorDomain` and `FIRFunctionsErrorDetailsKey` are
  deprecated and will be removed in v9.0.0. (#9569)

# v8.9.0
- [fixed] Add watchOS support for Swift Package Manager (#8864).

# v8.7.0
- [fixed] Add watchOS support (#8499).
- [changed] Don't set the App Check header in the case of App Check error (#8558).

# v8.3.0
- [fixed] Fixed an issue where subclassing Functions was unusable (#8265).

# v8.2.0
- [fixed] Fixed an issue where factory class methods returned a new instance on every invocation, causing emulator settings to not persist between invocations (#7783).

# v8.0.0
- [added] Added abuse reduction features. (#7928)

# v7.7.0
- [fixed] Fixed missing "http://" prefix when using Functions with the emulator. (#7537, #7538)

# v7.2.0
- [added] Made emulator connection API consistent between Auth, Database, Firestore, and Functions (#5916).

# v7.1.0
- [added] Added a constructor to set a custom domain. (#6787)

# v2.9.0
- [changed] Weak dependency on Instance ID replaced by Firebase Messaging. (#6395)

# v2.8.0
- [changed] New public header structure. (#6193)

# v2.7.0
- [changed] Functionally neutral source reorganization. (#5858)

# v2.6.0
- [fixed] Fix internal analyzer issue with error assignment (#4164).

# v2.4.0
- [added] Introduce community support for tvOS and macOS (#2506).

# v2.3.0
- [changed] Change the default timeout for callable functions to 70s (#2329).
- [added] Add a method to change the timeout for a callable (#2329).

# v2.1.0
- [added] Add a constructor to set the region.
- [added] Add a method to set a Cloud Functions emulator origin to use, for testing.

# v2.0.0
- [fixed] Remove FIR prefix on FIRFunctionsErrorCode in Swift.

# v1.0.0
- Initial public release
