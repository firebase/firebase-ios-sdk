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

/// The top-level build and packaging plan coordinating the compilation and distribution of all
/// Firebase SDKs.
public struct BuildPlan: Codable, Sendable, Equatable {
  /// Unified configuration for the release build.
  public let config: Config
  /// All resolved product plans to build and package.
  public let products: [ProductPlan]
  /// Helper and aggregate submodules required for umbrella headers and module maps.
  public let aggregatedSubmodules: [TargetDefinition]
  /// Search paths for prebuilt binary xcframeworks.
  public let frameworkSearchPaths: [String]

  // MARK: - Initializers

  /// Primary initializer from a resolved `Config` and build outputs.
  public init(config: Config,
              products: [ProductPlan],
              aggregatedSubmodules: [TargetDefinition] = [],
              frameworkSearchPaths: [String] = []) {
    self.config = config
    self.products = products
    self.aggregatedSubmodules = aggregatedSubmodules
    self.frameworkSearchPaths = frameworkSearchPaths
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case config
    case products
    case aggregatedSubmodules
    case frameworkSearchPaths
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let config = try container.decode(Config.self, forKey: .config)
    let products = try container.decode([ProductPlan].self, forKey: .products)
    let aggregatedSubmodules = try container.decodeIfPresent(
      [TargetDefinition].self,
      forKey: .aggregatedSubmodules
    ) ?? []
    let frameworkSearchPaths = try container.decodeIfPresent(
      [String].self,
      forKey: .frameworkSearchPaths
    ) ?? []

    self.init(
      config: config,
      products: products,
      aggregatedSubmodules: aggregatedSubmodules,
      frameworkSearchPaths: frameworkSearchPaths
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(config, forKey: .config)
    try container.encode(products, forKey: .products)
    try container.encode(aggregatedSubmodules, forKey: .aggregatedSubmodules)
    try container.encode(frameworkSearchPaths, forKey: .frameworkSearchPaths)
  }

  /// Loads and decodes a `BuildPlan` from a file URL.
  /// - Parameter url: File URL pointing to the JSON plan file.
  /// - Returns: Decoded `BuildPlan` instance.
  /// - Throws: An error if file reading or JSON decoding fails.
  public static func load(from url: URL) throws -> BuildPlan {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(BuildPlan.self, from: data)
  }

  /// Encodes and writes this `BuildPlan` as formatted JSON to the specified file URL.
  /// - Parameter url: Destination file URL.
  /// - Throws: An error if JSON encoding or file writing fails.
  public func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(self)
    try data.write(to: url)
  }
}

/// Represents the complete resolution plan for a single distribution product.
public struct ProductPlan: Codable, Sendable, Equatable {
  /// Name of the product (e.g. `FirebaseFirestore`).
  public let name: String
  /// Source-compiled targets that must be built for this product.
  public let targets: [TargetDefinition]
  /// Prebuilt binary targets associated with this product.
  public let binaryTargets: [TargetDefinition]
  /// Extra frameworks required by the product.
  public let extraFrameworks: [String]
  /// Declared root target names.
  public let declaredTargetNames: [String]
  /// Supported Apple platforms for this product.
  public let platforms: [Platform]
  /// Target names that should be compiled as dynamic frameworks.
  public let dynamicFrameworks: [String]
  /// Resource bundles to package.
  public let resourceBundles: [String]
  /// Custom compiler flags per target.
  public let customCompilerFlags: [String: [String]]

  /// Initializes a product plan.
  public init(name: String,
              targets: [TargetDefinition],
              binaryTargets: [TargetDefinition] = [],
              extraFrameworks: [String] = [],
              declaredTargetNames: [String] = [],
              platforms: [Platform] = [.ios, .macos, .tvos, .watchos, .catalyst],
              dynamicFrameworks: [String] = [],
              resourceBundles: [String] = [],
              customCompilerFlags: [String: [String]] = [:]) {
    self.name = name
    self.targets = targets
    self.binaryTargets = binaryTargets
    self.extraFrameworks = extraFrameworks
    self.declaredTargetNames = declaredTargetNames
    self.platforms = platforms
    self.dynamicFrameworks = dynamicFrameworks
    self.resourceBundles = resourceBundles
    self.customCompilerFlags = customCompilerFlags
  }

  /// Determines whether a product is a wrapper / alias product whose declared root targets are all
  /// wrappers.
  public func isWrapperProduct(filterWrapperTargets: Bool) -> Bool {
    guard binaryTargets.isEmpty else { return false }
    if !declaredTargetNames.isEmpty {
      let declaredTargets = targets.filter { declaredTargetNames.contains($0.name) }
      return !declaredTargets.isEmpty && declaredTargets
        .allSatisfy { $0.isWrapper(filterWrapperTargets: filterWrapperTargets) }
    }
    return !targets.isEmpty && targets
      .allSatisfy { $0.isWrapper(filterWrapperTargets: filterWrapperTargets) }
  }

  /// Determines whether a product is a wrapper product using default wrapper filtering rules.
  public var isWrapperProduct: Bool {
    isWrapperProduct(filterWrapperTargets: true)
  }
}

/// Represents a single module/target definition resolved from the SwiftPM package graph.
public struct TargetDefinition: Codable, Sendable, Equatable {
  /// Target identifier name (e.g., `FirebaseCore`, `GoogleUtilities`).
  public let name: String
  /// C99 identifier equivalent of the target name (with hyphens replaced by underscores).
  public let c99name: String
  /// Whether this target is a pre-compiled binary xcframework artifact rather than compiled from
  /// source.
  public let isBinary: Bool
  /// File system path to the prebuilt binary xcframework if `isBinary` is true.
  public let binaryPath: String?
  /// All source and header file paths belonging to this target.
  public let sources: [String]
  /// Direct module dependency target names.
  public let dependencies: [String]
  /// Transitive recursive module dependency target names.
  public let recursiveDependencies: [String]
  /// Resource definitions (e.g., `PrivacyInfo.xcprivacy`) declared for this target.
  public let resources: [ResourceDefinition]
  /// C and Objective-C compiler flags extracted from SPM build settings assignments.
  public let cSettings: [String]
  /// Swift compiler flags and compilation conditions.
  public let swiftSettings: [String]
  /// Cleaned include and header search paths (`-I`) for compiling this target.
  public let headerSearchPaths: [String]
  /// Public header search paths exported to dependent targets.
  public let exportedHeaderSearchPaths: [String]
  /// Relative subfolder containing public headers if defined (e.g. `Public`, `include`).
  public let publicHeadersPath: String?
  /// Linker flags extracted from build settings (e.g., `framework:Security`, `library:z`).
  public let linkerSettings: [String]
  /// Whether this target is a synthetic wrapper, intermediate SPM glue, or forwarder target
  /// that should not be packaged into the release distribution as a standalone framework.
  public let isWrapper: Bool

  /// Initializes a target definition.
  public init(name: String,
              c99name: String,
              isBinary: Bool,
              binaryPath: String? = nil,
              sources: [String] = [],
              dependencies: [String] = [],
              recursiveDependencies: [String] = [],
              resources: [ResourceDefinition] = [],
              cSettings: [String] = [],
              swiftSettings: [String] = [],
              headerSearchPaths: [String] = [],
              exportedHeaderSearchPaths: [String] = [],
              publicHeadersPath: String? = nil,
              linkerSettings: [String] = [],
              isWrapper: Bool = false) {
    self.name = name
    self.c99name = c99name
    self.isBinary = isBinary
    self.binaryPath = binaryPath
    self.sources = sources
    self.dependencies = dependencies
    self.recursiveDependencies = recursiveDependencies
    self.resources = resources
    self.cSettings = cSettings
    self.swiftSettings = swiftSettings
    self.headerSearchPaths = headerSearchPaths
    self.exportedHeaderSearchPaths = exportedHeaderSearchPaths
    self.publicHeadersPath = publicHeadersPath
    self.linkerSettings = linkerSettings
    self.isWrapper = isWrapper
  }

  /// Determines whether a target is a synthetic wrapper, optionally respecting the
  /// filterWrapperTargets setting.
  public func isWrapper(filterWrapperTargets: Bool) -> Bool {
    guard !isBinary else { return false }
    return filterWrapperTargets && isWrapper
  }

  /// Returns a copy of this target definition with updated header search paths.
  public func updatingHeaderSearchPaths(_ newHeaderSearchPaths: [String],
                                        exportedHeaderSearchPaths: [String]? = nil)
    -> TargetDefinition {
    TargetDefinition(
      name: name,
      c99name: c99name,
      isBinary: isBinary,
      binaryPath: binaryPath,
      sources: sources,
      dependencies: dependencies,
      recursiveDependencies: recursiveDependencies,
      resources: resources,
      cSettings: cSettings,
      swiftSettings: swiftSettings,
      headerSearchPaths: newHeaderSearchPaths,
      exportedHeaderSearchPaths: exportedHeaderSearchPaths ?? self.exportedHeaderSearchPaths,
      publicHeadersPath: publicHeadersPath,
      linkerSettings: linkerSettings,
      isWrapper: isWrapper
    )
  }

  /// Creates a unified aggregate `TargetDefinition` from multiple subtargets, combining their
  /// sources, resources, compiler flags, linker flags, and external dependencies.
  ///
  /// Dependencies referencing any of the subtargets internally are filtered out so that only
  /// true external dependencies remain on the aggregated target.
  public static func aggregate(name: String,
                               subtargets: [TargetDefinition],
                               headerSearchPaths: [String] = [],
                               exportedHeaderSearchPaths: [String] = [],
                               publicHeadersPath: String? = "Public") -> TargetDefinition {
    let internalNames = Set(subtargets.map(\.name) + subtargets.map(\.c99name))
    var sources: [String] = []
    var resources: [ResourceDefinition] = []
    var cSettings: [String] = []
    var linkerSettings = Set<String>()
    var dependencies = Set<String>()
    var recursiveDependencies = Set<String>()

    for target in subtargets {
      for src in target.sources where !sources.contains(src) {
        sources.append(src)
      }
      for res in target.resources where !resources.contains(where: { $0.path == res.path }) {
        resources.append(res)
      }
      for setting in target.cSettings where !cSettings.contains(setting) {
        cSettings.append(setting)
      }
      linkerSettings.formUnion(target.linkerSettings)
      dependencies.formUnion(target.dependencies.filter { !internalNames.contains($0) })
      recursiveDependencies
        .formUnion(target.recursiveDependencies.filter { !internalNames.contains($0) })
    }

    let combinedExported = exportedHeaderSearchPaths.isEmpty
      ? Array(Set(subtargets.flatMap(\.exportedHeaderSearchPaths))).sorted()
      : exportedHeaderSearchPaths

    return TargetDefinition(
      name: name,
      c99name: name.replacingOccurrences(of: "-", with: "_"),
      isBinary: false,
      sources: sources,
      dependencies: Array(dependencies).sorted(),
      recursiveDependencies: Array(recursiveDependencies).sorted(),
      resources: resources,
      cSettings: cSettings,
      swiftSettings: [],
      headerSearchPaths: headerSearchPaths,
      exportedHeaderSearchPaths: combinedExported,
      publicHeadersPath: publicHeadersPath,
      linkerSettings: Array(linkerSettings).sorted(),
      isWrapper: false
    )
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case name
    case c99name
    case isBinary
    case binaryPath
    case sources
    case dependencies
    case recursiveDependencies
    case resources
    case cSettings
    case swiftSettings
    case headerSearchPaths
    case exportedHeaderSearchPaths
    case publicHeadersPath
    case linkerSettings
    case isWrapper
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    c99name = try container.decode(String.self, forKey: .c99name)
    isBinary = try container.decode(Bool.self, forKey: .isBinary)
    binaryPath = try container.decodeIfPresent(String.self, forKey: .binaryPath)
    sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
    dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies) ?? []
    recursiveDependencies = try container.decodeIfPresent(
      [String].self,
      forKey: .recursiveDependencies
    ) ?? []
    resources = try container.decodeIfPresent([ResourceDefinition].self, forKey: .resources) ?? []
    cSettings = try container.decodeIfPresent([String].self, forKey: .cSettings) ?? []
    swiftSettings = try container.decodeIfPresent([String].self, forKey: .swiftSettings) ?? []
    headerSearchPaths = try container.decodeIfPresent([String].self, forKey: .headerSearchPaths) ??
      []
    exportedHeaderSearchPaths = try container.decodeIfPresent(
      [String].self,
      forKey: .exportedHeaderSearchPaths
    ) ?? []
    publicHeadersPath = try container.decodeIfPresent(String.self, forKey: .publicHeadersPath)
    linkerSettings = try container.decodeIfPresent([String].self, forKey: .linkerSettings) ?? []
    isWrapper = try container.decodeIfPresent(Bool.self, forKey: .isWrapper) ?? false
  }
}

/// Represents a resource file or bundle associated with a target (e.g., privacy manifests,
/// storyboards, asset catalogs).
public struct ResourceDefinition: Codable, Sendable, Equatable, Hashable {
  /// The file basename of the resource.
  public let name: String
  /// Absolute or repository-relative path to the resource file on disk.
  public let path: String
  /// The resource rule type (e.g. `process` or `copy`).
  public let rule: String

  /// Initializes a resource definition.
  /// - Parameters:
  ///   - name: The resource name (e.g. `PrivacyInfo.xcprivacy`).
  ///   - path: The file path to the resource asset.
  ///   - rule: SPM resource processing rule.
  public init(name: String, path: String, rule: String) {
    self.name = name
    self.path = path
    self.rule = rule
  }
}
