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

import Common
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// Context providing package graph lookups, aggregate mappings, and configuration
/// during target and product resolution.
public struct ResolutionContext: @unchecked Sendable {
  /// The resolved SwiftPM package graph.
  public let graph: ModulesGraph
  /// The top-level product configuration options.
  public let config: Config
  /// Absolute path to the repository root directory.
  public let repoRoot: String
  /// Root directory paths for all packages in the graph.
  public let packageRoots: [String]
  /// Map of module names to their corresponding `ResolvedModule` instances.
  public let modulesMap: [String: ResolvedModule]
  /// Pre-computed aggregate target definitions (e.g. `GoogleUtilities`).
  public let aggregates: [String: TargetDefinition]
  /// Mapping from fine-grained subtarget names to parent aggregate target names.
  public let subtargetMap: [String: String]
  /// Recognized directory names containing public headers.
  public let publicHeaderFolders: [String]

  /// Initializes a resolution context.
  public init(graph: ModulesGraph,
              config: Config,
              repoRoot: String,
              packageRoots: [String],
              modulesMap: [String: ResolvedModule]? = nil,
              aggregates: [String: TargetDefinition],
              subtargetMap: [String: String],
              publicHeaderFolders: [String]? = nil) {
    self.graph = graph
    self.config = config
    self.repoRoot = repoRoot
    self.packageRoots = packageRoots
    self.modulesMap = modulesMap ?? graph.reachableModules.keyedBy(\.name)
    self.aggregates = aggregates
    self.subtargetMap = subtargetMap
    self.publicHeaderFolders = publicHeaderFolders ?? config.publicHeaderFolderNames
  }

  /// Maps a target name to its parent aggregate target if one exists, or returns the original name.
  ///
  /// ```swift
  /// mappedTargetName(for: "GULEnvironment") // -> "GoogleUtilities"
  /// mappedTargetName(for: "FirebaseAuth")   // -> "FirebaseAuth" (unchanged)
  /// ```
  public func mappedTargetName(for rawName: String) -> String {
    subtargetMap[rawName] ?? rawName
  }

  /// Looks up a `ResolvedModule` by target name (resolving aggregate mappings first).
  ///
  /// Resolves submodule aliases before querying `modulesMap`:
  /// ```swift
  /// // Maps "GULEnvironment" -> "GoogleUtilities", then returns the ResolvedModule for
  /// GoogleUtilities:
  /// context.module(named: "GULEnvironment")
  ///
  /// // Directly returns the ResolvedModule for FirebaseAuth:
  /// context.module(named: "FirebaseAuth")
  ///
  /// // Returns nil if the target does not exist in the package graph:
  /// context.module(named: "UnknownTarget") // -> nil
  /// ```
  public func module(named targetName: String) -> ResolvedModule? {
    let mapped = mappedTargetName(for: targetName)

    return modulesMap[mapped]
  }

  /// Looks up an aggregate `TargetDefinition` by target name.
  ///
  /// Resolves submodule aliases and returns the combined aggregate target containing all merged
  /// source files, headers, and build settings:
  /// ```swift
  /// // Returns the combined GoogleUtilities TargetDefinition:
  /// context.aggregate(named: "GULEnvironment")
  /// context.aggregate(named: "GoogleUtilities")
  ///
  /// // Returns nil for regular non-aggregate targets:
  /// context.aggregate(named: "FirebaseFirestore") // -> nil
  /// ```
  public func aggregate(named targetName: String) -> TargetDefinition? {
    let mapped = mappedTargetName(for: targetName)

    return aggregates[mapped]
  }

  /// Resolves the platforms for a product entry, taking into account configured overrides, explicit
  /// entry platforms, graph-inferred platforms, and an optional global platform filter.
  public func platforms(for entry: Config.ProductEntry,
                        filter: [Common.Platform]? = nil) -> [Common.Platform] {
    let inferred = config.productPlatformOverrides[entry.name] ?? entry.platforms ?? ProductResolver
      .inferPlatforms(
        forTargetNames: entry.targets,
        context: self
      )
    if let filter {
      return inferred.filter(filter.contains)
    }

    return inferred
  }

  /// Resolves extra frameworks for a product entry, combining global product-level configuration
  /// and entry-specific frameworks.
  public func extraFrameworks(for entry: Config.ProductEntry) -> [String] {
    (config.extraFrameworksPerProduct[entry.name] ?? []) + (entry.extraFrameworks ?? [])
  }

  /// Evaluates whether a target name represents an internal companion or suppressed framework.
  ///
  /// Checks against `config.companionModuleSuffixes` (default `["Internal"]`) and
  /// `config.suppressedInternalFrameworks`:
  /// ```swift
  /// context.isInternalCompanion(named: "FirebaseCoreInternal") // -> true (matches "Internal"
  /// suffix)
  /// context.isInternalCompanion(named: "FirebaseAuth")         // -> false
  /// ```
  public func isInternalCompanion(named targetName: String) -> Bool {
    let mapped = mappedTargetName(for: targetName)
    if config.suppressedInternalFrameworks.containsAny(targetName, mapped) {
      return true
    }

    return config.companionModuleSuffixes.contains { suffix in
      targetName.hasSuffix(suffix) || mapped.hasSuffix(suffix)
    }
  }

  /// Evaluates whether a dependency target should expose its full internal header search paths
  /// to dependent targets rather than only public exported include directories.
  ///
  /// Standard dependencies only expose public exported headers to maintain modular encapsulation,
  /// whereas internal companions (e.g. `FirebaseCoreInternal`) and wrappers must expose
  /// private/internal directories so dependent targets can access non-public shared headers.
  public func shouldExposeInternalHeaders(forDependency name: String,
                                          module: ResolvedModule? = nil) -> Bool {
    if isInternalCompanion(named: name) {
      return true
    }

    // check if it's a wrapper target
    let mapped = mappedTargetName(for: name)
    guard let module = module ?? self.module(named: mapped) ?? self.module(named: name) else {
      // if no module exists, check wrapper target names and patterns
      return config.wrapperTargetNames.containsAny(name, mapped)
        || config.wrapperTargetPatterns.contains(where: name.matchesWildcard)
        || config.wrapperTargetPatterns.contains(where: mapped.matchesWildcard)
    }
    return TargetClassifier.isWrapperTarget(
      name: module.name,
      isBinary: module.isBinary,
      sources: module.sources.paths.map(\.pathString),
      config: config
    )
  }
}
