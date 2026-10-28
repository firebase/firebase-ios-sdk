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
import Logging
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// High-level coordinator that resolves a comprehensive `BuildPlan` from a SwiftPM package graph.
public enum BuildPlanResolver: Sendable {
  private static let logger = Logger(label: "zip-builder.build-plan-resolver")

  /// Resolves the full `BuildPlan` from the loaded SwiftPM module graph and configuration.
  ///
  /// - Parameters:
  ///   - graph: Resolved SwiftPM modules graph.
  ///   - config: Configuration file to use.
  ///   - options: Optional build options.
  /// - Returns: Completely resolved `BuildPlan`.
  /// - Throws: An error if version, dependency resolution, or target filtering fails.
  public static func resolveBuildPlan(from graph: ModulesGraph,
                                      config: Config,
                                      options: BuildOptions? = nil) throws -> BuildPlan {
    logger.info("Resolving build plan from module graph...")
    let repoRoot = graph.rootPackages.first?.path.pathString ?? ""
    var packageRoots = repoRoot.isEmpty ? [] : [repoRoot]
    for package in graph.packages {
      let path = package.path.pathString
      if !packageRoots.contains(path) {
        packageRoots.append(path)
      }
    }

    let effectiveConfig = options.map { ConfigResolver.apply(options: $0, to: config) } ?? config

    logger.debug(
      "Resolved project metadata", metadata: [
        "name": "\(effectiveConfig.projectName)",
        "version": "\(effectiveConfig.version)",
        "bundleIdPrefix": "\(effectiveConfig.bundleIdPrefix)",
        "targetPlatforms": "\(effectiveConfig.targetPlatforms.map(\.canonicalName).joined(separator: ", "))",
      ]
    )

    let (aggregates, subtargetMap, submodules) = try resolveAggregates(
      from: graph,
      config: effectiveConfig
    )

    let context = ResolutionContext(
      graph: graph,
      config: effectiveConfig,
      repoRoot: repoRoot,
      packageRoots: packageRoots,
      aggregates: aggregates,
      subtargetMap: subtargetMap
    )

    var productPlans = try resolveProductPlans(
      context: context,
      targetPlatforms: effectiveConfig.targetPlatforms
    )

    if let target = options?.target {
      logger.info("Filtering build plan for target/product", metadata: ["target": "\(target)"])
      productPlans = PlanningEngine.filterProductPlans(productPlans, for: target)
      guard !productPlans.isEmpty else {
        logger.error(
          "Target or product not found in build plan",
          metadata: ["target": "\(target)"]
        )
        throw PlanningError.targetNotFound(target)
      }
    }

    let frameworkSearchPaths = collectFrameworkSearchPaths(from: graph)

    logger.debug(
      "Build plan resolved",
      metadata: [
        "productCount": "\(productPlans.count)",
        "searchPathCount": "\(frameworkSearchPaths.count)",
      ]
    )

    return BuildPlan(
      config: effectiveConfig,
      products: productPlans,
      aggregatedSubmodules: submodules,
      frameworkSearchPaths: frameworkSearchPaths
    )
  }

  // MARK: - Private Helpers

  /// Resolves all `ProductPlan` instances across explicit and discovered package products.
  private static func resolveProductPlans(context: ResolutionContext,
                                          targetPlatforms: [Common.Platform]? = nil) throws
    -> [ProductPlan] {
    let entries = discoverProductEntries(context: context)
    return try entries.compactMap { entry in
      let platforms = context.platforms(for: entry, filter: targetPlatforms)
      guard !platforms.isEmpty else {
        logger.debug(
          "Excluding product with no matching platforms",
          metadata: ["product": "\(entry.name)"]
        )
        return nil
      }

      return try ProductResolver.resolveProduct(
        platforms: platforms,
        entry: entry,
        context: context
      )
    }
  }

  /// Discovers all configured and graph-defined `ProductEntry`s, filtering out exclusions and
  /// duplicates.
  private static func discoverProductEntries(context: ResolutionContext) -> [Config.ProductEntry] {
    let excludedSet = Set(context.config.excludedProducts)
    var entries: [Config.ProductEntry] = []
    var seenNames = Set<String>()

    func addEntry(_ entry: Config.ProductEntry) {
      guard !excludedSet.contains(entry.name), !seenNames.contains(entry.name) else { return }
      seenNames.insert(entry.name)
      entries.append(entry)
    }

    if let explicitProducts = context.config.products, !explicitProducts.isEmpty {
      for productConfig in explicitProducts {
        addEntry(productConfig)
      }
    } else {
      let rootProductNames = Set(context.graph.rootPackages.flatMap(\.products).map(\.name))
      let targetProducts = context.graph.reachableProducts.filter {
        rootProductNames.contains($0.name)
      }
      for product in targetProducts {
        guard case .library = product.type else { continue }
        let targetNames = product.modules.map(\.name)
        let resolvedName = context.config.renamedProducts[product.name] ?? product.name
        addEntry(Config.ProductEntry(name: resolvedName, targets: targetNames))
      }
    }

    for extraConfig in context.config.extraProducts {
      addEntry(extraConfig)
    }

    return entries
  }

  /// Collects parent directory paths for binary xcframework targets to provide framework search
  /// paths.
  ///
  /// SwiftPM represents binary targets with `sources.root` pointing to the `.xcframework` or
  /// `.framework` bundle itself. However, Xcode's `FRAMEWORK_SEARCH_PATHS` (and compiler `-F`
  /// flags)
  /// requires the directory that *contains* the framework bundle, rather than the bundle itself,
  /// in order to resolve `#import <Foo/Foo.h>` and `-framework Foo`.
  ///
  /// This collects the unique parent directories of all reachable binary targets so Xcode can
  /// locate and link them during compilation.
  private static func collectFrameworkSearchPaths(from graph: ModulesGraph) -> [String] {
    let paths = Set(graph.reachableModules.filter(\.isBinary).map(
      \.sources.root.parentDirectory.pathString
    ))
    return paths.sorted()
  }

  // MARK: - Package Aggregation

  /// Discovers external modular packages (such as `GoogleUtilities`) whose fine-grained C/Obj-C
  /// subtargets should be combined into a single unified framework.
  ///
  /// - Parameters:
  ///   - graph: Resolved SwiftPM modules graph.
  ///   - config: Configuration containing optional explicit aggregation rules.
  ///   - repoRoot: Root directory of the repository.
  ///   - packageRoots: Root directories of all packages in the graph.
  /// - Returns: A tuple containing:
  ///   - `aggregates`: Combined `TargetDefinition` instances keyed by package name.
  ///   - `subtargetMap`: Map from product name, module name, and C99 name to the enclosing package
  ///     name.
  ///   - `submodules`: Array of individual submodule `TargetDefinition`s for module map generation.
  package static func resolveAggregates(from graph: ModulesGraph,
                                        config: Config) throws -> (
    aggregates: [String: TargetDefinition],
    subtargetMap: [String: String],
    submodules: [TargetDefinition]
  ) {
    var aggregates: [String: TargetDefinition] = [:]
    var subtargetMap: [String: String] = [:]
    var submodules: [TargetDefinition] = []

    let rootPackageIdentities = Set(graph.rootPackages.map(\.identity))

    for package in graph.packages where shouldAggregate(
      package,
      rootPackageIdentities: rootPackageIdentities,
      config: config
    ) {
      let packageName = package.manifest.displayName
      let nonTestModules = package.modules.filter { !$0.isTest }

      // map library products to the aggregate package name (e.g. GULEnvironment -> GoogleUtilities)
      for product in package.products {
        subtargetMap[product.name] = packageName
      }

      // build individual submodule definitions and map module names & C99 identifiers
      var packageSubtargets: [TargetDefinition] = []
      for module in nonTestModules {
        subtargetMap[module.name] = packageName
        subtargetMap[module.c99name] = packageName

        let subtarget = try TargetDefinitionFactory.makeTargetDefinition(
          module: module,
          config: config
        )
        packageSubtargets.append(subtarget)
        submodules.append(subtarget)
      }

      let allSources = packageSubtargets.flatMap(\.sources)
      let allExportedPaths = packageSubtargets.flatMap(\.exportedHeaderSearchPaths)
      let aggregatedExported = Set(allExportedPaths).sorted()
      let ownHeaders = allSources.filter(\.isHeaderFile)
      let validSearchPaths = HeaderSearchPathBuilder.filterConcretePaths(packageSubtargets.flatMap(
        \.headerSearchPaths
      ))
      let explicitSearchPaths = Set(validSearchPaths).sorted()

      let headerSearchPaths = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
        ownHeaders: ownHeaders,
        explicitSearchPaths: explicitSearchPaths,
        dependencySearchPaths: aggregatedExported,
        baseSearchPaths: config.baseHeaderSearchPaths
      )

      let aggregateTarget = TargetDefinition.aggregate(
        name: packageName,
        subtargets: packageSubtargets,
        headerSearchPaths: headerSearchPaths,
        exportedHeaderSearchPaths: aggregatedExported,
        publicHeadersPath: packageSubtargets.first?.publicHeadersPath
          ?? (config.publicHeaderFolderNames.first)
      )

      aggregates[packageName] = aggregateTarget
    }

    return (aggregates, subtargetMap, submodules)
  }

  /// Determines whether an external dependency package contains multiple modular sub-targets
  /// that should be combined into a single unified framework.
  ///
  /// A packaged is considered to be a target of aggregation if it passes all the following:
  /// - Is not a root package or test module
  /// - Is not a binary target
  /// - Is a C/Obj-C module
  /// - It follows the naming convention of `<PackageName>-<Component>` (e.g.
  /// `GoogleUtilities-Logger`)
  package static func shouldAggregate(_ package: ResolvedPackage,
                                      rootPackageIdentities: Set<PackageIdentity>,
                                      config: Config) -> Bool {
    guard !rootPackageIdentities.contains(package.identity) else { return false }
    let nonTestModules = package.modules.filter { !$0.isTest }

    guard !nonTestModules.isEmpty,
          !nonTestModules.contains(where: \.isBinary),
          nonTestModules.allSatisfy({ $0.underlying is ClangModule })
    else { return false }

    let packageName = package.manifest.displayName
    if !config.aggregatePackageNames.isEmpty {
      return config.aggregatePackageNames.contains(packageName)
    }

    let prefixedModules = nonTestModules.filter { $0.name.hasPrefix("\(packageName)-") }
    return prefixedModules.count > 1
  }
}
