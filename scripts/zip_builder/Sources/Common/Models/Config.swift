/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import struct TSCUtility.Version

public typealias Version = TSCUtility.Version

// TODO: Look into generating a JSON Schema for IDE autocomplete/validation, and possibly a CLI dump/init command for default config files.

/// Fully resolved, immutable configuration used throughout the zip builder pipeline.
///
/// ### File System Discovery
/// When resolving a configuration locally, `PlanningEngine` searches the file system for a
/// JSON configuration file in the following order:
/// 1. **Explicit Path**: The custom file path passed via `-c` / `--config <path>`, if specified.
/// 2. **Package Root**: `zip_builder.json` inside the target SwiftPM package directory
///    (`<package-path>/zip_builder.json`).
/// 3. **Working Directory**: `zip_builder.json` in the current working directory
///    (`./zip_builder.json`).
///
/// ### Resolution Precedence
/// Regardless if a configuration file is found, `ConfigResolver` resolves each
/// property using the following precedence (from highest to lowest):
/// 1. **CLI Overrides (`BuildOptions`)**: Command-line flags and options passed at invocation.
/// 2. **Configuration File (`zip_builder.json`)**: Values explicitly declared in the JSON file.
/// 3. **Package Manifest (`Package.swift`)**: Inferred values for `projectName`, `version`,
///    baseline `deploymentTargets`, `products`, per-product platforms, and
///    `aggregatePackageNames`.
/// 4. **Default Fallbacks (`Config.Defaults`)**: Standard built-in defaults when omitted elsewhere.
public struct Config: Codable, Sendable, Equatable {
  /// Semantic release version used for Xcode build settings, preprocessor macros, and naming the
  /// output archive (`<projectName>-<version>-latest.zip`).
  ///
  /// In `zip_builder.json`, specify a semantic version string (which is automatically parsed into
  /// `Version`).
  ///
  /// - **Optional (Inferred)**: If omitted from the config file (and not passed via `--version`),
  ///   it is inferred from `Package.swift` by searching for a string variable named
  ///   `<projectName>Version` or `version`.
  /// - **Throws**: `LoadConfigError.missingVersion` if omitted and no matching version variable can
  ///   be inferred from `Package.swift`.
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// let firebaseVersion = "12.18.0"
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "version": "12.18.0"
  /// ```
  public let version: Version

  /// Name of the synthesized Xcode project (`<projectName>.xcodeproj`) and release archive prefix.
  ///
  /// - **Optional (Inferred)**: If omitted from the config file (and not passed via
  ///   `--project-name`), it is inferred from `Package.swift` by reading the `name` parameter of
  ///   the root `Package` declaration.
  /// - **Throws**: `LoadConfigError.missingProjectName` if omitted and a non-empty root package
  ///   name cannot be inferred from `Package.swift`.
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// let package = Package(
  ///   name: "Firebase",
  ///   // ...
  /// )
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "projectName": "Firebase"
  /// ```
  public let projectName: String

  /// Reverse-DNS prefix used to construct `PRODUCT_BUNDLE_IDENTIFIER`
  /// (`<bundleIdPrefix>.<TargetName>`) for all compiled frameworks and resource bundles.
  ///
  /// - **Required**: Must be specified in `zip_builder.json` (or via `--bundle-id-prefix`). Cannot
  ///   be inferred from `Package.swift` and has no default value.
  /// - **Throws**: `LoadConfigError.missingBundleIdPrefix` if omitted.
  ///
  /// ```json
  /// "bundleIdPrefix": "com.google.firebase"
  /// ```
  public let bundleIdPrefix: String

  /// Minimum OS deployment target versions applied to generated Xcode targets.
  ///
  /// In `zip_builder.json`, specify a dictionary mapping lowercase platform names (`"ios"`,
  /// `"macos"`, `"tvos"`, `"watchos"`, `"visionos"`, `"catalyst"`) to minimum OS version strings.
  ///
  /// - **Optional (Inferred)**: If omitted from the config file (or for any individual platform
  ///   omitted from the dictionary), baseline versions are inferred from the `platforms` array in
  ///   `Package.swift`, falling back to SwiftPM's default deployment target for any platform not
  ///   declared in `Package.swift`.
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// let package = Package(
  ///   name: "Firebase",
  ///   platforms: [
  ///     .iOS(.v15),
  ///     .macCatalyst(.v15),
  ///     .macOS(.v10_15),
  ///     .tvOS(.v15),
  ///     .watchOS(.v7),
  ///   ],
  ///   // ...
  /// )
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "deploymentTargets": {
  ///   "ios": "15.0",
  ///   "macos": "10.15",
  ///   "tvos": "15.0",
  ///   "watchos": "9.0",
  ///   "visionos": "1.0"
  /// }
  /// ```
  public let deploymentTargets: DeploymentTargets

  /// Optional C/Objective-C preprocessor macro name injected into `GCC_PREPROCESSOR_DEFINITIONS`
  /// with the resolved release version (`<versionMacroName>=<version>`).
  ///
  /// Useful when SDK source code reads its own version string at compile time via a preprocessor
  /// macro.
  ///
  /// - **Optional**: Defaults to `nil` (no version macro is injected).
  ///
  /// ```json
  /// "versionMacroName": "Firebase_VERSION"
  /// ```
  public let versionMacroName: String?

  /// Product names for which top-level folders should not be created in the final distribution zip.
  ///
  /// Useful for umbrella products (like `"Firebase"`) that have no standalone binary, or
  /// foundational products (like `"FirebaseCore"`) whose `.xcframework`s are already bundled
  /// inside `baseProduct`. Their underlying targets are still compiled when depended upon by other
  /// products.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "skippedProductFolders": [
  ///   "Firebase",
  ///   "FirebaseCore",
  ///   "FirebaseInstallations"
  /// ]
  /// ```
  public let skippedProductFolders: [String]

  /// Consolidates foundational shared frameworks into a single base product directory so they are
  /// not duplicated across every downstream product folder.
  ///
  /// When configured, any framework listed in `baseProduct.frameworks` is placed exclusively inside
  /// `baseProduct.product` and omitted from all other product directories, significantly reducing
  /// the size of the final zip archive.
  ///
  /// - **Optional**: Defaults to `nil` (each product folder bundles all of its transitive
  ///   `.xcframework` dependencies).
  ///
  /// ```json
  /// "baseProduct": {
  ///   "product": "FirebaseAnalytics",
  ///   "frameworks": [
  ///     "FirebaseAnalytics",
  ///     "FirebaseCore",
  ///     "GoogleUtilities",
  ///     "nanopb"
  ///   ]
  /// }
  /// ```
  public let baseProduct: BaseProduct?

  /// Supplementary files, headers, module maps, or scripts copied from the repository into the
  /// root release directory (`"destination": "."`) or specific product subdirectories
  /// (`"product": "<ProductName>"`).
  ///
  /// Useful for bundling helper scripts (like Crashlytics dSYM upload tools), `NOTICES` files, or
  /// top-level umbrella headers alongside compiled `.xcframework`s.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "extraFiles": [
  ///   {
  ///     "product": "FirebaseCrashlytics",
  ///     "files": [
  ///       "Crashlytics/run",
  ///       "Crashlytics/upload-symbols"
  ///     ]
  ///   },
  ///   {
  ///     "destination": ".",
  ///     "files": [
  ///       "CoreOnly/NOTICES",
  ///       "CoreOnly/Sources/Firebase.h"
  ///     ]
  ///   }
  /// ]
  /// ```
  public let extraFiles: [ExtraFiles]

  /// Product names declared in `Package.swift` that are completely ignored and excluded from the
  /// build plan and distribution.
  ///
  /// Useful for skipping community extensions, experimental libraries, or internal helper products
  /// that should not be shipped in the release archive.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "excludedProducts": [
  ///   "FirebaseAuthCombine-Community",
  ///   "FirebaseAnalyticsCore"
  /// ]
  /// ```
  public let excludedProducts: [String]

  /// Additional product entries to build and package alongside the library products automatically
  /// discovered from `Package.swift`.
  ///
  /// Useful when an internal SwiftPM target (such as `"FirebaseABTesting"`) is not exposed as a
  /// top-level `.library(...)` product in `Package.swift`, but still needs its own standalone
  /// product folder in the zip distribution.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "extraProducts": [
  ///   {
  ///     "name": "FirebaseABTesting",
  ///     "targets": ["FirebaseABTesting"]
  ///   }
  /// ]
  /// ```
  public let extraProducts: [ProductEntry]

  /// Explicit allowlist of products to build and package, overriding automatic product discovery
  /// from `Package.swift`.
  ///
  /// Set this only when you want to restrict the entire build to a fixed list of products.
  ///
  /// - **Optional (Inferred)**: Defaults to `nil`. If omitted from the config file, products are
  ///   inferred from the root package's `products` array in `Package.swift` by discovering all
  ///   `.library(name: ..., targets: [...])` entries (excluding any names in `excludedProducts` and
  ///   applying any renames from `renamedProducts`).
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// let package = Package(
  ///   name: "Firebase",
  ///   products: [
  ///     .library(
  ///       name: "FirebaseCore",
  ///       targets: ["FirebaseCore"]
  ///     ),
  ///   ],
  ///   // ...
  /// )
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "products": [
  ///   {
  ///     "name": "FirebaseCore",
  ///     "targets": ["FirebaseCore"]
  ///   }
  /// ]
  /// ```
  public let products: [ProductEntry]?

  /// Maps SwiftPM product or target names to their desired output `.xcframework` and distribution
  /// folder names.
  ///
  /// Useful when SwiftPM product or target names differ from expected binary distribution naming
  /// conventions (for example, stripping `-Beta` suffixes or renaming `GTMSessionFetcherCore` to
  /// `GTMSessionFetcher`).
  ///
  /// - **Optional**: Defaults to `[:]`.
  ///
  /// ```json
  /// "renamedProducts": {
  ///   "FirebaseAppDistribution-Beta": "FirebaseAppDistribution",
  ///   "GTMSessionFetcherCore": "GTMSessionFetcher",
  ///   "FirebaseAI": "FirebaseAILogic"
  /// }
  /// ```
  public let renamedProducts: [String: String]

  /// External prebuilt binary archives (`.zip`) to download and unpack into specific product
  /// directories during packaging.
  ///
  /// Useful for bundling third-party or out-of-repo binary dependencies (like `GoogleSignIn`) that
  /// are not part of the SwiftPM dependency graph.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "externalArtifacts": [
  ///   {
  ///     "productName": "GoogleSignIn",
  ///     "url": "https://dl.google.com/dl/firebase/ios/carthage/12.18.0/GoogleSignIn.zip",
  ///     "subpath": "GoogleSignIn"
  ///   }
  /// ]
  /// ```
  public let externalArtifacts: [ExternalArtifact]

  /// Directory names recognized as containing public C/Objective-C interface headers when
  /// classifying header visibility (`Public` vs `Project`) and generating module umbrella headers.
  ///
  /// SwiftPM targets typically place public headers in `"include"` or `"Public"`, whereas some
  /// libraries use custom directory conventions (such as `"spm_headers"` in nanopb or
  /// `"Interop"`/`"Extension"` for cross-module headers).
  ///
  /// - **Optional**: Defaults to `["Public", "include"]`.
  ///
  /// ```json
  /// "publicHeaderFolderNames": [
  ///   "Public",
  ///   "include",
  ///   "spm_headers",
  ///   "Interop",
  ///   "Extension"
  /// ]
  /// ```
  public let publicHeaderFolderNames: [String]

  /// Whether to automatically detect and filter out synthetic SwiftPM wrapper targets from
  /// compilation and packaging.
  ///
  /// Because SwiftPM does not natively support conditional target dependencies per platform or
  /// mixed-language targets, packages often define empty "wrapper" targets containing only stub
  /// files (`dummy.m`, `*Wrapper.swift`) to tie dependencies together. Enabling this prevents
  /// emitting empty `.xcframework` bundles for those wrapper targets while preserving their
  /// transitive dependencies.
  ///
  /// - **Optional**: Defaults to `true`.
  ///
  /// ```json
  /// "filterWrapperTargets": true
  /// ```
  public let filterWrapperTargets: Bool

  /// Whether to strip `_CodeSignature` directories from downloaded external binary `.xcframework`
  /// artifacts during packaging.
  ///
  /// Useful when prebuilt binary dependencies are signed with an upstream certificate that causes
  /// code-signing conflicts when embedded into consumer apps.
  ///
  /// - **Optional**: Defaults to `false`.
  ///
  /// ```json
  /// "stripExternalBinaryCodeSignatures": false
  /// ```
  public let stripExternalBinaryCodeSignatures: Bool

  /// Internal or companion target names whose standalone `.xcframework` bundles should be omitted
  /// from final product distribution folders.
  ///
  /// In SwiftPM, mixed-language modules must be split into separate targets (e.g., `FirebaseAuth`
  /// in Swift and `FirebaseAuthInternal` in Objective-C). While both targets are compiled and
  /// linked during the build, listing the internal companion target here prevents shipping an
  /// extra implementation-detail `.xcframework` when its public headers are already merged into the
  /// parent product.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "suppressedInternalFrameworks": [
  ///   "FirebaseAuthInternal",
  ///   "FirebaseCrashlyticsSwift",
  ///   "FirebaseSessionsObjC"
  /// ]
  /// ```
  public let suppressedInternalFrameworks: [String]

  /// Overrides the supported compilation and packaging platforms for specific products or targets.
  ///
  /// In `zip_builder.json`, map a product or target name to an array of lowercase platform strings
  /// (`"ios"`, `"macos"`, `"tvos"`, `"watchos"`, `"visionos"`, `"catalyst"`). Useful when
  /// `Package.swift` declares broad package-wide platform support, but a specific library only
  /// supports a subset of platforms in the binary distribution.
  ///
  /// - **Optional (Inferred)**: Defaults to `[:]`. If a product is omitted from
  ///   `productPlatformOverrides` (and `platforms` is omitted on its `ProductEntry`), its supported
  ///   platforms are inferred from `Package.swift` by inspecting `.when(platforms: [...])`
  ///   dependency conditions on its root target(s) (automatically including `"catalyst"` whenever
  ///   `.iOS` is present), or falling back to `["ios", "macos", "tvos", "watchos", "catalyst"]`
  ///   when no platform condition is declared.
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// .target(
  ///   name: "FirebaseAppDistributionTarget",
  ///   dependencies: [
  ///     .target(
  ///       name: "FirebaseAppDistribution",
  ///       condition: .when(platforms: [.iOS])
  ///     ),
  ///   ]
  /// )
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "productPlatformOverrides": {
  ///   "FirebaseInAppMessaging": ["ios", "catalyst"],
  ///   "FirebaseDatabase": ["ios", "catalyst", "macos", "tvos"]
  /// }
  /// ```
  public let productPlatformOverrides: [String: [Platform]]

  /// Maps a product name to additional `.xcframework` names that should be copied into its
  /// distribution folder even if they are not direct SwiftPM dependencies.
  ///
  /// Useful when maintaining parity with legacy distributions or bundling runtime-loaded
  /// frameworks alongside a product.
  ///
  /// - **Optional**: Defaults to `[:]`.
  ///
  /// ```json
  /// "extraFrameworksPerProduct": {
  ///   "FirebasePerformance": [
  ///     "FirebaseRemoteConfig",
  ///     "FirebaseSharedSwift"
  ///   ]
  /// }
  /// ```
  public let extraFrameworksPerProduct: [String: [String]]

  /// Restricts the compiled `ARCHS` Xcode build setting for specific platform keys (`"ios"`,
  /// `"macos"`, `"tvos"`, `"watchos"`, `"visionos"`, `"catalyst"`).
  ///
  /// Useful when a platform's default architecture set in Xcode includes slices that should not be
  /// built (for example, restricting `watchos` to `["arm64", "arm64_32"]` so the output slice
  /// directory matches expected naming).
  ///
  /// - **Optional**: Defaults to `[:]` (uses Xcode's standard architecture set for each platform).
  ///
  /// ```json
  /// "targetArchitectures": {
  ///   "watchos": [
  ///     "arm64",
  ///     "arm64_32"
  ///   ]
  /// }
  /// ```
  public let targetArchitectures: [String: [String]]

  /// Whether to enable Xcode's module verifier (`ENABLE_MODULE_VERIFIER = YES`) on generated
  /// framework targets to validate module maps and public headers during compilation.
  ///
  /// - **Optional**: Defaults to `false`.
  ///
  /// ```json
  /// "enableModuleVerifier": false
  /// ```
  public let enableModuleVerifier: Bool

  /// Custom Xcode build settings (`[Key: Value]`) injected into all generated native targets,
  /// overriding default project generation settings.
  ///
  /// - **Optional**: Defaults to `[:]`.
  ///
  /// ```json
  /// "buildSettings": {
  ///   "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
  ///   "OTHER_SWIFT_FLAGS": "-DDEBUG"
  /// }
  /// ```
  public let buildSettings: [String: String]

  /// Active Apple platforms to compile slices for and package into `.xcframework` bundles.
  ///
  /// In `zip_builder.json`, specify an array of lowercase platform strings (`"ios"`, `"macos"`,
  /// `"tvos"`, `"watchos"`, `"visionos"`, `"catalyst"`).
  ///
  /// - **Optional**: Defaults to `["ios", "macos", "tvos", "watchos", "catalyst", "visionos"]`.
  ///
  /// ```json
  /// "targetPlatforms": [
  ///   "ios",
  ///   "macos",
  ///   "tvos",
  ///   "watchos",
  ///   "visionos",
  ///   "catalyst"
  /// ]
  /// ```
  public let targetPlatforms: [Platform]

  /// Explicit target names that are always treated as synthetic SwiftPM wrapper targets and
  /// excluded from standalone framework compilation when `filterWrapperTargets` is enabled.
  ///
  /// Useful for umbrella targets (like `"Firebase"`) whose names do not match
  /// `wrapperTargetPatterns`.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "wrapperTargetNames": [
  ///   "Firebase"
  /// ]
  /// ```
  public let wrapperTargetNames: [String]

  /// Wildcard (`*`) patterns used to identify synthetic SwiftPM wrapper targets by name.
  ///
  /// Targets matching these patterns are inspected and filtered out if they only wrap binary or
  /// transitive dependencies without adding real implementation sources.
  ///
  /// - **Optional**: Defaults to `["*Wrapper", "*Wrap"]`.
  ///
  /// ```json
  /// "wrapperTargetPatterns": [
  ///   "*Wrapper",
  ///   "*Wrap"
  /// ]
  /// ```
  public let wrapperTargetPatterns: [String]

  /// Directory names within a target's source path that indicate the target only contains SwiftPM
  /// platform-exclusion stubs rather than real implementation code.
  ///
  /// If all of a target's source files reside inside these folders, it is treated as a synthetic
  /// wrapper target.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "wrapperSourceFolderNames": [
  ///   "SwiftPM-PlatformExclude"
  /// ]
  /// ```
  public let wrapperSourceFolderNames: [String]

  /// External SwiftPM package names whose fine-grained Clang sub-targets should be combined into a
  /// single monolithic `.xcframework` named after the package.
  ///
  /// Some packages (like `GoogleUtilities`) split their code into many small SwiftPM targets
  /// (`GULAppDelegateSwizzler`, `GULEnvironment`, `GULLogger`, etc.), which would otherwise emit
  /// dozens of separate `.xcframework` bundles. Listing the package here merges all of its source
  /// files, public headers, and dependencies into a single unified `.xcframework`.
  ///
  /// - **Optional (Inferred)**: Defaults to `[]`. If omitted from the config file, external Clang
  ///   (C/Objective-C) dependency packages are automatically inferred for aggregation when their
  ///   `Package.swift` defines multiple non-test, non-binary targets prefixed with
  ///   `<PackageName>-`.
  ///
  /// # Examples
  ///
  /// ## Package.swift
  /// ```swift
  /// let package = Package(
  ///   name: "GoogleUtilities",
  ///   // ...
  ///   targets: [
  ///     .target(
  ///       name: "GoogleUtilities-Environment",
  ///       // ...
  ///     ),
  ///     .target(
  ///       name: "GoogleUtilities-Logger",
  ///       // ...
  ///     ),
  ///   ]
  /// )
  /// ```
  ///
  /// ## Config File
  ///
  /// ```json
  /// "aggregatePackageNames": [
  ///   "GoogleUtilities"
  /// ]
  /// ```
  public let aggregatePackageNames: [String]

  /// Additional subfolder names at a module's parent directory level that should be added to
  /// `HEADER_SEARCH_PATHS` when present on disk.
  ///
  /// Useful when shared header-only directories (like `"Typedefs"`) live alongside a module's
  /// `Sources` folder rather than inside a specific target path.
  ///
  /// - **Optional**: Defaults to `[]`.
  ///
  /// ```json
  /// "extraHeaderFolderNames": [
  ///   "Typedefs"
  /// ]
  /// ```
  public let extraHeaderFolderNames: [String]

  /// Path substrings used to filter out internal or generated header directories when merging
  /// companion module headers into a primary target's public headers.
  ///
  /// Prevents internal headers (such as `/Private/` or `/Protogen/`) from accidentally being
  /// exposed as `Public` in the compiled `.xcframework`.
  ///
  /// - **Optional**: Defaults to `["/Private/"]`.
  ///
  /// ```json
  /// "excludedHeaderPathSubstrings": [
  ///   "/Private/",
  ///   "/Protogen/"
  /// ]
  /// ```
  public let excludedHeaderPathSubstrings: [String]

  /// Suffixes used to detect internal companion targets belonging to a parent module.
  ///
  /// When a module is split across targets in SwiftPM (e.g., `FirebaseAuth` and
  /// `FirebaseAuthInternal`), matching these suffixes allows the project generator to locate the
  /// companion target's public headers (excluding `excludedHeaderPathSubstrings`) and merge them
  /// into the parent framework's public header interface.
  ///
  /// - **Optional**: Defaults to `["Internal", "ObjC", "Swift", "_iOS"]`.
  ///
  /// ```json
  /// "companionModuleSuffixes": [
  ///   "Internal",
  ///   "ObjC",
  ///   "Swift",
  ///   "_iOS"
  /// ]
  /// ```
  public let companionModuleSuffixes: [String]

  /// Exact source or header filenames recognized as empty dummy/stub files when determining whether
  /// a target is a synthetic SwiftPM wrapper.
  ///
  /// Targets containing only stub files have no real symbols to compile and are filtered out when
  /// `filterWrapperTargets` is `true`.
  ///
  /// - **Optional**: Defaults to `["dummy.m", "dummy.h", "empty.m", "empty.h"]`.
  ///
  /// ```json
  /// "stubFileNames": [
  ///   "dummy.m",
  ///   "dummy.h",
  ///   "empty.m",
  ///   "empty.h"
  /// ]
  /// ```
  public let stubFileNames: [String]

  /// Wildcard (`*`) filename patterns recognized as dummy/stub files when determining whether a
  /// target is a synthetic SwiftPM wrapper.
  ///
  /// - **Optional**: Defaults to `["*Wrapper.swift", "*Wrap.swift"]`.
  ///
  /// ```json
  /// "stubFilePatterns": [
  ///   "*Wrapper.swift",
  ///   "*Wrap.swift"
  /// ]
  /// ```
  public let stubFilePatterns: [String]

  /// Default configuration values used when options are omitted.
  public enum Defaults {
    public static let deploymentTargets = DeploymentTargets()
    public static let skippedProductFolders: [String] = []
    public static let extraFiles: [ExtraFiles] = []
    public static let excludedProducts: [String] = []
    public static let extraProducts: [ProductEntry] = []
    public static let renamedProducts: [String: String] = [:]
    public static let externalArtifacts: [ExternalArtifact] = []
    public static let publicHeaderFolderNames: [String] = ["Public", "include"]
    public static let filterWrapperTargets: Bool = true
    public static let stripExternalBinaryCodeSignatures: Bool = false
    public static let suppressedInternalFrameworks: [String] = []
    public static let companionModuleSuffixes: [String] = ["Internal", "ObjC", "Swift", "_iOS"]
    public static let stubFileNames: [String] = ["dummy.m", "dummy.h", "empty.m", "empty.h"]
    public static let stubFilePatterns: [String] = ["*Wrapper.swift", "*Wrap.swift"]
    public static let productPlatformOverrides: [String: [Platform]] = [:]
    public static let extraFrameworksPerProduct: [String: [String]] = [:]
    public static let targetArchitectures: [String: [String]] = [:]
    public static let enableModuleVerifier: Bool = false
    public static let buildSettings: [String: String] = [:]
    public static let targetPlatforms: [Platform] = Platform.allApplePlatforms
    public static let wrapperTargetNames: [String] = []
    public static let wrapperTargetPatterns: [String] = ["*Wrapper", "*Wrap"]
    public static let wrapperSourceFolderNames: [String] = []
    public static let aggregatePackageNames: [String] = []
    public static let extraHeaderFolderNames: [String] = []
    public static let excludedHeaderPathSubstrings: [String] = ["/Private/"]
    public static let baseHeaderSearchPaths: [String] = [
      "$(inherited)",
      "$(PROJECT_DIR)/GeneratedModules",
      "$(PROJECT_DIR)/GeneratedModules/*",
    ]
  }

  /// Foundational `HEADER_SEARCH_PATHS` entries included on every generated Xcode target before
  /// target-specific include paths are appended.
  ///
  /// Including `$(PROJECT_DIR)/GeneratedModules` allows targets to resolve synthesized module maps
  /// and umbrella headers across modules.
  ///
  /// - **Optional**: Defaults to `["$(inherited)", "$(PROJECT_DIR)/GeneratedModules",
  ///   "$(PROJECT_DIR)/GeneratedModules/*"]`.
  ///
  /// ```json
  /// "baseHeaderSearchPaths": [
  ///   "$(inherited)",
  ///   "$(PROJECT_DIR)/GeneratedModules",
  ///   "$(PROJECT_DIR)/GeneratedModules/*"
  /// ]
  /// ```
  public let baseHeaderSearchPaths: [String]

  public init(version: Version,
              projectName: String,
              bundleIdPrefix: String,
              deploymentTargets: DeploymentTargets? = nil,
              versionMacroName: String? = nil,
              skippedProductFolders: [String]? = nil,
              baseProduct: BaseProduct? = nil,
              extraFiles: [ExtraFiles]? = nil,
              excludedProducts: [String]? = nil,
              extraProducts: [ProductEntry]? = nil,
              products: [ProductEntry]? = nil,
              renamedProducts: [String: String]? = nil,
              externalArtifacts: [ExternalArtifact]? = nil,
              publicHeaderFolderNames: [String]? = nil,
              filterWrapperTargets: Bool? = nil,
              stripExternalBinaryCodeSignatures: Bool? = nil,
              suppressedInternalFrameworks: [String]? = nil,
              productPlatformOverrides: [String: [Platform]]? = nil,
              extraFrameworksPerProduct: [String: [String]]? = nil,
              targetArchitectures: [String: [String]]? = nil,
              enableModuleVerifier: Bool? = nil,
              buildSettings: [String: String]? = nil,
              targetPlatforms: [Platform]? = nil,
              wrapperTargetNames: [String]? = nil,
              wrapperTargetPatterns: [String]? = nil,
              wrapperSourceFolderNames: [String]? = nil,
              aggregatePackageNames: [String]? = nil,
              baseHeaderSearchPaths: [String]? = nil,
              extraHeaderFolderNames: [String]? = nil,
              excludedHeaderPathSubstrings: [String]? = nil,
              companionModuleSuffixes: [String]? = nil,
              stubFileNames: [String]? = nil,
              stubFilePatterns: [String]? = nil) {
    self.version = version
    self.projectName = projectName
    self.bundleIdPrefix = bundleIdPrefix
    self.deploymentTargets = deploymentTargets ?? Defaults.deploymentTargets
    self.versionMacroName = versionMacroName
    self.skippedProductFolders = skippedProductFolders ?? Defaults.skippedProductFolders
    self.baseProduct = baseProduct
    self.extraFiles = extraFiles ?? Defaults.extraFiles
    self.excludedProducts = excludedProducts ?? Defaults.excludedProducts
    self.extraProducts = extraProducts ?? Defaults.extraProducts
    self.products = products
    self.renamedProducts = renamedProducts ?? Defaults.renamedProducts
    self.externalArtifacts = externalArtifacts ?? Defaults.externalArtifacts
    self.publicHeaderFolderNames = publicHeaderFolderNames ?? Defaults.publicHeaderFolderNames
    self.filterWrapperTargets = filterWrapperTargets ?? Defaults.filterWrapperTargets
    self.stripExternalBinaryCodeSignatures = stripExternalBinaryCodeSignatures ?? Defaults
      .stripExternalBinaryCodeSignatures
    self.suppressedInternalFrameworks = suppressedInternalFrameworks ?? Defaults
      .suppressedInternalFrameworks
    self.companionModuleSuffixes = companionModuleSuffixes ?? Defaults.companionModuleSuffixes
    self.stubFileNames = stubFileNames ?? Defaults.stubFileNames
    self.stubFilePatterns = stubFilePatterns ?? Defaults.stubFilePatterns
    self.productPlatformOverrides = productPlatformOverrides ?? Defaults.productPlatformOverrides
    self.extraFrameworksPerProduct = extraFrameworksPerProduct ?? Defaults.extraFrameworksPerProduct
    self.targetArchitectures = targetArchitectures ?? Defaults.targetArchitectures
    self.enableModuleVerifier = enableModuleVerifier ?? Defaults.enableModuleVerifier
    self.buildSettings = buildSettings ?? Defaults.buildSettings
    self.targetPlatforms = targetPlatforms ?? Defaults.targetPlatforms
    self.wrapperTargetNames = wrapperTargetNames ?? Defaults.wrapperTargetNames
    self.wrapperTargetPatterns = wrapperTargetPatterns ?? Defaults.wrapperTargetPatterns
    self.wrapperSourceFolderNames = wrapperSourceFolderNames ?? Defaults.wrapperSourceFolderNames
    self.aggregatePackageNames = aggregatePackageNames ?? Defaults.aggregatePackageNames
    self.baseHeaderSearchPaths = baseHeaderSearchPaths ?? Defaults.baseHeaderSearchPaths
    self.extraHeaderFolderNames = extraHeaderFolderNames ?? Defaults.extraHeaderFolderNames
    self.excludedHeaderPathSubstrings = excludedHeaderPathSubstrings ?? Defaults
      .excludedHeaderPathSubstrings
  }

  enum CodingKeys: String, CodingKey {
    case version
    case projectName
    case bundleIdPrefix
    case deploymentTargets
    case versionMacroName
    case skippedProductFolders
    case baseProduct
    case extraFiles
    case excludedProducts
    case extraProducts
    case products
    case renamedProducts
    case externalArtifacts
    case publicHeaderFolderNames
    case filterWrapperTargets
    case stripExternalBinaryCodeSignatures
    case suppressedInternalFrameworks
    case productPlatformOverrides
    case extraFrameworksPerProduct
    case targetArchitectures
    case enableModuleVerifier
    case buildSettings
    case targetPlatforms
    case wrapperTargetNames
    case wrapperTargetPatterns
    case wrapperSourceFolderNames
    case aggregatePackageNames
    case baseHeaderSearchPaths
    case extraHeaderFolderNames
    case excludedHeaderPathSubstrings
    case companionModuleSuffixes
    case stubFileNames
    case stubFilePatterns
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      version: container.decode(Version.self, forKey: .version),
      projectName: container.decode(String.self, forKey: .projectName),
      bundleIdPrefix: container.decode(String.self, forKey: .bundleIdPrefix),
      deploymentTargets: container.decodeIfPresent(.deploymentTargets),
      versionMacroName: container.decodeIfPresent(.versionMacroName),
      skippedProductFolders: container.decodeIfPresent(.skippedProductFolders),
      baseProduct: container.decodeIfPresent(.baseProduct),
      extraFiles: container.decodeIfPresent(.extraFiles),
      excludedProducts: container.decodeIfPresent(.excludedProducts),
      extraProducts: container.decodeIfPresent(.extraProducts),
      products: container.decodeIfPresent(.products),
      renamedProducts: container.decodeIfPresent(.renamedProducts),
      externalArtifacts: container.decodeIfPresent(.externalArtifacts),
      publicHeaderFolderNames: container.decodeIfPresent(.publicHeaderFolderNames),
      filterWrapperTargets: container.decodeIfPresent(.filterWrapperTargets),
      stripExternalBinaryCodeSignatures: container.decodeIfPresent(
        .stripExternalBinaryCodeSignatures
      ),
      suppressedInternalFrameworks: container.decodeIfPresent(.suppressedInternalFrameworks),
      productPlatformOverrides: container.decodeIfPresent(.productPlatformOverrides),
      extraFrameworksPerProduct: container.decodeIfPresent(.extraFrameworksPerProduct),
      targetArchitectures: container.decodeIfPresent(.targetArchitectures),
      enableModuleVerifier: container.decodeIfPresent(.enableModuleVerifier),
      buildSettings: container.decodeIfPresent(.buildSettings),
      targetPlatforms: container.decodeIfPresent(.targetPlatforms),
      wrapperTargetNames: container.decodeIfPresent(.wrapperTargetNames),
      wrapperTargetPatterns: container.decodeIfPresent(.wrapperTargetPatterns),
      wrapperSourceFolderNames: container.decodeIfPresent(.wrapperSourceFolderNames),
      aggregatePackageNames: container.decodeIfPresent(.aggregatePackageNames),
      baseHeaderSearchPaths: container.decodeIfPresent(.baseHeaderSearchPaths),
      extraHeaderFolderNames: container.decodeIfPresent(.extraHeaderFolderNames),
      excludedHeaderPathSubstrings: container.decodeIfPresent(.excludedHeaderPathSubstrings),
      companionModuleSuffixes: container.decodeIfPresent(.companionModuleSuffixes),
      stubFileNames: container.decodeIfPresent(.stubFileNames),
      stubFilePatterns: container.decodeIfPresent(.stubFilePatterns)
    )
  }
}

// MARK: - Nested Configuration Models

public extension Config {
  /// Configuration entry defining how a single product and its targets should be resolved and
  /// packaged in `products` or `extraProducts`.
  struct ProductEntry: Codable, Sendable, Equatable {
    /// Distribution folder name for the product in the final zip archive.
    ///
    /// - **Required**: Must be specified for each `ProductEntry`.
    ///
    /// ```json
    /// "name": "FirebaseABTesting"
    /// ```
    public let name: String

    /// Root SwiftPM target names that compose this product and seed its transitive dependency
    /// graph.
    ///
    /// - **Required**: Must be specified for each `ProductEntry`.
    /// - **Throws**: `PlanningError.targetNotFound` if a declared root target does not exist in the
    ///   resolved SwiftPM module graph.
    ///
    /// ```json
    /// "targets": [
    ///   "FirebaseABTesting"
    /// ]
    /// ```
    public let targets: [String]

    /// Additional `.xcframework` or system framework names to bundle into this product's folder
    /// even if not linked as direct SwiftPM dependencies.
    ///
    /// - **Optional**: Defaults to `nil` (`[]`).
    ///
    /// ```json
    /// "extraFrameworks": [
    ///   "FirebaseRemoteConfig",
    ///   "FirebaseSharedSwift"
    /// ]
    /// ```
    public let extraFrameworks: [String]?

    /// Explicit list of platforms supported by this product (`"ios"`, `"macos"`, `"tvos"`,
    /// `"watchos"`, `"visionos"`, `"catalyst"`), overriding automatic inference from
    /// `Package.swift`.
    ///
    /// - **Optional (Inferred)**: Defaults to `nil`. If omitted, supported platforms are inferred
    ///   from `Package.swift` by inspecting `.when(platforms: [...])` dependency conditions on the
    ///   product's `targets` (automatically including `"catalyst"` whenever `.iOS` is present), or
    ///   falling back to `["ios", "macos", "tvos", "watchos", "catalyst"]` when no platform
    ///   condition is declared.
    ///
    /// # Examples
    ///
    /// ## Package.swift
    /// ```swift
    /// .target(
    ///   name: "FirebaseAppDistributionTarget",
    ///   dependencies: [
    ///     .target(
    ///       name: "FirebaseAppDistribution",
    ///       condition: .when(platforms: [.iOS])
    ///     ),
    ///   ]
    /// )
    /// ```
    ///
    /// ## Config File
    ///
    /// ```json
    /// "platforms": [
    ///   "ios",
    ///   "catalyst"
    /// ]
    /// ```
    public let platforms: [Platform]?

    /// Target names within this product that must be compiled as dynamic frameworks (`mh_dylib`)
    /// instead of static frameworks.
    ///
    /// - **Optional**: Defaults to `nil` (`[]`).
    ///
    /// ```json
    /// "dynamicFrameworks": [
    ///   "FirebaseDynamicTarget"
    /// ]
    /// ```
    public let dynamicFrameworks: [String]?

    /// Target names of resource bundles to compile and embed inside the product's `.xcframework`
    /// slices.
    ///
    /// - **Optional**: Defaults to `nil` (`[]`).
    ///
    /// ```json
    /// "resourceBundles": [
    ///   "InAppMessagingDisplayResources"
    /// ]
    /// ```
    public let resourceBundles: [String]?

    /// Custom compiler flags keyed by target name to inject during Xcode project generation.
    ///
    /// - **Optional**: Defaults to `nil` (`[:]`).
    ///
    /// ```json
    /// "customCompilerFlags": {
    ///   "FirebaseCore": [
    ///     "-DFIRCore_MINOR_VERSION=18"
    ///   ]
    /// }
    /// ```
    public let customCompilerFlags: [String: [String]]?

    /// Initializes a product configuration entry.
    public init(name: String,
                targets: [String],
                extraFrameworks: [String]? = nil,
                platforms: [Platform]? = nil,
                dynamicFrameworks: [String]? = nil,
                resourceBundles: [String]? = nil,
                customCompilerFlags: [String: [String]]? = nil) {
      self.name = name
      self.targets = targets
      self.extraFrameworks = extraFrameworks
      self.platforms = platforms
      self.dynamicFrameworks = dynamicFrameworks
      self.resourceBundles = resourceBundles
      self.customCompilerFlags = customCompilerFlags
    }
  }
}

/// Configuration for consolidating foundational shared frameworks (such as `FirebaseCore` and
/// `GoogleUtilities`) into a single primary product folder rather than duplicating them across
/// every product directory.
public struct BaseProduct: Codable, Sendable, Equatable {
  /// Name of the primary base product directory where shared core frameworks are consolidated.
  /// Consumers are expected to link all frameworks in this folder alongside any other product
  /// folders they use.
  ///
  /// - **Required**: Must be specified when `baseProduct` is provided.
  ///
  /// ```json
  /// "product": "FirebaseAnalytics"
  /// ```
  public let product: String

  /// List of shared `.xcframework` names to place exclusively in the `product` directory and omit
  /// from all other downstream product folders that depend on them.
  ///
  /// - **Required**: Must be specified when `baseProduct` is provided.
  ///
  /// ```json
  /// "frameworks": [
  ///   "FirebaseCore",
  ///   "GoogleUtilities",
  ///   "nanopb",
  ///   "FBLPromises"
  /// ]
  /// ```
  public let frameworks: [String]

  /// Initializes base product distribution rules.
  public init(product: String, frameworks: [String]) {
    self.product = product
    self.frameworks = frameworks
  }
}

/// Definition of supplementary files, headers, module maps, or scripts bundled into the release
/// root or a specific product subfolder.
public struct ExtraFiles: Codable, Sendable, Equatable {
  /// Target directory path relative to the release root where the files will be copied.
  ///
  /// In `zip_builder.json`, this can be specified using either `"destination"` (for relative paths
  /// like `"."`) or `"product"` (as an alias for a product directory name).
  ///
  /// - **Optional**: Defaults to `"."` (the top-level release root) when both `"destination"` and
  ///   `"product"` are omitted.
  ///
  /// ```json
  /// {
  ///   "product": "FirebaseCrashlytics",
  ///   "files": [
  ///     "Crashlytics/run",
  ///     "Crashlytics/upload-symbols"
  ///   ]
  /// }
  /// ```
  public let destination: String

  /// Relative repository paths to files or scripts to copy into `destination`.
  ///
  /// - **Required**: Must be specified for each entry in `extraFiles`.
  ///
  /// ```json
  /// "files": [
  ///   "CoreOnly/NOTICES",
  ///   "CoreOnly/Sources/Firebase.h",
  ///   "CoreOnly/Sources/module.modulemap"
  /// ]
  /// ```
  public let files: [String]

  enum CodingKeys: String, CodingKey {
    case destination
    case product
    case files
  }

  /// Initializes an extra files specification with a destination path.
  /// - Parameters:
  ///   - destination: Subdirectory in release distribution (e.g. `FirebaseCrashlytics`, or `.` for
  /// root).
  ///   - files: Relative repo paths to files to copy.
  public init(destination: String = ".", files: [String]) {
    self.destination = destination
    self.files = files
  }

  /// Initializes an extra files specification with a product name.
  /// - Parameters:
  ///   - product: Product directory name where files should be copied.
  ///   - files: Relative repo paths to files to copy.
  public init(product: String, files: [String]) {
    destination = product
    self.files = files
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    files = try container.decode([String].self, forKey: .files)
    if let dest = try container.decodeIfPresent(String.self, forKey: .destination) {
      destination = dest
    } else if let prod = try container.decodeIfPresent(String.self, forKey: .product) {
      destination = prod
    } else {
      destination = "."
    }
  }

  /// Encodes this extra files specification into the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(destination, forKey: .destination)
    try container.encode(files, forKey: .files)
  }
}

/// Declaration for an external prebuilt `.zip` or binary artifact to download and bundle with a
/// product.
public struct ExternalArtifact: Codable, Sendable, Equatable {
  /// Product folder name in the distribution zip where the extracted artifact will be placed.
  ///
  /// - **Required**: Must be specified for each entry in `externalArtifacts`.
  ///
  /// ```json
  /// "productName": "GoogleSignIn"
  /// ```
  public let productName: String

  /// Remote download URL (`https://`) or local file URL (`file://`) for the prebuilt `.zip`
  /// archive.
  ///
  /// - **Required**: Must be specified for each entry in `externalArtifacts`.
  ///
  /// ```json
  /// "url": "https://dl.google.com/dl/firebase/ios/carthage/12.18.0/GoogleSignIn.zip"
  /// ```
  public let url: String

  /// Optional subdirectory path within the downloaded archive containing the `.xcframework`s or
  /// resources to copy.
  ///
  /// Useful when the upstream `.zip` wraps its frameworks inside a top-level folder instead of
  /// placing them at the archive root.
  ///
  /// - **Optional**: Defaults to `nil` (files are copied from the root of the archive).
  ///
  /// ```json
  /// "subpath": "GoogleSignIn"
  /// ```
  public let subpath: String?

  /// Initializes an external artifact declaration.
  public init(productName: String, url: String, subpath: String? = nil) {
    self.productName = productName
    self.url = url
    self.subpath = subpath
  }
}

public enum LoadConfigError: Error, CustomStringConvertible, Equatable {
  case missingProjectName
  case missingVersion
  case missingBundleIdPrefix
  case unknownPlatform(platform: String)

  public var description: String {
    switch self {
    case let .unknownPlatform(platform):
      return "Unknown platform specified '\(platform)'."
    case .missingProjectName:
      return "Project name could not be inferred from Package.swift and was not specified via CLI argument or configuration."
    case .missingVersion:
      return "Release version could not be inferred from Package.swift and was not specified via CLI argument or configuration."
    case .missingBundleIdPrefix:
      return "Bundle ID prefix was not specified via CLI argument or configuration."
    }
  }
}
