# Firestore Swift Package Manager Target Hierarchy

This document outlines the hierarchy of the Firestore-related targets in the
`Package.swift` manifest. The setup is designed to support two different build
options for Firestore: from source or from a pre-compiled binary. This choice is
controlled by the `FIREBASE_SOURCE_FIRESTORE` environment variable.

## Main Product

The main entry point for integrating Firestore via Swift Package Manager is the
`FirebaseFirestore` library product.

```swift
.library(
  name: "FirebaseFirestore",
  targets: ["FirebaseFirestoreTarget"]
)
```

This product points to a wrapper target, `FirebaseFirestoreTarget`, which then
depends on the appropriate Firestore targets based on the chosen build option.

---

## Wrapper Target

The `FirebaseFirestoreTarget` is a thin wrapper that exists to work around a
limitation in Swift Package Manager where a single target cannot conditionally
depend on different sets of targets (source vs. binary).

By having clients depend on the wrapper, the `Package.swift` can internally
manage the complexity of switching between source and binary builds based on the
`FIREBASE_SOURCE_FIRESTORE` environment variable. This provides a stable entry
point for all clients and avoids pushing conditional logic into their own
package manifests.

---

## 1. Binary-Based Build

When the `FIREBASE_SOURCE_FIRESTORE` environment variable is **not** set (which is
the default), Swift Package Manager will use pre-compiled binaries for Firestore
and its heavy dependencies.

### Dependency Hierarchy

The dependency tree for a binary-based build is as follows:

```
FirebaseFirestore (Library Product)
└── FirebaseFirestoreTarget (Wrapper Target)
    └── FirebaseFirestore (Swift Target)
        ├── FirebaseAppCheckInterop
        ├── FirebaseCore
        ├── FirebaseCoreExtension
        ├── FirebaseSharedSwift
        ├── leveldb
        ├── nanopb
        ├── abseil (binary) (from https://github.com/google/abseil-cpp-binary.git)
        ├── gRPC-C++ (binary) (from https://github.com/google/grpc-binary.git)
        └── FirebaseFirestoreInternalWrapper (Wrapper Target)
            └── FirebaseFirestoreInternal (Binary Target)
```

### Target Breakdown

*   **`FirebaseFirestoreTarget`**: A wrapper target, same as in the source-based
    build.
*   **`FirebaseFirestore`**: The Swift target containing the public API. In this
    configuration, it depends on the binary versions of abseil and gRPC, as
    well as the `FirebaseFirestoreInternalWrapper`.
*   **`FirebaseFirestoreInternalWrapper`**: A thin wrapper target that exists to
    expose the headers from the underlying binary target.
*   **`FirebaseFirestoreInternal`**: This is a `binaryTarget` that downloads and
    links the pre-compiled `FirebaseFirestoreInternal.xcframework`. This
    framework contains the compiled C++ core of Firestore.

---

## 2. Source-Based Build

When the `FIREBASE_SOURCE_FIRESTORE` environment variable is set, Firestore and
its dependencies (like abseil and gRPC) are compiled from source.

### Dependency Hierarchy

The dependency tree for a source-based build looks like this:

```
FirebaseFirestore (Library Product)
└── FirebaseFirestoreTarget (Wrapper Target)
    └── FirebaseFirestore (Swift Target)
        ├── FirebaseCore
        ├── FirebaseCoreExtension
        ├── FirebaseSharedSwift
        └── FirebaseFirestoreInternalWrapper (C++ Target)
            ├── FirebaseAppCheckInterop
            ├── FirebaseCore
            ├── leveldb
            ├── nanopb
            ├── abseil (source) (from https://github.com/firebase/abseil-cpp-SwiftPM.git)
            ├── gRPC-cpp (source) (from https://github.com/grpc/grpc-ios.git)
            └── BoringSSL (source) (from https://github.com/firebase/boringSSL-SwiftPM.git)
```

### Target Breakdown

*   **`FirebaseFirestoreTarget`**: A wrapper target that conditionally depends on
    the main `FirebaseFirestore` target.
*   **`FirebaseFirestore`**: The main Swift target containing the public Swift
    API for Firestore. It acts as a bridge to the underlying C++
    implementation.
*   **`FirebaseFirestoreInternalWrapper`**: This target compiles the core C++
    source code of Firestore. It depends on other low-level libraries and C++
    dependencies, which are also built from source.

---

## 3. Local Binary Build (CI Only)

A third, less common build option is available for CI environments. When the
`FIREBASECI_USE_LOCAL_FIRESTORE_ZIP` environment variable is set, the build
system will use a local `FirebaseFirestoreInternal.xcframework` instead of
downloading the pre-compiled binary. This option assumes the xcframework is
located at the root of the repository.

This option is primarily used by internal scripts, such as
`scripts/check_firestore_symbols.sh`, to perform validation against a locally
built version of the Firestore binary. It is not intended for general consumer
use.

---

## 4. Test Targets

The testing infrastructure for Firestore in Swift Package Manager is designed to
be independent of the build choice (source vs. binary).

*   **`FirebaseFirestoreTestingSupport`**: This is a library target, not a test
    target. It provides public testing utilities that consumers can use to write
    unit tests for their Firestore-dependent code. It has a dependency on
    `FirebaseFirestoreTarget`, which means it will link against whichever
    version of Firestore (source or binary) is being used in the build.

*   **`FirestoreTestingSupportTests`**: This is a test target that contains the
    unit tests for the `FirebaseFirestoreTestingSupport` library itself. Its
    purpose is to validate the testing utilities.

Because both of these targets depend on the `FirebaseFirestoreTarget` wrapper,
they seamlessly adapt to either the source-based or binary-based build path
without any conditional logic.

