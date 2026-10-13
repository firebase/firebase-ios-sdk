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

import Basics
import Common
import Foundation
import Logging
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// Resolves individual `ProductPlan` definitions by traversing module dependency graphs,
/// merging companion internal headers/resources, and collecting linker & compiler settings.
public enum ProductResolver: Sendable {
  private static let logger = Logger(label: "zip-builder.product-resolver")

  /// Resolves a single product plan using the given resolution context.
  public static func resolveProduct(platforms: [Common.Platform],
                                    entry: Config.ProductEntry,
                                    context: ResolutionContext) throws -> ProductPlan {
    logger.debug(
      "Resolving product",
      metadata: [
        "product": "\(entry.name)",
        "declaredTargets": "\(entry.targets.joined(separator: ", "))",
      ]
    )
    var sourceTargets: [TargetDefinition] = []
    var binaryTargets: [TargetDefinition] = []
    var resolvedTargetNames = Set<String>()
    var queue = entry.targets

    while !queue.isEmpty {
      let rawTargetName = queue.removeFirst()
      let targetName = context.mappedTargetName(for: rawTargetName)
      guard resolvedTargetNames.insert(targetName).inserted else { continue }

      // handle aggregate targets (e.g. GoogleUtilities, gRPC)
      if let aggregateTarget = context.aggregate(named: targetName) {
        let updatedAggregate = try resolveAggregateTarget(aggregateTarget, context: context)
        if updatedAggregate.isBinary {
          binaryTargets.append(updatedAggregate)
        } else {
          sourceTargets.append(updatedAggregate)
        }

        for dep in aggregateTarget.dependencies {
          let mappedDep = context.mappedTargetName(for: dep)
          if !resolvedTargetNames.contains(mappedDep) {
            queue.append(mappedDep)
          }
        }

        continue
      }

      // handle module targets from package graph
      guard let module = context.module(named: targetName) else {
        if entry.targets.contains(targetName) {
          logger.error(
            "Declared root target not found in module graph",
            metadata: [
              "target": "\(targetName)",
              "product": "\(entry.name)",
            ]
          )
          throw PlanningError.targetNotFound(targetName)
        }
        logger.warning(
          "Target not found in module graph",
          metadata: [
            "target": "\(targetName)",
            "product": "\(entry.name)",
          ]
        )
        continue
      }

      let directDeps = directDependencies(for: module, context: context)
      for dep in directDeps where !resolvedTargetNames.contains(dep) {
        queue.append(dep)
      }

      // don't create target definitions for the wrapper itself; just its dependencies
      // (which are queued aboved)
      if TargetClassifier.isWrapperSourceRoot(
        path: module.sources.root.pathString,
        config: context.config
      ) {
        continue
      }

      let recursiveDeps = transitiveDependencies(
        for: module,
        context: context
      )
      for dep in recursiveDeps where !resolvedTargetNames.contains(dep) {
        queue.append(dep)
      }

      let targetDef = try TargetDefinitionFactory.makeTargetDefinition(
        module: module,
        directDeps: directDeps,
        recursiveDeps: recursiveDeps,
        context: context
      )

      if targetDef.isBinary {
        binaryTargets.append(targetDef)
      } else {
        sourceTargets.append(targetDef)
      }
    }

    logger.debug(
      "Product resolved",
      metadata: [
        "product": "\(entry.name)",
        "sourceTargetCount": "\(sourceTargets.count)",
        "binaryTargetCount": "\(binaryTargets.count)",
        "platforms": "\(platforms.map(\.rawValue).joined(separator: ", "))",
      ]
    )

    return ProductPlan(
      name: entry.name,
      targets: sourceTargets,
      binaryTargets: binaryTargets,
      extraFrameworks: context.extraFrameworks(for: entry),
      declaredTargetNames: entry.targets,
      platforms: platforms,
      dynamicFrameworks: entry.dynamicFrameworks ?? [],
      resourceBundles: entry.resourceBundles ?? [],
      customCompilerFlags: entry.customCompilerFlags ?? [:]
    )
  }

  // MARK: - Dependency and Target Resolution Helpers

  /// Resolves dependency search paths for an aggregate target within the current context.
  private static func resolveAggregateTarget(_ aggregate: TargetDefinition,
                                             context: ResolutionContext) throws
    -> TargetDefinition {
    let allDeps = aggregate.dependencies + aggregate.recursiveDependencies
    let depSearchPaths = try TargetDefinitionFactory.collectDependencyHeaderSearchPaths(
      dependencies: allDeps,
      context: context
    )
    let searchPaths = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
      ownHeaders: aggregate.sources.filter(\.isHeaderFile),
      explicitSearchPaths: HeaderSearchPathBuilder.filterConcretePaths(aggregate.headerSearchPaths),
      dependencySearchPaths: depSearchPaths + aggregate.exportedHeaderSearchPaths,
      baseSearchPaths: context.config.baseHeaderSearchPaths
    )

    return aggregate.updatingHeaderSearchPaths(searchPaths)
  }

  /// Collects direct module dependency target names mapped through aggregate mappings.
  package static func directDependencies(for module: ResolvedModule,
                                         context: ResolutionContext) -> [String] {
    var directDeps: [String] = []
    for dep in module.dependencies {
      switch dep {
      case let .module(m, _):
        directDeps.append(context.mappedTargetName(for: m.name))
      case let .product(p, _):
        for module in p.modules {
          directDeps.append(context.mappedTargetName(for: module.name))
        }
      }
    }

    return directDeps
  }

  /// Collects transitive module dependency target names mapped through aggregate mappings.
  package static func transitiveDependencies(for module: ResolvedModule,
                                             context: ResolutionContext) -> [String] {
    guard let recursiveModules = try? module.recursiveModuleDependencies() else { return [] }

    return recursiveModules.map { context.mappedTargetName(for: $0.name) }
  }

  // MARK: - Public Util Helpers

  /// Infers supported platforms for a set of target names by inspecting `.when(platforms: [...])`
  /// dependency conditions on modules in the package graph.
  ///
  /// - Parameters:
  ///   - targetNames: Names of targets to check for platform-specific dependencies.
  ///   - context: Resolution context containing the module graph and aggregate mappings.
  ///   - fallback: Fallback platforms when no platform conditions are declared.
  /// - Returns: Array of supported platform identifiers in preferred display order.
  public static func inferPlatforms(forTargetNames targetNames: [String],
                                    context: ResolutionContext,
                                    fallback: [Common.Platform] = Common.Platform
                                      .defaultPlatforms) -> [Common.Platform] {
    let resolvedModules = targetNames.compactMap(context.module)

    let conditionalPlatforms = resolvedModules
      .flatMap { $0.dependencies.flatMap(\.conditions) }
      .compactMap(\.platformsCondition)
      .flatMap(\.platforms)

    guard !conditionalPlatforms.isEmpty else {
      return fallback
    }

    var supported = Set(conditionalPlatforms.map(Common.Platform.from))
    if supported.contains(.ios) {
      supported.insert(.catalyst)
    }

    return Common.Platform.preferredPlatformOrder.filter(supported.contains)
  }
}
