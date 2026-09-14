# Headers and Imports

## Introduction

Follow this set of guidelines when creating header files and importing them. The
guidelines are designed to support a wide range of build systems and usage scenarios.

In this document, the term `library` refers to a buildable package. In CocoaPods, it's a CocoaPod.
In Swift Package Manager, it's a library target.

## Header File Types and Locations - For Header File Creators

* *Public Headers* - Headers that define the library's API. They must be located in
  `FirebaseFoo/Sources/Public/FirebaseFoo`. Any additions require a minor version update. Any
  changes or deletions require a major version update.

* *Public Umbrella Header* - A single header that includes the full library's public API located at
  `FirebaseFoo/Sources/Public/FirebaseFoo/FirebaseFoo.h`.

* *Interop Headers* - Special private headers that define cross-library interfaces/protocols
  (e.g., `FIRAnalyticsInterop`, `FIRAuthInterop`, `FIRAppCheckInterop`, `FIRMessagingInterop`).
  These are located in `FirebaseFoo/Interop/Public/FirebaseFooInterop/` or `Interop/FirebaseFoo/Public/FirebaseFooInterop/`
  and exposed via dedicated modular interop targets (e.g. `FirebaseAnalyticsInterop`, `FirebaseAuthInterop`, `FirebaseMessagingInterop`, `FirebaseAppCheckInterop`).
  Details in [Firebase Component System docs](Interop/FirebaseComponentSystem.md).

* *Library Internal Headers* - Headers that are only used by the enclosing library. These headers
  should be located among the source files (e.g. `FirebaseFoo/Sources/`).

* *Library C++ Internal Headers* - In CocoaPods, C++ internal headers should not be included
  in the `source_files` attribute. Instead, they should be defined with the `preserve_paths`
  attribute to avoid filename collisions in the generated Xcode workspace. C++ does not assume
  a global header map, so if filenames are qualified at all, it's generally by directory, not a
  filename prefix like in Objective-C.

## Imports - For Header File Consumers

* *Headers within the Same Library/Target* - Use local or source-relative imports:
  `#import "FIRMyInternalHeader.h"` or `#import "Subdirectory/FIRMyHeader.h"`.
  * For files in subdirectories, prefer qualifying the path relative to the target's source root (e.g., `#import "Controllers/FIRCLSManager.h"` or `#import "Core/FRepo.h"`).
  * In `Package.swift`, avoid adding nested subdirectories to `.headerSearchPath(...)`. Instead, configure `.headerSearchPath(".")` at the target root to allow source-relative imports.
  * *Exception* - Public header imports from other public headers within the *same* library should use unqualified
    imports like `#import "FIRPublicHeader.h"` to avoid module collisions.

* *Cross-Target Imports (Interop, and other Firebase libraries)* - Use modular bracket syntax:
  `#import <ModuleName/Header.h>`.
  Examples:
  * `#import <FirebaseCoreExtension/FirebaseCoreInternal.h>`
  * `#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>`
  * `#import <FirebaseAuthInterop/FIRAuthInterop.h>`
  * `#import <FirebaseMessagingInterop/FIRMessagingInterop.h>`
  * `#import <FirebaseCore/FIRApp.h>`

  **Important:** Any target that consumes headers from another target must explicitly declare a dependency on that target in both `Package.swift` and the respective `.podspec` file.

* *Vendored Third-Party Code and Generated Protos* - Vendored third-party dependencies (e.g., `third_party/libunwind`, `third_party/SocketRocket`) and generated Nanopb proto directories (`Protogen/nanopb`) may retain dedicated `.headerSearchPath(...)` entries in `Package.swift` to preserve upstream code and generated file integrity without modifying third-party sources.

* *Headers from an External Dependency* - Do a module import for Swift Package Manager and an
  umbrella header import otherwise, like:
```objectivec
#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#endif
```

## Additional Background

### Build Systems

We support building with CocoaPods, Swift Package Manager, and Google internal build systems.
By organizing public, and interop headers under `<publicHeadersPath>/<TargetName>/<Header.h>` and
declaring explicit interop targets, both Swift Package Manager and CocoaPods resolve bracket imports
(`<TargetName/Header.h>`) natively without requiring any repo-wide broad header search paths (e.g., `headerSearchPath("../..")`).

### "Internal" versus "Private"

"Internal" and "Private" are often used interchangeably.
- **Internal / Project**: Headers only used within the enclosing module target.
- **Private / Interop**: Headers consumed by other Firebase SDKs in the repository, but not part of the public developer API.
- **Public**: Developer-facing public APIs shipped to end-users.
