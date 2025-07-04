# Jules.md - Context for AI Assisted Development

This document provides essential context and guidelines for Jules, an AI software engineering
agent, to effectively understand, navigate, and make changes within the `firebase-ios-sdk`
repository. It highlights key aspects of the development environment, coding practices, and
architectural patterns.

## Setup Commands

To contribute to or develop within the `firebase-ios-sdk` repository, an understanding of the
following setup is beneficial.

### Prerequisites

1.  **Xcode**: The development environment relies on Xcode 16.2 or above.
2.  **Command-Line Tools**:
    *   `clang-format`: Used for C, C++, and Objective-C code formatting. Version 20 is
        specifically mentioned.
    *   `mint`: Used to install and run Swift command-line tools, including `swiftformat` for
        Swift code styling.
    *   Note: The build environment uses `clang-format` (version 20) and `mint` (for
        `swiftformat`) for code styling. Ensure any generated or modified code adheres to these
        styling requirements.

### Development Workflows

You can develop Firebase libraries using either Swift Package Manager (SPM) or CocoaPods.

#### 1. Swift Package Manager (SPM)

Swift Package Manager (SPM) is a primary development workflow. The project is typically opened
via the `Package.swift` file at the repository root.

*   When working with SPM, specific library schemes (e.g., `FirebaseAuth`, `FirebaseFirestore`)
    are used to build and develop individual modules.
*   For test-related tasks using SPM, be aware of the `./scripts/setup_spm_tests.sh` script, which
    configures Xcode to show schemes for testing individual packages. This script may need to be
    invoked if tests need to be run or modified in an SPM context.
    ```bash
    ./scripts/setup_spm_tests.sh
    ```

#### 2. CocoaPods

CocoaPods (v1.12.0+) is another key development workflow.

*   The `cocoapods-generate` plugin is used to create a development workspace from a `.podspec`
    file.
*   Development workspaces for individual libraries (e.g., `FirebaseStorage`) are generated using
    a command like:
    ```bash
    pod gen FirebaseStorage.podspec --local-sources=./ --auto-open --platforms=ios
    ```
    *   Replace `FirebaseStorage.podspec` with the podspec of the library you intend to develop.
        Podspecs are located in the root directory.
    *   The `--local-sources=./` flag tells CocoaPods to use the local checkout of the SDK.
    *   `--platforms` can be set to `ios`, `macos`, or `tvos`. Note that for Xcode 10.2+,
        multi-platform CocoaPods workspaces might have issues, so generating for a single
        platform is advised by `README.md`.
    *   If the CocoaPods cache is outdated, you might need to run `pod repo update` first.
*   Understanding this command structure is important if tasks involve setting up or modifying a
    CocoaPods-based development environment for a specific module.
*   **Mac Catalyst Development**:
    1.  Run `pod gen` as above for `ios`.
    2.  In the generated project, check the "Mac" box in the host app's "Build Settings" under
        Deployment.
    3.  Configure signing for the host app in "Signing & Capabilities."
    4.  In the "Pods" project, add signing to the host app and unit test targets.
    5.  Alternatively, disable code signing by adding a user-defined setting
        `CODE_SIGNING_REQUIRED` with value `NO` to each relevant target's build settings.

### Code Styling

Code consistency is maintained by `clang-format` (for C-based languages) and `swiftformat` (for
Swift). Any code generated or modified must adhere to these standards.

*   The `./scripts/style.sh` script is used to apply formatting. If a task involves code
    changes, this script (or the underlying tools) should be used to ensure compliance:
    ```bash
    ./scripts/style.sh {path_to_changed_files_or_branch_name}
    ```
    For example:
    ```bash
    ./scripts/style.sh FirebaseStorage/Sources/
    # OR
    ./scripts/style.sh my-feature-branch
    ```
    Running `./scripts/style.sh` with no arguments will format all eligible files in the
    repository.
*   Failures in CI style checks often indicate that code modifications were not formatted
    correctly with these tools.

### Firestore Specific Development

Firestore has a self-contained Xcode project. For details, refer to `Firestore/README.md`.

## Testing

Thorough testing is essential for maintaining the quality and stability of the Firebase SDK.

### General Guidelines

*   **Write Tests**:
    *   When fixing a bug, add a test to prevent regressions.
    *   When adding a new feature, include tests to validate the new or modified APIs.
*   **Tests as Documentation**: Well-written tests can serve as examples of how to use an API.
*   **Code Coverage**: Aim for good code coverage to ensure all critical paths are tested.

### Running Tests

The primary method for running tests is through Xcode, after setting up your development
environment using either Swift Package Manager or CocoaPods.

#### 1. Swift Package Manager (SPM)

1.  **Enable Test Schemes**: If you haven't already, run the script from the repository root:
    ```bash
    ./scripts/setup_spm_tests.sh
    ```
2.  **Run Tests**:
    *   In Xcode, select the scheme corresponding to the library or test suite you want to run
        (e.g., `FirebaseFirestoreTests`).
    *   Choose the target platform (run destination) along with the scheme.
    *   Press `⌘U` or click the "play" arrow in the project navigation bar to run the tests.
    *   Note: `CONTRIBUTING.md` mentions that not all test schemes might be configured to run
        with SPM.

##### Environment Variables in SwiftPM

The following are environment variables to modify sources of code that can help with testing
specific frameworks or dealing with version mismatches.
*   `FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT`: When passed, sets the dependency on the
    https://github.com/google/GoogleAppMeasurement.git package to use the main branch. This is
    done to keep the Firebase package's main branch building when it depends on unreleased changes
    in the GoogleAppMeasurement package's main branch. Use it when you run into version issues.
*   `FIREBASECI_USE_LOCAL_FIRESTORE_ZIP`: When passed, looks for a local
    `FirebaseFirestoreInternal.xcframework` framework at the root of the repo to resolve the
    Firestore target. Used for testing incombination with `scripts/check_firestore_symbols.sh`.
*   `FIREBASE_SOURCE_FIRESTORE`: When passed, builds Firestore's large C++ dependencies (abseil,
     gRPC, BoringSSL) from source rather than, by default, using existing binaries.

To enable an env var within Xcode, quit the current Xcode instance, and open it from the command
line, passing each desired env var with the `--env` argument.
```console
open --env FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT --env FIREBASE_SOURCE_FIRESTORE \
Package.swift
```

To unset the env vars, quit the running Xcode instance.

#### 2. CocoaPods

1.  **Generate Workspace**: After generating a workspace using `pod gen ...` as described in the
    "Setup Commands" section.
2.  **Run Tests**:
    *   Open the generated `.xcworkspace`.
    *   Select the appropriate scheme for the unit tests of the library
        (e.g., `FirebaseStorage-Unit-unit`).
    *   Press `⌘U` or click the "play" arrow to run tests.

### Code Coverage

*   **Enable in Xcode**:
    1.  Go to `Product → Scheme ➞ Edit Scheme...` (or use `⌥⌘U`).
    2.  Select the "Test" action in the sidebar.
    3.  Go to the "Options" tab.
    4.  Check the "Code Coverage" box.
*   **Coverage Report Tool**: The repository includes a tool for generating more detailed
    coverage reports. Refer to its documentation: `scripts/code_coverage_report/README.md`.

### Handling `GoogleService-Info.plist` in Tests

Configuration files like `GoogleService-Info.plist` are necessary for Firebase SDKs to connect to
a backend project. How these are handled in tests varies:

*   **Unit Tests**:
    *   Unit tests should generally not rely on a live backend or a real
        `GoogleService-Info.plist`.
    *   Where configuration is needed (e.g., for `FirebaseApp.configure()`), tests often use
        mock or fake `GoogleService-Info.plist` files with dummy values. These are typically
        included directly in the test target's resources. Be aware of this pattern if tests
        seem to require Firebase app initialization.
*   **Integration Tests & Sample Apps**:
    *   Integration tests and sample apps, which do interact with live backends, require valid
        `GoogleService-Info.plist` files.
    *   In the CI (Continuous Integration) environment, these files are usually provided
        securely (e.g., via environment variables, mounted secrets, or dedicated build steps
        that place the correct plist). As an AI agent, you typically won't manage these CI
        secrets directly.
    *   If integration tests fail due to configuration issues, it might relate to how the CI
        environment provides this plist.
    *   For local execution of sample apps or some integration tests (if specifically requested
        for a task), a valid plist obtained from the Firebase console for a test project would
        be needed, as described in the original `README.md`. However, direct interaction with
        the Firebase console to download plists is outside typical AI agent operations unless
        explicitly guided.

### Product-Specific Testing Notes

*   **Firebase Database**:
    *   Integration tests can run against a local Database Emulator or a production instance.
    *   **Emulator**: Run `./scripts/run_database_emulator.sh start` before executing tests.
    *   **Production**: Provide a valid `GoogleService-Info.plist` (copied to
        `FirebaseDatabase/Tests/Resources/GoogleService-Info.plist`) and ensure security rules
        are public during the test run.
*   **Firebase Storage**:
    *   For integration tests, follow instructions in
        `FirebaseStorage/Tests/Integration/StorageIntegration.swift`.
*   **Push Notifications (General for Messaging, etc.)**:
    *   Cannot be tested on the iOS Simulator; requires a physical device.
    *   Requires specific App ID provisioning in the Apple Developer portal.
    *   Upload your APNs Provider Authentication Key or certificate to the Firebase Console.
    *   Ensure the test device is registered in your Apple Developer account.

## API Surface

Designing and maintaining a consistent and developer-friendly API is critical for the Firebase
SDK. Adherence to established guidelines is important for a good user experience and should be
followed when tasks involve API modifications.

### Guiding Principles for New APIs

The primary reference for API design is `docs/firebase-api-guidelines.md`. Key principles for new
API designs include:

*   **Swift-First**: New APIs should be designed and implemented in Swift. Objective-C APIs
    require strong justification. Generated Swift interfaces for Objective-C APIs should be
    manually refined for Swift idioms if necessary.
*   **Swift Code Samples**: Swift code samples should be prioritized in API proposals and
    documentation.
*   **Async/Await**: New asynchronous APIs should use Swift's `async/await`. Callback-based APIs
    require justification (though callbacks are still appropriate for event handlers).
    ```swift
    // Preferred
    public func fetchData() async throws -> Data { /* ... */ }

    // Pre-Swift Concurrency (No longer preferred for new async APIs)
    public func fetchData(completion: (Data?, Error?) -> Void) { /* ... */ }
    ```
*   **Sendable Types**: New APIs should be `Sendable` where applicable, to allow safe use in
    concurrent contexts (e.g., within a `Task`).
*   **Access Control**:
    *   `public` access level should be used for new Swift APIs rather than `open`.
    *   New Swift classes should generally be `final` to prevent subclassing, unless subclassing
        is an intended design feature.
*   **API Availability**:
    *   The `@available` attribute is used to specify platform and version compatibility (e.g.,
        `@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)`).
    *   The minimum supported versions for SPM are often tied to Analytics/Crashlytics. For other
        APIs, the product's CocoaPods podspec is the reference for versioning in `@available`.
*   **Constants**:
    *   Constants in Swift should be defined within case-less enums (prevents instantiation).
    *   The "k" prefix for Swift constants should be avoided.
    ```swift
    public enum NetworkConstants {
        public static let httpPostMethod = "POST"
    }
    ```
*   **Minimize Optionals**: While Swift's optionals provide type safety for nullability, their
    overuse should be avoided to prevent complicating call sites.
*   **Structs vs. Enums for Extensibility**:
    *   For sets of values that might expand in the future, `structs` with static factory
        methods are preferred over `enums`. Adding a case to a public Swift enum is a breaking
        change.
    *   See `docs/firebase-api-guidelines.md` (links to PRs #13728, #13976) for examples.
*   **Avoid `Any`, `AnyObject`, NS-Types**: `Any`, `AnyObject`, or Objective-C NS-prefixed types
    (like `NSString`, `NSDictionary`) should not be used in public Swift APIs. Swift native
    types (`String`, `Dictionary`) are preferred, and heterogeneous collections should be
    modeled with enums or structs for type safety.
*   **Documentation**: New APIs must be documented using Swift-flavored Markdown. Xcode's `⌥ ⌘ /`
    shortcut can generate documentation block structure.
*   **Naming Conventions**:
    *   Clarity and expressiveness should be prioritized (e.g., `fetchMetadata()` over `fetch()`
        or `getMetadata()`).
    *   Consistency with existing Firebase APIs must be maintained.
    *   Refer to [Swift's API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
*   **Error Handling**:
    *   APIs that can fail should be marked with `throws`.
    *   Public error types conforming to Swift's `Error` protocol should be defined and thrown.
*   **Objective-C (If Necessary)**:
    *   Defining `typedefs` in public Objective-C headers should be avoided as they obscure the
        underlying type in the generated Swift interface. Full types should be used.

### Header Management and Imports

The document `HeadersImports.md` provides detailed guidelines. Key points include:

*   **Public Headers**:
    *   Define the library's public API.
    *   Located in `FirebaseFoo/Sources/Public/FirebaseFoo/`.
    *   Additions are minor version updates; changes/deletions are major.
*   **Public Umbrella Header**:
    *   A single header including the library's full public API
        (e.g., `FirebaseFoo/Sources/Public/FirebaseFoo/FirebaseFoo.h`).
*   **Private Headers**:
    *   Located in `FirebaseFoo/Sources/Private/`.
    *   Available to other libraries within the `firebase-ios-sdk` repo but NOT part of the
        public API.
    *   For CocoaPods, these are included in `source_files`, not `private_header_files`.
*   **Interop Headers**:
    *   Special private headers for defining interfaces between libraries
        (see `Interop/FirebaseComponentSystem.md`).
*   **Private Umbrella Header**:
    *   Includes public API + private APIs for other in-repo libraries. Package manager
        complexities should be localized here.
*   **Library Internal Headers**:
    *   Only used by the enclosing library, located among its source files.
*   **Import Styles**:
    *   **Within the same library**: Use repo-relative paths
        (e.g., `#import "FirebaseFoo/Sources/Internal/MyInternalHeader.h"`).
        *   *Exception*: Public headers importing other public headers from the *same library*
            should use unqualified imports (`#import "AnotherPublicHeaderInFoo.h"`) to avoid
            module collisions.
    *   **Private Headers from other libraries**: Import the private umbrella header
        (e.g., `#import "FirebaseCore/Extension/FirebaseCoreInternal.h"`).
    *   **External Dependencies**:
        ```objectivec
        #if SWIFT_PACKAGE
        @import GTMSessionFetcherCore;
        #else
        #import <GTMSessionFetcher/GTMSessionFetcher.h>
        #endif
        ```

This structure ensures that APIs are well-defined, discoverable, and maintainable across
different build systems and for various Firebase products.

## Best Practices

Adhering to best practices ensures code quality, maintainability, and a positive developer
experience for both contributors and users of the Firebase SDK.

*   **Contribution Guidelines**: The `CONTRIBUTING.md` file contains detailed information on the
    development workflow, pull requests, coding styles, and environment setup, which should be
    adhered to.
*   **Code of Conduct**: All contributions and interactions must align with the
    [Code of Conduct](CODE_OF_CONDUCT.md).
*   **Swift-First Development**: New features and APIs should prioritize Swift, as outlined in the
    API guidelines. Objective-C is used only with strong justification.
*   **Modularity**: The SDK's modular design, with each Firebase product in its own library/pod
    (e.g., Auth, Firestore, Storage), promotes separation of concerns. Changes should generally
    be focused within a product's dedicated directory.
*   **Dependency Management**:
    *   Internal dependencies (between Firebase pods) are managed via version specifications in
        `.podspec` files or `Package.swift`.
    *   External dependencies are also declared here. The impact of adding new external
        dependencies requires careful consideration.
*   **Central FirebaseApp (`FIRApp`)**:
    *   `FirebaseApp` (Swift) / `FIRApp` (Objective-C) is the central class for initializing and
        configuring Firebase.
    *   It provides access to project-level configurations from `GoogleService-Info.plist`.
*   **Component System (`FIRComponent`)**:
    *   An internal component system (`FIRComponent`, `FIRComponentContainer`) is used for
        registering and discovering Firebase services at runtime.
    *   This enables a decoupled architecture. New top-level Firebase pods often require
        registration with this system (see `docs/AddNewPod.md` and `FIRApp.m`).
*   **`GoogleService-Info.plist` (in relation to SDK code)**:
    *   While handling `GoogleService-Info.plist` in tests has specific considerations (see
        "Handling `GoogleService-Info.plist` in Tests"), SDK code itself relies on `FirebaseApp`
        to provide project configurations derived from such a file.
*   **`-ObjC` Linker Flag**:
    *   Awareness of the `-ObjC` "Other Linker Flags" setting is important, as it's necessary
        for applications using Firebase Analytics (and often transitively, other Firebase SDKs)
        to correctly link Objective-C categories.
*   **Changelogs**: `CHANGELOG.md` files (root and product-specific) must be updated with
    meaningful descriptions of changes for any pull request.
*   **Minimize Breaking Changes**: Breaking changes are avoided if possible and require careful
    consideration, typically aligning with major version releases.
*   **Platform Support**: Different levels of support exist for Apple platforms (macOS, Catalyst,
    tvOS, visionOS, watchOS). `@available` and conditional compilation (`#if os(iOS)`) are
    used. visionOS and watchOS are community-supported.
*   **Header Hygiene**: Guidelines in `HeadersImports.md` must be followed strictly for
    compatibility.
*   **Testing**: Comprehensive testing (unit, integration) is a core best practice. Tests must
    cover new code and bug fixes.

Adherence to these practices helps maintain the quality and robustness of the Firebase Apple
SDKs.

## Common Patterns

Recognizing the following common design and implementation patterns, prevalent throughout the
Firebase Apple SDKs, facilitates understanding the existing codebase and developing new features
consistently.

*   **Async/Await and Sendable for Swift**:
    *   New asynchronous Swift code predominantly uses `async/await` for cleaner, more readable
        control flow.
    *   Types involved in concurrent operations are increasingly expected to conform to
        `Sendable` to ensure thread safety, especially with Swift 6's stricter concurrency
        checking.
*   **Case-less Enums for Constants**:
    *   Swift code uses case-less enums to group related constants, preventing instantiation and
        providing a clear namespace.
    ```swift
    public enum StorageConstants {
        public static let maxUploadRetryTime: TimeInterval = 600.0
        public static let defaultChunkSize: Int64 = 256 * 1024
    }
    ```
*   **Structs for Extensible Enum-like Values**:
    *   When a set of predefined values (akin to enum cases) might need to be expanded without
        causing breaking changes, `structs` with static factory methods are often used. This
        avoids the issue where adding a new case to a public `enum` breaks client `switch`
        statements. (See `docs/firebase-api-guidelines.md` for context).
*   **Protocol Buffers (Protobuf / Nanopb)**:
    *   Several modules (e.g., Crashlytics, Firestore, InAppMessaging, Performance, Messaging)
        utilize Protocol Buffers for data serialization.
    *   This involves `.proto` files defining data structures and scripts
        (e.g., `generate_protos.sh`) for compilation into Swift or Objective-C (often Nanopb
        for C/Objective-C). Due to their complexity and impact on build processes, introducing
        Protobufs to new areas of the SDK should be avoided unless that area already heavily
        relies on them or it's a specific requirement for interacting with an existing
        Protobuf-based system.
*   **API Visibility Layers (Public/Private/Internal)**:
    *   A clear distinction is maintained for API visibility:
        *   **Public**: APIs intended for end-users, found in `Sources/Public/` directories.
            Changes here are subject to semantic versioning.
        *   **Private**: APIs intended for use by *other Firebase SDKs within this repository*
            but not for public consumption. Often found in `Sources/Private/` or `Interop/`
            directories.
        *   **Internal/Project**: Code and headers used only within the same library/module.
            These are typically co-located with the module's other source files.
*   **Umbrella Headers**:
    *   **Public Umbrella Header**: Each library typically has a main public header
        (e.g., `FirebaseFoo.h`) that includes all other public headers for that library,
        simplifying imports for Objective-C users.
    *   **Private Umbrella Header**: Some libraries may have an internal or extension umbrella
        header (e.g., `FirebaseCoreInternal.h`) to expose necessary private APIs to other
        Firebase libraries.
*   **Module-Specific Prefixes (Objective-C)**:
    *   Objective-C class names are typically prefixed to avoid collisions (e.g., `FIR` for
        Firebase Core, `FST` for Firestore, `FIRCLS` for Crashlytics). This is less of a concern
        in Swift due to namespacing with module names.
*   **Error Handling Conventions**:
    *   Swift: Adopts the `Error` protocol, with specific error enums/structs per module.
    *   Objective-C: Uses `NSError**` parameters and standard error domains (often
        module-specific).
*   **Delegate Pattern (Objective-C & Swift)**:
    *   Commonly used for callbacks and event notifications, especially in older Objective-C APIs
        or when multiple distinct events need to be communicated.
*   **Completion Handlers (Callbacks)**:
    *   While `async/await` is preferred for new Swift asynchronous operations, completion
        handlers remain prevalent in many existing Objective-C and Swift APIs. These typically
        take `(ResultType?, Error?)` or similar parameters.
*   **Singletons and Shared Instances**:
    *   Many Firebase services offer a shared instance or singleton accessor
        (e.g., `FirebaseApp.app()`, `Firestore.firestore()`, `Auth.auth()`).
*   **Resource Bundles**:
    *   SDKs requiring UI components or other resources (e.g., Firebase In-App Messaging) may
        package them into `.bundle` files.
*   **Use of `dispatch_once` / Lazy Initialization for Singletons (Objective-C)**:
    *   This is a common Objective-C pattern for ensuring singleton instances are initialized
        safely and only once. Swift employs `static let` properties for a similar outcome.

Understanding these patterns is key to navigating the codebase and contributing effectively.

## External Dependencies

The Firebase Apple SDK integrates several external open-source libraries to provide its
functionality. These dependencies are managed as part of the overall SDK build and release
process, primarily through CocoaPods and Swift Package Manager configurations.

Examples of such dependencies include (but are not limited to):
*   gRPC (for Firestore and other components)
*   LevelDB (for Firestore local persistence)
*   nanopb (for Protocol Buffer serialization in C/Objective-C contexts)
*   abseil-cpp (common C++ libraries)
*   GTMSessionFetcher (for networking)

When working on tasks for this repository, **do not introduce new external dependencies** unless
explicitly instructed to do so by the user. Adding and managing dependencies in a large SDK like
this involves careful consideration of binary size, licensing, potential conflicts, and long-term
maintenance. The existing dependencies are curated and managed by the Firebase team. If a task
seems to require functionality that might suggest a new library, discuss alternatives or confirm
the need for a new dependency with the user first.

## Updating agents.md

This document (`agents.md`) is intended as a living guide to assist AI agents (like Jules) in
understanding and contributing to the `firebase-ios-sdk` repository. As the SDK evolves, new
patterns may emerge, best practices might be updated, or setup procedures could change.

**Guideline for Future Tasks:**
If, during the course of completing new tasks, you identify:
*   New common patterns or architectural decisions.
*   Changes to the build, test, or setup process.
*   Updates to API design philosophies or best practices.
*   Any other information that would be beneficial for an AI agent to have context on this
    repository.

Please consider updating this `agents.md` file to reflect those new findings. Keeping this
document current will improve the efficiency and accuracy of future AI-assisted development.
