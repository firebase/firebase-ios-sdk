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

import ArgumentParser
import Common
import Foundation

/// Shared command-line options for locating and configuring a SwiftPM package manifest.
public struct ManifestOptions: ParsableArguments, Sendable {
  /// Path to repository root directory containing `Package.swift`.
  @Option(name: .shortAndLong, help: "Path to Package.swift directory.")
  public var packagePath: String = "."

  /// Optional file path to custom `zip_builder.jsonc` or `zip_builder.json` configuration file.
  @Option(name: .shortAndLong, help: "Optional path to JSON/JSONC configuration file.")
  public var config: String? = nil

  /// Optional project name override.
  @Option(name: .long, help: "Override the project name to use.")
  public var projectName: String? = nil

  /// Optional release version override.
  @Option(name: .long, help: "Override the release version to use.")
  public var version: String? = nil

  /// Optional bundle ID prefix override.
  @Option(name: .long, help: "Override the bundle ID prefix to use.")
  public var bundleIdPrefix: String? = nil

  /// Whether to strip _CodeSignature from downloaded external binary artifacts.
  @Flag(
    name: .customLong("strip-external-code-signatures"),
    help: "Strip _CodeSignature directories from downloaded external binary artifacts."
  )
  public var stripExternalBinaryCodeSignatures: Bool = false

  /// Whether to disable filtering of internal SPM wrapper targets.
  @Flag(
    name: .customLong("no-filter-wrapper-targets"),
    help: "Disable filtering of internal SPM wrapper targets from release packaging."
  )
  public var noFilterWrapperTargets: Bool = false

  /// Whether to enable Xcode module verifier (ENABLE_MODULE_VERIFIER).
  @Flag(
    name: .customLong("enable-module-verifier"),
    help: "Enable Xcode module verifier (ENABLE_MODULE_VERIFIER) during project generation and archiving."
  )
  public var enableModuleVerifier: Bool = false

  /// Suffix or wildcard patterns for identifying wrapper targets.
  @Option(
    name: .customLong("wrapper-target-pattern"),
    help: "Wildcard or suffix patterns for identifying wrapper targets (e.g. '*Wrapper', '*Wrap'). Can be specified multiple times."
  )
  public var wrapperTargetPatterns: [String] = []

  /// Suffix patterns used to identify companion internal modules.
  @Option(
    name: .customLong("companion-module-suffix"),
    help: "Suffix patterns used to identify companion internal modules (e.g. 'Internal', 'ObjC', 'Swift'). Can be specified multiple times."
  )
  public var companionModuleSuffixes: [String] = []

  /// Additional Xcode build settings in KEY=VALUE format.
  @Option(
    name: [.customLong("build-setting"), .customShort("s")],
    parsing: .unconditionalSingleValue,
    help: "Additional Xcode build setting in KEY=VALUE format (e.g. -s SWIFT_OPTIMIZATION_LEVEL=-Onone). Can be specified multiple times. Overrides default settings."
  )
  public var buildSettings: [String] = []

  /// Parses `buildSettings` array into key-value pairs.
  public func parsedBuildSettings() -> [String: String] {
    var result: [String: String] = [:]

    for setting in buildSettings {
      let parts = setting.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      let key = parts[0].trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty else { continue }

      let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
      result[key] = value
    }

    return result
  }

  /// Creates a unified `BuildOptions` instance combining manifest, platform, and target options.
  public func buildOptions(platformOptions: PlatformOptions? = nil,
                           targetOptions: TargetOptions? = nil) throws -> BuildOptions {
    let parsedSettings = parsedBuildSettings()
    let parsedVersion = try version.map {
      try Version(versionString: $0, usesLenientParsing: true)
    }

    return BuildOptions(
      version: parsedVersion,
      projectName: projectName,
      bundleIdPrefix: bundleIdPrefix,
      targetPlatforms: platformOptions?.platforms,
      target: targetOptions?.target,
      filterWrapperTargets: noFilterWrapperTargets ? false : nil,
      stripExternalBinaryCodeSignatures: stripExternalBinaryCodeSignatures ? true : nil,
      enableModuleVerifier: enableModuleVerifier ? true : nil,
      buildSettings: parsedSettings.isEmpty ? nil : parsedSettings,
      wrapperTargetPatterns: wrapperTargetPatterns.isEmpty ? nil : wrapperTargetPatterns,
      companionModuleSuffixes: companionModuleSuffixes.isEmpty ? nil : companionModuleSuffixes
    )
  }

  public init() {}
}

/// Shared command-line options for consuming a pre-resolved `BuildPlan` artifact.
public struct PlanOptions: ParsableArguments, Sendable {
  /// Optional path to a pre-resolved build plan JSON file (from a previous `plan` run).
  @Option(name: .long, help: "Optional path to a JSON build plan file.")
  public var plan: String? = nil

  /// URL pointing to the plan file if specified.
  public var planURL: URL? {
    plan.map { URL(filePath: $0) }
  }

  public init() {}
}

/// Shared command-line options for selecting target compilation platforms.
public struct PlatformOptions: ParsableArguments, Sendable {
  /// Target platforms to compile and package.
  @Option(
    name: .long,
    help: "Target platforms to build."
  )
  public var platforms: [Platform] = [.ios, .macos, .tvos, .watchos, .catalyst]

  public init() {}
}

/// Shared command-line options for targeting a specific product or target.
public struct TargetOptions: ParsableArguments, Sendable {
  /// Specific product or target to build/package (e.g. `FirebaseCore`). If omitted, all products
  /// are processed.
  @Option(
    name: .shortAndLong,
    help: "Specific product or target to process (e.g. FirebaseCore). By default, all products are included."
  )
  public var target: String? = nil

  public init() {}
}

extension Platform: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(rawValue: argument)
  }
}
