# Firestore Swift Package Manager Target Hierarchy

This document outlines the hierarchy of the Firestore-related targets in the
`Package.swift` manifest. The setup is designed to support three different
build options for Firestore: from a pre-compiled binary (the default), from
source (via the `FIREBASE_SOURCE_FIRESTORE` environment variable), or from a
local binary for CI purposes (via the `FIREBASECI_USE_LOCAL_FIRESTORE_ZIP`
environment variable).

---

## 1. Binary-based build (Default)

When the `FIREBASE_SOURCE_FIRESTORE` environment variable is **not** set, SPM
will use pre-compiled binaries for Firestore and its heavy dependencies. This
is the default and recommended approach for most users.

### Dependency hierarchy

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
        ├── gRPC-C++ (binary) (from https://github.com/google/grpc-binary.git, contains BoringSSL-GRPC target)
        └── FirebaseFirestoreInternalWrapper (Wrapper Target)
            └── FirebaseFirestoreInternal (Binary Target)
```

### Target breakdown

*   **`FirebaseFirestore`**: The Swift target containing the public API. In this
    configuration, it depends on the binary versions of abseil and gRPC, as
    well as the `FirebaseFirestoreInternalWrapper`.
*   **`FirebaseFirestoreInternalWrapper`**: A thin wrapper target that exists to
    expose the headers from the underlying binary target.
*   **`FirebaseFirestoreInternal`**: This is a `binaryTarget` that downloads and
    links the pre-compiled `FirebaseFirestoreInternal.xcframework`. This
    framework contains the compiled C++ core of Firestore.

---

## 2. Source-based build

When the `FIREBASE_SOURCE_FIRESTORE` environment variable is set, Firestore and
its dependencies (like abseil and gRPC) are compiled from source.

### How to build Firestore from source

To build Firestore from source, set the `FIREBASE_SOURCE_FIRESTORE` environment
variable before building the project.

#### Building with Xcode

A direct method for building within Xcode is to pass the environment variable
when opening it from the command line. This approach scopes the variable to the
Xcode instance. To enable an env var within Xcode, first quit any running Xcode
instance, and then open the project from the command line:

```console
open --env FIREBASE_SOURCE_FIRESTORE Package.swift
```

To unset the env var, quit the running Xcode instance. If you need to pass
multiple variables, repeat the `--env` argument for each:
```console
open --env FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT \
--env FIREBASE_SOURCE_FIRESTORE Package.swift
```

#### Command-line builds

For command-line builds using `xcodebuild` or `swift build`, the recommended
approach is to prefix the build command with the environment variable. This sets
the variable only for that specific command, avoiding unintended side effects.

```bash
FIREBASE_SOURCE_FIRESTORE=1 xcodebuild -scheme FirebaseFirestore \
-destination 'generic/platform=iOS'
```

Alternatively, if you plan to run multiple commands that require the variable
to be set, you can `export` it. This will apply the variable to all subsequent
commands in that terminal session.

```bash
export FIREBASE_SOURCE_FIRESTORE=1
xcodebuild -scheme FirebaseFirestore -destination 'generic/platform=iOS'
# Any other commands here will also have the variable set
```

Once the project is built with the variable set, SPM will clone and build
Firestore and its C++ dependencies (like abseil and gRPC) from source.

### Dependency hierarchy

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
            └── gRPC-cpp (source) (from https://github.com/grpc/grpc-ios.git)
                └── BoringSSL (source) (from https://github.com/firebase/boringSSL-SwiftPM.git)
```

### Target breakdown

*   **`FirebaseFirestore`**: The main Swift target containing the public Swift
    API for Firestore. It acts as a bridge to the underlying C++
    implementation.
*   **`FirebaseFirestoreInternalWrapper`**: This target compiles the core C++
    source code of Firestore. It depends on other low-level libraries and C++
    dependencies, which are also built from source.

---

## 3. Local binary build (CI only)

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

## Core target explanations

### `FirebaseFirestore` (Library product)

The main entry point for integrating Firestore via SPM is the
`FirebaseFirestore` library product.

```swift
.library(
  name: "FirebaseFirestore",
  targets: ["FirebaseFirestoreTarget"])
```

This product points to a wrapper target, `FirebaseFirestoreTarget`, which then
depends on the appropriate Firestore targets based on the chosen build option.

### `FirebaseFirestoreTarget` (Wrapper target)

The `FirebaseFirestoreTarget` is a thin wrapper that exists to work around a
limitation in SPM where a single target cannot conditionally depend on
different sets of targets (source vs. binary).

By having clients depend on the wrapper, the `Package.swift` can internally
manage the complexity of switching between source and binary builds. This
provides a stable entry point for all clients and avoids pushing conditional
logic into their own package manifests.

---

## Test targets

The testing infrastructure for Firestore in SPM is designed to be independent
of the build choice (source vs. binary).

*   **`FirebaseFirestoreTestingSupport`**: This is a library target, not a test
    target. It provides public testing utilities that consumers can use to
    write unit tests for their Firestore-dependent code. It has a dependency on
    `FirebaseFirestoreTarget`, which means it will link against whichever
    version of Firestore (source or binary) is being used in the build.

*   **`FirestoreTestingSupportTests`**: This is a test target that contains the
    unit tests for the `FirebaseFirestoreTestingSupport` library itself. Its
    purpose is to validate the testing utilities.

Because both of these targets depend on the `FirebaseFirestoreTarget` wrapper,
they seamlessly adapt to either the source-based or binary-based build path
without any conditional logic.
