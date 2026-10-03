# Architecture and phased plan: Portable Firebase Core and AI Logic on Linux

## 1. Overview and goals

This document specifies a phased, pure-Swift port of core Firebase
infrastructure to enable building and testing `FirebaseAILogic` on Linux (and
other non-Darwin platforms such as Android, Windows, or WASI) while coexisting
cleanly with the existing Objective-C implementation on Apple platforms.

### Key objectives

- **Compile on Linux without Darwin frameworks**: Remove dependencies on the
  Objective-C runtime, CocoaPods, `Security.framework`, `DeviceCheck`, `os.log`,
  and dynamic Objective-C component discovery when building in portable mode.
- **Strict concurrency (Swift 6)**: Build with `-strict-concurrency=complete`
  and **zero** `@unchecked Sendable` annotations in portable code.
- **Preserve the Darwin public API contract**: Match existing Darwin Swift API
  signatures (`FirebaseApp.configure()`, `FirebaseOptions`,
  `Auth.auth().signIn(withEmail:password:)`,
  `AppCheck.setAppCheckProviderFactory(_:)`) so client code, unit tests, and the
  existing `FirebaseAITestApp` compile without source changes across Apple and
  portable builds.
- **Minimize conditional compilation in `FirebaseAILogic`**: Retain target names
  (`FirebaseCore`, `FirebaseCoreExtension`, `FirebaseAuthInterop`,
  `FirebaseAppCheckInterop`, `FirebaseAuth`, `FirebaseAppCheck`) and provide a
  lightweight `Mutex`-backed `FirebaseComponentContainer` / `ComponentType` so
  `FirebaseAILogic` requires minimal `#if` branching.
- **Validate locally on macOS before Linux**: Support activating portable mode
  on macOS via the `FIREBASE_PORTABLE` environment variable for rapid local
  iteration in `swift test`, Xcode (`FirebaseAITestApp`), and Static Linux SDK
  cross-compilation.

---

## 2. Architectural principles

1. **Coexistence via `<Module>/Portable` directories**:
   - Existing Darwin Objective-C and Swift sources remain untouched in their
     current paths (e.g., `FirebaseCore/Sources`, `FirebaseCore/Extension`).
   - Portable pure-Swift implementations and tests live under
     `<Module>/Portable/Sources` and `<Module>/Portable/Tests` (mirroring the
     existing `FirebaseCore/Internal/Sources` and `FirebaseCore/Internal/Tests`
     pattern).
2. **Manifest-level portable mode (`isPortableBuild`) & Dependabot compatibility**:
   - Because `Package.swift` executes on the host OS (which is macOS when
     cross-compiling with `--swift-sdk` or testing locally), portable mode
     activates automatically on non-Darwin hosts (`#if !canImport(Darwin)`)
     **unless** `DEPENDABOT` is set in the environment, or on Darwin hosts when
     `Context.environment["FIREBASE_PORTABLE"] != nil`.
   - When Dependabot runs on Linux CI to resolve dependencies for Apple-platform
     apps, it sets the `DEPENDABOT` environment variable. Checking
     `Context.environment["DEPENDABOT"] == nil` ensures Dependabot still sees
     the full Darwin manifest (including `FirebaseCrashlytics`,
     `FirebaseAnalytics`, etc.; see
     [PR #16579](https://github.com/firebase/firebase-ios-sdk/pull/16579)).
   - When `isPortableBuild` is `true`, `Package.swift` exposes only the portable
     product/target graph and omits Apple-only external package dependencies
     (`GoogleAppMeasurement`, `GoogleUtilities`, `gtm-session-fetcher`,
     `ocmock`, `grpc-binary`, `abseil`, `leveldb`, `app-check`, etc.).
3. **Unidirectional dependency flow with explicit container registration**:
   - Traditional `firebase-ios-sdk` discovers downstream components at runtime
     by iterating Objective-C classes conforming to `FIRLibrary`.
   - In portable builds, dynamic Objective-C discovery is replaced by a
     thread-safe `FirebaseComponentContainer` (`app.container`) backed by
     `FirebaseCoreInternal`'s `UnfairLock`.
   - Dependencies flow strictly in one direction: `FirebaseAILogic` depends on
     `FirebaseCore`, `FirebaseCoreExtension`, `FirebaseAuthInterop`, and
     `FirebaseAppCheckInterop`. When `FirebaseAuth` or `FirebaseAppCheck` is
     configured by the application or test suite, it registers its factory or
     instance into `FirebaseComponentContainer`.
4. **Synchronization via `FirebaseCoreInternal.UnfairLock` (`Mutex` on Linux, `os_unfair_lock` on Darwin)**:
   - On non-Darwin platforms (`#if !canImport(Darwin)`), `UnfairLock<Value>` in
     `FirebaseCoreInternal` wraps Swift 6 `Synchronization.Mutex<Value>` with
     **zero** `@unchecked Sendable` annotations in the entire Linux build.
   - On Darwin (`#if canImport(Darwin)`), `UnfairLock<Value>` uses its existing
     `os_unfair_lock` implementation, keeping `@unchecked Sendable` isolated to
     that single lock primitive while supporting **iOS 15+ and macOS 11+**
     without `@available(iOS 18.0, macOS 15.0, *)` propagation across
     `FirebaseCore`, `FirebaseAILogic`, or `FirebaseAITestApp`.
   - Reference types (`FirebaseApp`, `FirebaseOptions`, `FirebaseConfiguration`,
     `FirebaseComponentContainer`, `Auth`, `AppCheck`) conform to `Sendable`
     natively by being marked `final class` with immutable (`let`) stored
     properties wrapping `UnfairLock`.
5. **Experimental DocC convention for portable symbols**:
   - Every public and package-visible declaration in the portable Swift targets
     must include the experimental prefix and warning callout in its DocC
     comment:
     ```swift
     /// **[Experimental]** <summary line like usual>
     ///
     /// > Warning: This portable implementation is for development and testing
     /// > use only. The Firebase Apple SDK is only officially supported on Apple
     /// > platforms.
     ///
     /// <rest of docs>
     ```
6. **Swift 6.2.3 (Xcode 26.2) baseline vs. Swift 6.4 (Xcode 27)**:
   - We keep the existing `swift-tools-version:6.2.1` and `#if compiler(<6.2.3)`
     minimum in `Package.swift` so `FirebaseAITestApp` and `swift test` can be
     validated on Xcode 26.2 today.
   - All core language features needed for Phases 1–4 (`Synchronization.Mutex`
     on Linux, `package` access level, `internal import` / `private import`,
     strict concurrency `sending` / `borrowing`) are available in Swift 6.2.3.
7. **Strict per-framework unit testing gate**:
   - Even though the portable implementation is experimental, **each portable
     framework must be thoroughly unit tested (using Swift Testing,
     `import Testing`) and pass all unit tests before moving on to the next
     phase**.
   - Every phase requires both:
     1. Passing unit tests on macOS under portable mode
        (`FIREBASE_PORTABLE=1 swift test --filter <Target>Tests`), and
     2. Clean compilation (and test execution where supported) against the
        Swift Static Linux SDK (`--swift-sdk`).

> [!NOTE]
> **What becomes easier if we bump to Swift 6.4 / Xcode 27**:
>
> - **`FoundationNetworking` & `URLSession.AsyncBytes` on Linux**: Newer Swift
>   6.3 / 6.4 toolchains and `swift-foundation` releases significantly improve
>   `URLSession.shared.bytes(for:)` streaming parity and Static Linux SDK
>   (`--swift-sdk`) bundling compared to 6.2.3.
> - **Unconditional `GeminiLanguageModel` compilation**: Currently gated behind
>   `#if compiler(>=6.4) && canImport(FoundationModels)` in `Package.swift`.
>   Once Xcode 27 (Swift 6.4) is the baseline, the `#if compiler(>=6.4)` guard
>   can be removed across `Package.swift` and `FirebaseAI`.

---

## 3. Phased implementation roadmap

> [!IMPORTANT]
> **Phase gate requirement**: Do not advance from Phase $N$ to Phase $N+1$
> until all unit tests for the frameworks introduced in Phase $N$ are written,
> passing under `FIREBASE_PORTABLE=1 swift test`, and compiling cleanly for
> Linux.

| Phase | Scope | Key deliverables | Required unit test gate before next phase |
| :--- | :--- | :--- | :--- |
| **Phase 1** | `FirebaseCore`, `FirebaseCoreInternal`, & `FirebaseCoreExtension` | `Package.swift` portable toggle, `UnfairLock` (`Mutex` on Linux), `FirebaseApp`, `FirebaseOptions`, `FirebaseConfiguration`, `FirebaseLogger`, `ComponentType` | `FirebaseCorePortableTests` passing on macOS & Linux cross-build |
| **Phase 2** | `FirebaseAuthInterop` & `FirebaseAppCheckInterop` | Pure-Swift `AuthInterop`, `AppCheckInterop`, and `FIRAppCheckTokenResultInterop` protocols | `FirebaseAuthInteropPortableTests` & `FirebaseAppCheckInteropPortableTests` passing |
| **Phase 3** | Portable `FirebaseAuth` & `FirebaseAppCheck` | Lightweight REST implementations of `Auth` and `AppCheck` (`AppCheckDebugProvider`) + container registration | `FirebaseAuthPortableTests` & `FirebaseAppCheckPortableTests` (mocked `URLProtocol`) passing |
| **Phase 4** | `FirebaseAILogic` Linux port & unit tests | `FoundationNetworking` imports, `os.log` / lock guards in `FirebaseAI`, portable `FirebaseAILogicUnit` target | Full `FirebaseAILogicUnit` test suite passing in portable mode & Linux |
| **Phase 5** | End-to-end integration testing | Validate `FirebaseAITestApp` with `FIREBASE_PORTABLE=1` on macOS and SwiftPM integration tests on Linux | Live backend integration tests with Auth + App Check on macOS & Linux |

---

## 4. Phase 1: Portable `FirebaseCore` and `FirebaseCoreExtension`

> [!IMPORTANT]
> Phase 1 is the foundation. It establishes the `Package.swift` portable build
> mode, updates `UnfairLock` in `FirebaseCoreInternal` to use `Mutex` on
> non-Darwin platforms, implements `FirebaseCore` and `FirebaseCoreExtension` in
> pure Swift 6, and verifies compilation and unit tests on both macOS
> (`FIREBASE_PORTABLE=1`) and Linux (`--swift-sdk`).

### 4.1 `Package.swift` portable mode configuration

`Package.swift` keeps the existing `platforms` array unchanged
(`[.iOS(.v15), .macCatalyst(.v15), .macOS(.v11), .tvOS(.v15), .watchOS(.v8)]`)
and defines `isPortableBuild` so portable mode activates on non-Darwin hosts
(unless `DEPENDABOT` is set) or on Darwin hosts when `FIREBASE_PORTABLE` is set:

```swift
#if canImport(Darwin)
  let isPortableBuild = Context.environment["FIREBASE_PORTABLE"] != nil
#else
  let isPortableBuild =
    Context.environment["FIREBASE_PORTABLE"] != nil
    || Context.environment["DEPENDABOT"] == nil
#endif
```

In portable mode, `Package.swift` defines:

- **Products**:
  - `FirebaseCore` (target: `FirebaseCore`)
  - (Subsequent phases add `FirebaseAuthInterop`, `FirebaseAppCheckInterop`,
    `FirebaseAuth`, `FirebaseAppCheck`, and `FirebaseAILogic`.)
- **Phase 1 targets**:
  - `FirebaseCoreInternal` (`path: "FirebaseCore/Internal/Sources/Utilities"`,
    exposing `UnfairLock` backed by `os_unfair_lock` on Darwin iOS 15+ and
    `Synchronization.Mutex` on non-Darwin)
  - `FirebaseCore` (`path: "FirebaseCore/Portable/Sources"`, depends on
    `FirebaseCoreInternal`)
  - `FirebaseCoreExtension` (`path: "FirebaseCore/Extension/Portable/Sources"`,
    depends on `FirebaseCore` and `FirebaseCoreInternal`)
  - `FirebaseCorePortableTests` (`path: "FirebaseCore/Portable/Tests"`, depends
    on `FirebaseCore` and `FirebaseCoreExtension`)

### 4.2 Options and plist discovery (`FirebaseOptions.swift`)

On Darwin (`FIROptions.h`), `FirebaseOptions` is a reference type (`class`)
whose properties (`apiKey`, `projectID`, etc.) are mutated after initialization
(e.g., `let options = FirebaseOptions(googleAppID: ..., gcmSenderID: ...);`
`options.apiKey = ...`), and `apiKey` is typed as `String?`.

To preserve 100% source compatibility with `FirebaseAI.swift` and existing tests
while maintaining strict `Sendable` conformance on iOS 15+ and Linux, portable
`FirebaseOptions` is implemented as a `final class: Sendable` backed by
`UnfairLock<Storage>`.

Linux executables run outside of `.app` bundles, so `FirebaseOptions.defaultOptions()`
searches in order:

1. `GOOGLE_SERVICE_INFO_PATH` environment variable.
2. `Bundle.main` resource lookup (`GoogleService-Info.plist`).
3. Current working directory (`./GoogleService-Info.plist`).

```swift
import Foundation
private import FirebaseCoreInternal

/// **[Experimental]** Configuration options for a `FirebaseApp`.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class FirebaseOptions: Sendable {
  package struct Storage: Sendable, Equatable, Codable {
    var apiKey: String?
    var bundleID: String
    var clientID: String?
    var gcmSenderID: String
    var projectID: String?
    var googleAppID: String
    var databaseURL: String?
    var storageBucket: String?
    var appGroupID: String?
  }

  private let storage: UnfairLock<Storage>

  public var apiKey: String? {
    get { storage.withLock { $0.apiKey } }
    set { storage.withLock { $0.apiKey = newValue } }
  }

  public var bundleID: String {
    get { storage.withLock { $0.bundleID } }
    set { storage.withLock { $0.bundleID = newValue } }
  }

  public var clientID: String? {
    get { storage.withLock { $0.clientID } }
    set { storage.withLock { $0.clientID = newValue } }
  }

  public var gcmSenderID: String {
    get { storage.withLock { $0.gcmSenderID } }
    set { storage.withLock { $0.gcmSenderID = newValue } }
  }

  public var projectID: String? {
    get { storage.withLock { $0.projectID } }
    set { storage.withLock { $0.projectID = newValue } }
  }

  public var googleAppID: String {
    get { storage.withLock { $0.googleAppID } }
    set { storage.withLock { $0.googleAppID = newValue } }
  }

  public var databaseURL: String? {
    get { storage.withLock { $0.databaseURL } }
    set { storage.withLock { $0.databaseURL = newValue } }
  }

  public var storageBucket: String? {
    get { storage.withLock { $0.storageBucket } }
    set { storage.withLock { $0.storageBucket = newValue } }
  }

  public var appGroupID: String? {
    get { storage.withLock { $0.appGroupID } }
    set { storage.withLock { $0.appGroupID = newValue } }
  }

  package init(storage: Storage) {
    self.storage = UnfairLock(storage)
  }

  package func snapshot() -> FirebaseOptions {
    FirebaseOptions(storage: storage.withLock { $0 })
  }

  public init(googleAppID: String, gcmSenderID: String) {
    self.storage = UnfairLock(
      Storage(
        apiKey: nil,
        bundleID: Bundle.main.bundleIdentifier ?? "",
        clientID: nil,
        gcmSenderID: gcmSenderID,
        projectID: nil,
        googleAppID: googleAppID,
        databaseURL: nil,
        storageBucket: nil,
        appGroupID: nil
      )
    )
  }

  public convenience init(
    apiKey: String,
    googleAppID: String,
    projectID: String? = nil,
    gcmSenderID: String = "",
    bundleID: String? = nil,
    clientID: String? = nil,
    databaseURL: String? = nil,
    storageBucket: String? = nil,
    appGroupID: String? = nil
  ) {
    self.init(googleAppID: googleAppID, gcmSenderID: gcmSenderID)
    self.apiKey = apiKey
    self.projectID = projectID
    if let bundleID {
      self.bundleID = bundleID
    }
    self.clientID = clientID
    self.databaseURL = databaseURL
    self.storageBucket = storageBucket
    self.appGroupID = appGroupID
  }

  public convenience init?(contentsOfFile plistPath: String) {
    let url = URL(fileURLWithPath: plistPath)
    guard let loaded = Self.loadStorage(from: url) else {
      return nil
    }
    self.init(storage: loaded)
  }

  public static func defaultOptions() -> FirebaseOptions? {
    // 1. Environment variable override.
    if let envPath = ProcessInfo.processInfo.environment["GOOGLE_SERVICE_INFO_PATH"],
      !envPath.isEmpty,
      let storage = loadStorage(from: URL(fileURLWithPath: envPath))
    {
      return FirebaseOptions(storage: storage)
    }

    // 2. Bundle.main resource location.
    if let bundleURL = Bundle.main.url(
      forResource: "GoogleService-Info",
      withExtension: "plist"
    ),
      let storage = loadStorage(from: bundleURL)
    {
      return FirebaseOptions(storage: storage)
    }

    // 3. Current working directory fallback.
    let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("GoogleService-Info.plist")
    if FileManager.default.fileExists(atPath: cwdURL.path),
      let storage = loadStorage(from: cwdURL)
    {
      return FirebaseOptions(storage: storage)
    }

    return nil
  }

  private static func loadStorage(from url: URL) -> Storage? {
    guard let data = try? Data(contentsOf: url),
      let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any],
      let googleAppID = plist["GOOGLE_APP_ID"] as? String
    else {
      return nil
    }

    return Storage(
      apiKey: plist["API_KEY"] as? String,
      bundleID: (plist["BUNDLE_ID"] as? String)
        ?? Bundle.main.bundleIdentifier
        ?? "",
      clientID: plist["CLIENT_ID"] as? String,
      gcmSenderID: (plist["GCM_SENDER_ID"] as? String) ?? "",
      projectID: plist["PROJECT_ID"] as? String,
      googleAppID: googleAppID,
      databaseURL: plist["DATABASE_URL"] as? String,
      storageBucket: plist["STORAGE_BUCKET"] as? String,
      appGroupID: nil
    )
  }
}
```

### 4.3 `FirebaseApp`, `FirebaseVersion`, and `FirebaseConfiguration`

`FirebaseApp` manages the static app registry, copies `FirebaseOptions` on
initialization (matching `@property(nonatomic, copy, readonly) FIROptions *options`),
supports `isDataCollectionDefaultEnabled`, and holds a `FirebaseComponentContainer`
(`app.container`) for interop lookup:

```swift
import Foundation
private import FirebaseCoreInternal

/// **[Experimental]** Returns the current version of Firebase.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public func FirebaseVersion() -> String {
  "0.0.1-portable"
}

/// **[Experimental]** The entry point of Firebase SDKs.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class FirebaseApp: Sendable {
  public static let defaultAppName = "__FIRAPP_DEFAULT"
  private static let registry = UnfairLock<[String: FirebaseApp]>([:])

  public let name: String
  public let options: FirebaseOptions
  package let _container: FirebaseComponentContainer
  private let dataCollectionEnabled: UnfairLock<Bool>

  public var isDataCollectionDefaultEnabled: Bool {
    get { dataCollectionEnabled.withLock { $0 } }
    set { dataCollectionEnabled.withLock { $0 = newValue } }
  }

  public init(instanceWithName name: String, options: FirebaseOptions) {
    self.name = name
    self.options = options.snapshot()
    self._container = FirebaseComponentContainer()
    self.dataCollectionEnabled = UnfairLock(true)
    self._container.populateFactories(for: self)
  }

  public static func configure() {
    guard let options = FirebaseOptions.defaultOptions() else {
      fatalError(
        """
        Could not locate GoogleService-Info.plist in GOOGLE_SERVICE_INFO_PATH, \
        Bundle.main, or the current working directory.
        """
      )
    }
    configure(name: defaultAppName, options: options)
  }

  public static func configure(options: FirebaseOptions) {
    configure(name: defaultAppName, options: options)
  }

  public static func configure(name: String, options: FirebaseOptions) {
    let app = FirebaseApp(instanceWithName: name, options: options)
    registry.withLock { apps in
      precondition(
        apps[name] == nil,
        "FirebaseApp named '\(name)' has already been configured."
      )
      apps[name] = app
    }
  }

  public static func app() -> FirebaseApp? {
    app(name: defaultAppName)
  }

  public static func app(name: String) -> FirebaseApp? {
    registry.withLock { $0[name] }
  }

  public static var allApps: [String: FirebaseApp]? {
    registry.withLock { $0.isEmpty ? nil : $0 }
  }

  public func delete(_ completion: @escaping @Sendable (Bool) -> Void) {
    let removed = Self.registry.withLock { $0.removeValue(forKey: name) != nil }
    completion(removed)
  }

  @discardableResult
  public func delete() async -> Bool {
    Self.registry.withLock { $0.removeValue(forKey: name) != nil }
  }

  public static func resetApps() {
    registry.withLock { $0.removeAll() }
  }
}
```

### 4.4 `FirebaseCoreExtension`: `ComponentType` and `FirebaseLogger`

To avoid `#if` checks in `FirebaseAI.swift` and `AILog.swift`,
`FirebaseCoreExtension` exposes `app.container`, `ComponentType`, and
`FirebaseLogger`:

```swift
import FirebaseCore
import Foundation
private import FirebaseCoreInternal

extension FirebaseApp {
  /// **[Experimental]** The component container for this `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var container: FirebaseComponentContainer {
    _container
  }
}

/// **[Experimental]** Thread-safe component container for an individual
/// `FirebaseApp`.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class FirebaseComponentContainer: Sendable {
  public typealias Factory = @Sendable (FirebaseApp) -> (any Sendable)?

  private static let registeredFactories = UnfairLock<[ObjectIdentifier: Factory]>([:])
  private let instances = UnfairLock<[ObjectIdentifier: any Sendable]>([:])

  public init() {}

  /// **[Experimental]** Registers a component factory invoked when
  /// `FirebaseApp` instances are created or when a component is requested.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public static func register<T>(
    for type: T.Type,
    factory: @escaping @Sendable (FirebaseApp) -> (any Sendable)?
  ) {
    registeredFactories.withLock { $0[ObjectIdentifier(type)] = factory }
  }

  /// **[Experimental]** Stores or replaces a component instance directly in
  /// this container.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public func setInstance<T>(_ instance: (any Sendable)?, for type: T.Type) {
    instances.withLock { $0[ObjectIdentifier(type)] = instance }
  }

  /// **[Experimental]** Retrieves a registered component instance for `type`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public func instance<T>(for type: T.Type) -> T? {
    instances.withLock { $0[ObjectIdentifier(type)] as? T }
  }

  package func populateFactories(for app: FirebaseApp) {
    let factories = Self.registeredFactories.withLock { $0 }
    for (key, factory) in factories {
      if let instance = factory(app) {
        instances.withLock { $0[key] = instance }
      }
    }
  }
}

/// **[Experimental]** Type-safe lookup wrapper matching Darwin's
/// `FIRComponentType`.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public enum ComponentType<T> {
  public static func instance(
    for type: T.Type,
    in container: FirebaseComponentContainer
  ) -> T? {
    container.instance(for: type)
  }
}
```

### 4.5 Phase 1 unit tests (`FirebaseCore/Portable/Tests`)

Before moving to Phase 2, `FirebaseCorePortableTests` (written with Swift
Testing, `import Testing`) must cover:

- **`FirebaseOptions` tests**:
  - Designated initializer (`init(googleAppID:gcmSenderID:)`) and convenience
    initializer (`init(googleAppID:gcmSenderID:apiKey:projectID:storageBucket:bundleID:clientID:)`).
  - Reference-type mutation (`let options = FirebaseOptions(...); options.apiKey = "new"`),
    `Equatable` / `Hashable` conformance, and `copy()` snapshot behavior.
  - Plist loading via `init?(contentsOfFile:)` (valid `GoogleService-Info.plist`,
    missing required keys returning `nil`, nonexistent path returning `nil`).
- **`FirebaseApp` lifecycle tests**:
  - `configure(options:)` and `configure(name:options:)` for default (`__FIRAPP_DEFAULT`)
    and named apps.
  - Verifying `app.options` stores an immutable snapshot (mutating the original
    `FirebaseOptions` instance after `configure` does not mutate `app.options`).
  - `app()`, `app(name:)`, `allApps`, `delete(_:)`, `resetApps()`, and
    `isDataCollectionDefaultEnabled` thread safety under concurrent access.
- **`FirebaseComponentContainer` & `ComponentType` tests**:
  - Registering a factory with `FirebaseComponentContainer.register(for:factory:)`
    and resolving it lazily via `ComponentType<T>.instance(for:in:)`.
  - Direct instance registration via `container.register(instance:for:)` and
    cleanup on `resetApps()`.
- **`FirebaseConfiguration` & `FirebaseLogger` tests**:
  - Setting `FirebaseConfiguration.shared.setLoggerLevel(_:)` and verifying
    level filtering in `FirebaseLogger`.
- **`UnfairLock` tests**:
  - Concurrent read/write stress test verifying mutual exclusion across tasks.

### 4.6 Phase 1 checklist (gate before Phase 2)

- [ ] Add `isPortableBuild` conditional in `Package.swift` gating dependencies
  and targets (respecting `DEPENDABOT`).
- [ ] Implement `FirebaseCore/Portable/Sources` (with `**[Experimental]**` +
  `> Warning:` DocC comments on all declarations):
  - [ ] `FirebaseOptions.swift`
  - [ ] `FirebaseApp.swift`
  - [ ] `FirebaseConfiguration.swift` & `FirebaseLoggerLevel.swift`
  - [ ] `FirebaseVersion.swift`
  - [ ] `FirebaseComponentContainer.swift`
- [ ] Implement `FirebaseCore/Extension/Portable/Sources`:
  - [ ] `FirebaseLogger.swift`
  - [ ] `ComponentType.swift`
- [ ] Update `FirebaseCore/Internal/Sources/Utilities/UnfairLock.swift` to use
  `Synchronization.Mutex` when `#if !canImport(Darwin)`.
- [ ] Create `FirebaseCore/Portable/Tests/FirebaseCorePortableTests.swift` using
  Swift Testing (`import Testing`).
- [ ] **Phase 1 exit gate**:
  - [ ] `FIREBASE_PORTABLE=1 swift test --filter FirebaseCorePortableTests`
    passes on macOS.
  - [ ] `DEPENDABOT=1 swift package dump-package` outputs the full Darwin
    manifest.
  - [ ] `FIREBASE_PORTABLE=1 swift build --swift-sdk ...` compiles cleanly for
    Static Linux SDK.

---

## 5. Phase 2: Portable interop modules (`FirebaseAuthInterop` and `FirebaseAppCheckInterop`)

### 5.1 `FirebaseAppCheckInterop` (`FirebaseAppCheck/Interop/Portable/Sources`)

Matches Darwin's `FIRAppCheckInterop.h` and `FIRAppCheckTokenResultInterop.h`
so `FirebaseAI/Sources/Types/Internal/AppCheck.swift` and
`AppCheckInteropFake.swift` compile cleanly:

```swift
import Foundation

/// **[Experimental]** Represents the result of a Firebase App Check token
/// request.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public protocol FIRAppCheckTokenResultInterop: Sendable {
  var token: String { get }
  var error: (any Error)? { get }
}

public typealias AppCheckTokenResultInterop = FIRAppCheckTokenResultInterop
public typealias AppCheckTokenHandlerInterop = @Sendable (
  any FIRAppCheckTokenResultInterop
) -> Void

/// **[Experimental]** Common methods for Firebase App Check interoperability.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public protocol AppCheckInterop: AnyObject, Sendable {
  func getToken(
    forcingRefresh: Bool,
    completion handler: @escaping AppCheckTokenHandlerInterop
  )
  func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop

  func tokenDidChangeNotificationName() -> String
  func notificationTokenKey() -> String
  func notificationAppNameKey() -> String

  func getLimitedUseToken(completion handler: @escaping AppCheckTokenHandlerInterop)
  func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop
}

extension AppCheckInterop {
  public func getToken(
    forcingRefresh: Bool,
    completion handler: @escaping AppCheckTokenHandlerInterop
  ) {
    Task {
      let result = await getToken(forcingRefresh: forcingRefresh)
      handler(result)
    }
  }

  public func getLimitedUseToken(
    completion handler: @escaping AppCheckTokenHandlerInterop
  ) {
    Task {
      let result = await getLimitedUseToken()
      handler(result)
    }
  }
}
```

### 5.2 `FirebaseAuthInterop` (`FirebaseAuth/Interop/Portable/Sources`)

Matches Darwin's `FIRAuthInterop.h`:

```swift
import Foundation

/// **[Experimental]** Common methods for Firebase Auth interoperability.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public protocol AuthInterop: AnyObject, Sendable {
  func getToken(forcingRefresh: Bool) async throws -> String?
  func getToken(
    forcingRefresh: Bool,
    completion: @escaping @Sendable (String?, (any Error)?) -> Void
  )
  func getUserID() -> String?
}

extension AuthInterop {
  public func getToken(
    forcingRefresh: Bool,
    completion: @escaping @Sendable (String?, (any Error)?) -> Void
  ) {
    Task {
      do {
        let token = try await getToken(forcingRefresh: forcingRefresh)
        completion(token, nil)
      } catch {
        completion(nil, error)
      }
    }
  }
}
```

### 5.3 Phase 2 unit tests (`FirebaseAuthInteropPortableTests` & `FirebaseAppCheckInteropPortableTests`)

Before moving to Phase 3, unit tests must verify:

- **`FirebaseAppCheckInterop`**:
  - Conforming a mock `AppCheckInterop` and `FIRAppCheckTokenResultInterop`
    type, resolving it from `app.container` via
    `ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self, in: app.container)`,
    and verifying both `async` and default completion-handler `getToken(forcingRefresh:)`
    and `getLimitedUseToken()` methods.
- **`FirebaseAuthInterop`**:
  - Conforming a mock `AuthInterop` type, resolving it via
    `ComponentType<AuthInterop>.instance(for: AuthInterop.self, in: app.container)`,
    and verifying `getToken(forcingRefresh:)` (`async throws` and completion
    bridging for both success and thrown error cases) and `getUserID()`.

### 5.4 Phase 2 checklist (gate before Phase 3)

- [ ] Wire `FirebaseAuthInterop` (`FirebaseAuth/Interop/Portable/Sources`) and
  `FirebaseAppCheckInterop` (`FirebaseAppCheck/Interop/Portable/Sources`) into
  `Package.swift` when `isPortableBuild` is `true`.
- [ ] Implement `AuthInterop.swift` and `AppCheckInterop.swift`.
- [ ] Add unit tests in `FirebaseAuth/Interop/Portable/Tests` and
  `FirebaseAppCheck/Interop/Portable/Tests`.
- [ ] **Phase 2 exit gate**:
  - [ ] `FIREBASE_PORTABLE=1 swift test` passes for both interop test targets on
    macOS.
  - [ ] Static Linux SDK cross-build succeeds.

---

## 6. Phase 3: Portable `FirebaseAppCheck` and `FirebaseAuth`

### 6.1 Portable `FirebaseAppCheck` (`FirebaseAppCheck/Portable/Sources`)

Implements Darwin-compatible `AppCheck`, `AppCheckProvider`,
`AppCheckProviderFactory`, and `AppCheckDebugProvider` so existing integration
test setup (`AppCheck.setAppCheckProviderFactory(TestAppCheckProviderFactory())`)
works without changes.

`AppCheckDebugProvider` exchanges a debug secret (from the
`FIRAAppCheckDebugToken` or `APP_CHECK_DEBUG_TOKEN` environment variable) with
the Firebase App Check REST API:

- Endpoint:
  `POST https://firebaseappcheck.googleapis.com/v1/projects/{project_id}/apps/{app_id}:exchangeDebugToken?key={api_key}`

When `AppCheck.setAppCheckProviderFactory(_:)` is called, it registers a
component factory with `FirebaseComponentContainer.register(for: AppCheckInterop.self)`
so any subsequently configured `FirebaseApp` automatically populates an
`AppCheck` instance in `app.container`.

### 6.2 Portable `FirebaseAuth` (`FirebaseAuth/Portable/Sources`)

Implements Darwin-compatible `Auth.auth(app:)`, `auth.currentUser`,
`auth.signIn(withEmail:password:)`, `auth.signInAnonymously()`, and
`auth.signOut()` against the Google Identity Toolkit and Secure Token REST APIs:

- Anonymous sign-up:
  `POST https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}`
- Email/password sign-in:
  `POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}`
- Token refresh:
  `POST https://securetoken.googleapis.com/v1/token?key={api_key}`

Calling `Auth.auth(app:)` lazily creates or retrieves the `Auth` instance for
`app` and registers it in `app.container` under `AuthInterop.self` so
`FirebaseAI.firebaseAI(app:)` automatically attaches `Authorization: Firebase <token>`
headers when a user is signed in.

### 6.3 Phase 3 unit tests (`FirebaseAppCheckPortableTests` & `FirebaseAuthPortableTests`)

Before moving to Phase 4, each framework must be unit tested using injected
`URLSession` / `URLProtocol` mocks:

- **`FirebaseAppCheckPortableTests`**:
  - `AppCheckDebugProvider` REST request serialization (`exchangeDebugToken` URL,
    `debugToken` JSON body) and response parsing (`token` and `ttl` duration).
  - In-memory token caching in `AppCheck`: returning cached token when valid,
    forcing refresh when `forcingRefresh == true` or when token is near
    expiration, and returning an error-carrying `FIRAppCheckTokenResultInterop`
    (with placeholder token) on HTTP/network failure.
  - Automatic registration into `app.container` via
    `AppCheck.setAppCheckProviderFactory(_:)` and lookup via
    `ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self, in: app.container)`.
- **`FirebaseAuthPortableTests`**:
  - `signIn(withEmail:password:)` and `signInAnonymously()` request payloads,
    response decoding (`idToken`, `refreshToken`, `expiresIn`, `localId`), and
    `currentUser` state updates.
  - `AuthInterop.getToken(forcingRefresh:)`: returning cached `idToken` when
    unexpired, exchanging `refreshToken` against `securetoken.googleapis.com`
    when expired or `forcingRefresh == true`, and returning `nil` when signed
    out (`signOut()`).
  - Automatic registration into `app.container` under `AuthInterop.self`.

### 6.4 Phase 3 checklist (gate before Phase 4)

- [ ] Implement `FirebaseAppCheck/Portable/Sources` (`AppCheck`, `AppCheckToken`,
  `AppCheckProvider`, `AppCheckProviderFactory`, `AppCheckDebugProvider`).
- [ ] Implement `FirebaseAuth/Portable/Sources` (`Auth`, `User`,
  `AuthDataResult`, REST token exchange & refresh).
- [ ] Add unit tests using mock `URLProtocol` handlers in
  `FirebaseAppCheck/Portable/Tests` and `FirebaseAuth/Portable/Tests`.
- [ ] **Phase 3 exit gate**:
  - [ ] `FIREBASE_PORTABLE=1 swift test` passes all `FirebaseAppCheckPortableTests`
    and `FirebaseAuthPortableTests` on macOS.
  - [ ] Static Linux SDK cross-build succeeds for both frameworks.

---

## 7. Phase 4: `FirebaseAILogic` Linux port and unit tests

### 7.1 `FirebaseAI/Sources` audit and portability updates

Audit and update `FirebaseAI/Sources` with minimal conditional compilation:

- [ ] **`FoundationNetworking` imports**: Add
  `#if canImport(FoundationNetworking) import FoundationNetworking #endif` (or
  re-export from `FirebaseCore` in portable mode) for `URLSession`,
  `URLRequest`, `URLResponse`, `HTTPURLResponse`, and `URLSessionWebSocketTask`.
- [ ] **Logging (`AILog.swift`, `GenerativeAIService.swift`)**: Guard
  `import os.log` and `OSLog` usage with `#if canImport(os)` so Linux builds
  route logs solely through `FirebaseLogger.log(level:service:code:message:)`.
- [ ] **Locking (`FirebaseAI.swift`, `UnfairLock.swift`)**: Replace direct
  `os_unfair_lock` in `FirebaseAI.swift` with `UnfairLock` (from
  `FirebaseCoreInternal`) or `Synchronization.Mutex` so no Darwin `os.lock`
  symbol is referenced on Linux.
- [ ] **Objective-C component stub (`FirebaseAI.swift`)**: Guard
  `@objc(FIRVertexAIComponent) class FirebaseVertexAIComponent: NSObject {}`
  with `#if canImport(ObjectiveC)`.
- [ ] **Platform image extensions (`PartsRepresentable+Image.swift`)**: Verify
  all `UIKit` / `AppKit` / `CoreGraphics` / `ImageIO` imports are already
  properly guarded by `#if canImport(...)`.
- [ ] **WebSocket / Live API (`AsyncWebSocket.swift`, `LiveSession.swift`)**:
  Verify `URLSessionWebSocketTask` compilation with `FoundationNetworking` on
  Linux (or guard unavailable APIs if needed by `swift-corelibs-foundation`).

### 7.2 `FirebaseAILogicUnit` test target on portable / Linux builds (gate before Phase 5)

- [ ] In `Package.swift`, omit the `"FirebaseStorage"` dependency from
  `FirebaseAILogicUnit` when `isPortableBuild` is `true` (and guard
  `CloudStorageSnippets.swift` with `#if canImport(FirebaseStorage)`).
- [ ] Guard Objective-C runtime assertions in `VertexComponentTests.swift`
  (`NSClassFromString("FIRVertexAIComponent")` and `autoreleasepool`) with
  `#if canImport(ObjectiveC)`.
- [ ] **Phase 4 exit gate**:
  - [ ] `FIREBASE_PORTABLE=1 swift test --filter FirebaseAILogicUnit` passes on
    macOS.
  - [ ] `FirebaseAILogic` builds cleanly with the Static Linux SDK (and passes
    `swift test` on Linux).

---

## 8. Phase 5: End-to-end integration testing on macOS and Linux

### 8.1 Local portable validation with `FirebaseAITestApp`

Before running on Linux machines:

- [ ] Open `FirebaseAITestApp` in Xcode with `FIREBASE_PORTABLE=1` set in the
  environment.
- [ ] Run the existing integration test suite (`GenerateContentIntegrationTests`,
  `CountTokensIntegrationTests`, `SchemaTests`) against live Firebase backends
  to confirm portable `FirebaseCore`, `FirebaseAuth`, and `FirebaseAppCheck`
  interoperate seamlessly with `FirebaseAILogic`.

### 8.2 Standalone SwiftPM Linux integration test target

- [ ] Configure a SwiftPM integration test target (or portable test runner) that
  reads `GOOGLE_SERVICE_INFO_PATH`, `FIRAAppCheckDebugToken` /
  `APP_CHECK_DEBUG_TOKEN`, and test Auth credentials from environment variables.
- [ ] Execute integration tests on Linux via `swift test` in CI.