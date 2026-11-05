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

/// Unified build and plan resolution overrides populated from command-line arguments.
///
/// Any option provided via the CLI takes precedence over values configured in `zip_builder.json`
/// or inferred from `Package.swift`.
public struct BuildOptions: Sendable, Equatable {
  /// Overrides the semantic release version used for Xcode build settings, preprocessor macros,
  /// and naming the output archive (`<projectName>-<version>-latest.zip`).
  ///
  /// Passed via `--version <version>` on the CLI (automatically parsed from a semantic version
  /// string into `Version`), taking precedence over `zip_builder.json` and `Package.swift`.
  ///
  /// ```sh
  /// zip-builder build --version 12.18.0
  /// ```
  public let version: Version?

  /// Overrides the synthesized Xcode project name (`<projectName>.xcodeproj`) and release archive
  /// prefix.
  ///
  /// Passed via `--project-name <name>` on the CLI, taking precedence over `zip_builder.json` and
  /// the root package name in `Package.swift`.
  ///
  /// ```sh
  /// zip-builder build --project-name Firebase
  /// ```
  public let projectName: String?

  /// Overrides the reverse-DNS bundle identifier prefix used to construct
  /// `PRODUCT_BUNDLE_IDENTIFIER` (`<bundleIdPrefix>.<TargetName>`) for all generated frameworks
  /// and resource bundles.
  ///
  /// Passed via `--bundle-id-prefix <prefix>` on the CLI.
  ///
  /// ```sh
  /// zip-builder build --bundle-id-prefix com.google.firebase
  /// ```
  public let bundleIdPrefix: String?

  /// Restricts the Apple platforms to compile slices for and package into `.xcframework` bundles
  /// (`ios`, `macos`, `tvos`, `watchos`, `visionos`, `catalyst`).
  ///
  /// Passed via `--platforms <platform>` on the CLI (can be specified multiple times to build a
  /// subset of platforms).
  ///
  /// ```sh
  /// zip-builder build --platforms ios --platforms macos
  /// ```
  public let targetPlatforms: [Platform]?

  /// Scopes the build plan and packaging pipeline to a single product or target name and its
  /// transitive dependency graph.
  ///
  /// Passed via `-t <name>` or `--target <name>` on the CLI. Useful for fast local iteration or
  /// debugging a single module without building the entire repository.
  ///
  /// ```sh
  /// zip-builder build --target FirebaseAuth
  /// ```
  public let target: String?

  /// Controls whether synthetic SwiftPM wrapper targets (targets containing only dummy/stub files
  /// or platform-exclusion wrappers) are filtered out from `.xcframework` compilation.
  ///
  /// Wrapper filtering is enabled by default (`true`). Passing `--no-filter-wrapper-targets` on
  /// the CLI sets this override to `false` so wrapper targets are retained in the Xcode project.
  ///
  /// ```sh
  /// zip-builder build --no-filter-wrapper-targets
  /// ```
  public let filterWrapperTargets: Bool?

  /// Strips `_CodeSignature` directories from downloaded external binary `.xcframework` artifacts
  /// during packaging to prevent code-signing conflicts in consumer apps.
  ///
  /// Disabled by default (`false`). Passing `--strip-external-code-signatures` on the CLI sets
  /// this override to `true`.
  ///
  /// ```sh
  /// zip-builder build --strip-external-code-signatures
  /// ```
  public let stripExternalBinaryCodeSignatures: Bool?

  /// Enables Xcode's Clang/Swift module verifier (`ENABLE_MODULE_VERIFIER = YES`) on generated
  /// framework targets to validate module maps and public headers during compilation.
  ///
  /// Disabled by default (`false`). Passing `--enable-module-verifier` on the CLI sets this
  /// override to `true`.
  ///
  /// ```sh
  /// zip-builder build --enable-module-verifier
  /// ```
  public let enableModuleVerifier: Bool?

  /// Additional or overriding Xcode build settings injected into all generated native targets,
  /// merged on top of `buildSettings` from `zip_builder.json`.
  ///
  /// Passed via `-s <KEY=VALUE>` or `--build-setting <KEY=VALUE>` on the CLI (can be specified
  /// multiple times).
  ///
  /// ```sh
  /// zip-builder build \
  ///   -s SWIFT_OPTIMIZATION_LEVEL=-Onone \
  ///   --build-setting OTHER_SWIFT_FLAGS=-DDEBUG
  /// ```
  public let buildSettings: [String: String]?

  /// Overrides the supported compilation and packaging platforms per product or target name,
  /// replacing `productPlatformOverrides` in `zip_builder.json`.
  ///
  /// Note: Currently configurable via `zip_builder.json` or programmatic `BuildOptions`
  /// initialization (not exposed as a CLI flag).
  ///
  /// ```json
  /// "productPlatformOverrides": {
  ///   "FirebaseInAppMessaging": ["ios", "catalyst"]
  /// }
  /// ```
  public let productPlatformOverrides: [String: [Platform]]?

  /// Overrides the explicit target names treated as synthetic SwiftPM wrapper targets, replacing
  /// `wrapperTargetNames` in `zip_builder.json`.
  ///
  /// Note: Currently configurable via `zip_builder.json` or programmatic `BuildOptions`
  /// initialization (use `--wrapper-target-pattern` on the CLI to match target names).
  ///
  /// ```json
  /// "wrapperTargetNames": [
  ///   "Firebase"
  /// ]
  /// ```
  public let wrapperTargetNames: [String]?

  /// Overrides the wildcard (`*`) or suffix patterns used to identify synthetic SwiftPM wrapper
  /// targets by name, replacing `wrapperTargetPatterns` in `zip_builder.json`.
  ///
  /// Passed via `--wrapper-target-pattern <pattern>` on the CLI (can be specified multiple times).
  ///
  /// ```sh
  /// zip-builder build \
  ///   --wrapper-target-pattern "*Wrapper" \
  ///   --wrapper-target-pattern "*Wrap"
  /// ```
  public let wrapperTargetPatterns: [String]?

  /// Overrides the suffixes used to detect internal companion targets belonging to a parent module
  /// (so their public headers can be merged into the parent framework), replacing
  /// `companionModuleSuffixes` in `zip_builder.json`.
  ///
  /// Passed via `--companion-module-suffix <suffix>` on the CLI (can be specified multiple times).
  ///
  /// ```sh
  /// zip-builder build \
  ///   --companion-module-suffix Internal \
  ///   --companion-module-suffix ObjC \
  ///   --companion-module-suffix Swift
  /// ```
  public let companionModuleSuffixes: [String]?

  /// Overrides the exact source or header filenames recognized as empty dummy/stub files when
  /// identifying synthetic SwiftPM wrapper targets, replacing `stubFileNames` in
  /// `zip_builder.json`.
  ///
  /// Note: Currently configurable via `zip_builder.json` or programmatic `BuildOptions`
  /// initialization (not exposed as a CLI flag).
  ///
  /// ```json
  /// "stubFileNames": [
  ///   "dummy.m",
  ///   "dummy.h",
  ///   "empty.m",
  ///   "empty.h"
  /// ]
  /// ```
  public let stubFileNames: [String]?

  /// Overrides the wildcard (`*`) filename patterns recognized as dummy/stub files when
  /// identifying synthetic SwiftPM wrapper targets, replacing `stubFilePatterns` in
  /// `zip_builder.json`.
  ///
  /// Note: Currently configurable via `zip_builder.json` or programmatic `BuildOptions`
  /// initialization (not exposed as a CLI flag).
  ///
  /// ```json
  /// "stubFilePatterns": [
  ///   "*Wrapper.swift",
  ///   "*Wrap.swift"
  /// ]
  /// ```
  public let stubFilePatterns: [String]?

  /// Primary initializer with typed `Version`.
  public init(version: Version? = nil,
              projectName: String? = nil,
              bundleIdPrefix: String? = nil,
              targetPlatforms: [Platform]? = nil,
              target: String? = nil,
              filterWrapperTargets: Bool? = nil,
              stripExternalBinaryCodeSignatures: Bool? = nil,
              enableModuleVerifier: Bool? = nil,
              buildSettings: [String: String]? = nil,
              productPlatformOverrides: [String: [Platform]]? = nil,
              wrapperTargetNames: [String]? = nil,
              wrapperTargetPatterns: [String]? = nil,
              companionModuleSuffixes: [String]? = nil,
              stubFileNames: [String]? = nil,
              stubFilePatterns: [String]? = nil) {
    self.version = version
    self.projectName = projectName
    self.bundleIdPrefix = bundleIdPrefix
    self.targetPlatforms = targetPlatforms
    self.target = target
    self.filterWrapperTargets = filterWrapperTargets
    self.stripExternalBinaryCodeSignatures = stripExternalBinaryCodeSignatures
    self.enableModuleVerifier = enableModuleVerifier
    self.buildSettings = buildSettings
    self.productPlatformOverrides = productPlatformOverrides
    self.wrapperTargetNames = wrapperTargetNames
    self.wrapperTargetPatterns = wrapperTargetPatterns
    self.companionModuleSuffixes = companionModuleSuffixes
    self.stubFileNames = stubFileNames
    self.stubFilePatterns = stubFilePatterns
  }

  /// Convenience initializer accepting version as a non-optional string.
  public init(versionString: String,
              projectName: String? = nil,
              bundleIdPrefix: String? = nil,
              targetPlatforms: [Platform]? = nil,
              target: String? = nil,
              filterWrapperTargets: Bool? = nil,
              stripExternalBinaryCodeSignatures: Bool? = nil,
              enableModuleVerifier: Bool? = nil,
              buildSettings: [String: String]? = nil,
              productPlatformOverrides: [String: [Platform]]? = nil,
              wrapperTargetNames: [String]? = nil,
              wrapperTargetPatterns: [String]? = nil,
              companionModuleSuffixes: [String]? = nil,
              stubFileNames: [String]? = nil,
              stubFilePatterns: [String]? = nil) {
    let parsedVersion = try? Version(versionString: versionString, usesLenientParsing: true)
    self.init(
      version: parsedVersion,
      projectName: projectName,
      bundleIdPrefix: bundleIdPrefix,
      targetPlatforms: targetPlatforms,
      target: target,
      filterWrapperTargets: filterWrapperTargets,
      stripExternalBinaryCodeSignatures: stripExternalBinaryCodeSignatures,
      enableModuleVerifier: enableModuleVerifier,
      buildSettings: buildSettings,
      productPlatformOverrides: productPlatformOverrides,
      wrapperTargetNames: wrapperTargetNames,
      wrapperTargetPatterns: wrapperTargetPatterns,
      companionModuleSuffixes: companionModuleSuffixes,
      stubFileNames: stubFileNames,
      stubFilePatterns: stubFilePatterns
    )
  }

  /// Whether any option or override differs from standard default resolution.
  public var hasOverrides: Bool {
    version != nil ||
      projectName != nil ||
      bundleIdPrefix != nil ||
      targetPlatforms != nil ||
      filterWrapperTargets != nil ||
      stripExternalBinaryCodeSignatures != nil ||
      enableModuleVerifier != nil ||
      (buildSettings != nil && !buildSettings!.isEmpty) ||
      productPlatformOverrides != nil ||
      (wrapperTargetNames != nil && !wrapperTargetNames!.isEmpty) ||
      (wrapperTargetPatterns != nil && !wrapperTargetPatterns!.isEmpty) ||
      (companionModuleSuffixes != nil && !companionModuleSuffixes!.isEmpty) ||
      stubFileNames != nil ||
      stubFilePatterns != nil
  }
}
