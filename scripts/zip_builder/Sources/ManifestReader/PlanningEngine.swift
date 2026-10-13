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

/// Unified entry point and orchestration engine that produces a comprehensive `BuildPlan` across
/// the zip builder pipeline, either by loading a pre-resolved plan artifact or by evaluating
/// `Package.swift` and product configuration.
public enum PlanningEngine: Sendable {
  private static let logger = Logger(label: "zip-builder.planning-engine")
  private static let defaultConfigFileName = "zip_builder.json"

  /// Resolves the active `BuildPlan` using URLs and unified `BuildOptions`.
  ///
  /// - Parameters:
  ///   - planURL: Optional URL pointing to a pre-resolved JSON build plan file.
  ///   - packageURL: Root package directory URL containing `Package.swift`.
  ///   - configURL: Optional file URL pointing to a custom product configuration JSON.
  ///   - options: Unified build and resolution options (filtering, overrides).
  ///   - logger: Active logger instance.
  /// - Returns: Fully resolved and scoped `BuildPlan`.
  /// - Throws: `PlanningError` or decoding errors if resolution fails.
  public static func resolve(planURL: URL? = nil,
                             packageURL: URL = URL(filePath: "."),
                             configURL: URL? = nil,
                             options: BuildOptions = BuildOptions(),
                             logger: Logger =
                               Logger(label: "zip-builder.planning-engine")) async throws
    -> BuildPlan {
    if let planURL {
      guard FileManager.default.fileExists(atPath: planURL.path) else {
        throw PlanningError.planFileNotFound(planURL.path)
      }

      logger.info("Loading pre-resolved build plan", metadata: ["path": "\(planURL.path)"])
      let decodedPlan = try BuildPlan.load(from: planURL)
      logger.debug(
        "Decoded build plan",
        metadata: [
          "version": "\(decodedPlan.config.version)",
          "project": "\(decodedPlan.config.projectName)",
          "productCount": "\(decodedPlan.products.count)",
        ]
      )

      return try resolve(decodedPlan: decodedPlan, options: options, logger: logger)
    }

    logger.info("Loading package manifest", metadata: ["path": "\(packageURL.path)"])
    let loader = PackageGraphLoader(packagePath: packageURL)
    let graph = try await loader.loadGraph()

    let effectiveConfigURL = resolveConfigFileURL(configURL: configURL, packageURL: packageURL)

    let config = try ConfigResolver.resolve(
      from: effectiveConfigURL,
      graph: graph,
      options: options
    )

    return try BuildPlanResolver.resolveBuildPlan(from: graph, config: config, options: options)
  }

  /// Convenience overload taking file path strings.
  public static func resolve(planPath: String? = nil,
                             packagePath: String = ".",
                             configPath: String? = nil,
                             options: BuildOptions = BuildOptions(),
                             logger: Logger =
                               Logger(label: "zip-builder.planning-engine")) async throws
    -> BuildPlan {
    let planURL = planPath.map { URL(filePath: $0) }
    let packageURL = URL(filePath: packagePath)
    let configURL = configPath.map { URL(filePath: $0) }

    return try await resolve(
      planURL: planURL,
      packageURL: packageURL,
      configURL: configURL,
      options: options,
      logger: logger
    )
  }

  /// Applies options and filtering to a pre-resolved `BuildPlan` artifact.
  public static func resolve(decodedPlan: BuildPlan,
                             options: BuildOptions,
                             logger: Logger = Logger(label: "zip-builder.planning-engine")) throws
    -> BuildPlan {
    if options.hasOverrides || options.target != nil {
      logger.info("Applying command-line overrides to pre-resolved build plan...")
    }
    let effectiveConfig = ConfigResolver.apply(options: options, to: decodedPlan.config)

    var effectiveProducts = decodedPlan.products

    if options.targetPlatforms != nil {
      let resolvedTargetPlatforms = effectiveConfig.targetPlatforms
      logger.info(
        "Filtering build plan platforms",
        metadata: [
          "platforms": "\(resolvedTargetPlatforms.map(\.canonicalName).joined(separator: ", "))",
        ]
      )

      effectiveProducts = effectiveProducts.compactMap { product in
        let supportedPlatforms = product.platforms.filter { resolvedTargetPlatforms.contains($0) }
        guard !supportedPlatforms.isEmpty else {
          logger.debug(
            "Excluding product with no matching platforms",
            metadata: ["product": "\(product.name)"]
          )
          return nil
        }

        return ProductPlan(
          name: product.name,
          targets: product.targets,
          binaryTargets: product.binaryTargets,
          extraFrameworks: product.extraFrameworks,
          declaredTargetNames: product.declaredTargetNames,
          platforms: supportedPlatforms,
          dynamicFrameworks: product.dynamicFrameworks,
          resourceBundles: product.resourceBundles,
          customCompilerFlags: product.customCompilerFlags
        )
      }
    }

    if let target = options.target {
      logger.info(
        "Filtering build plan for target/product",
        metadata: ["target": "\(target)"]
      )

      effectiveProducts = filterProductPlans(effectiveProducts, for: target)
      guard !effectiveProducts.isEmpty else {
        logger.error(
          "Target or product not found in build plan",
          metadata: ["target": "\(target)"]
        )

        throw PlanningError.targetNotFound(target)
      }

      logger.debug(
        "Filtered build plan",
        metadata: ["productCount": "\(effectiveProducts.count)"]
      )
    }

    return BuildPlan(
      config: effectiveConfig,
      products: effectiveProducts,
      aggregatedSubmodules: decodedPlan.aggregatedSubmodules,
      frameworkSearchPaths: decodedPlan.frameworkSearchPaths
    )
  }

  /// Filters a list of product plans to only contain products matching the specified target or
  /// product name.
  public static func filterProductPlans(_ products: [ProductPlan],
                                        for targetFilter: String) -> [ProductPlan] {
    let targetLower = targetFilter.lowercased()
    return products.compactMap { product -> ProductPlan? in
      if product.name.lowercased() == targetLower {
        return product
      }

      let matchingTargets = product.targets
        .filter { $0.name.lowercased() == targetLower }
      if !matchingTargets.isEmpty {
        return ProductPlan(
          name: product.name,
          targets: matchingTargets,
          binaryTargets: product.binaryTargets,
          extraFrameworks: product.extraFrameworks,
          declaredTargetNames: product.declaredTargetNames,
          platforms: product.platforms,
          dynamicFrameworks: product.dynamicFrameworks,
          resourceBundles: product.resourceBundles,
          customCompilerFlags: product.customCompilerFlags
        )
      }

      return nil
    }
  }

  /// Resolves the URL for the `zip_builder.json` configuration file following the default search
  /// hierarchy.
  ///
  /// The search order is:
  /// 1. The explicit `configURL` if provided.
  /// 2. `zip_builder.json` located within the root package directory (`packageURL`).
  /// 3. `zip_builder.json` located in the current working directory.
  ///
  /// - Parameters:
  ///   - configURL: An optional explicit URL pointing to a configuration file.
  ///   - packageURL: Root package directory URL containing `Package.swift`.
  /// - Returns: The resolved configuration file URL, or `nil` if no configuration file was found.
  private static func resolveConfigFileURL(configURL: URL?, packageURL: URL) -> URL? {
    if let configURL {
      return configURL
    }

    let packageConfig = packageURL.appendingPathComponent(defaultConfigFileName)
    if FileManager.default.fileExists(atPath: packageConfig.path) {
      return packageConfig
    }

    let cwdConfig = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(defaultConfigFileName)
    if FileManager.default.fileExists(atPath: cwdConfig.path) {
      return cwdConfig
    }

    return nil
  }
}

/// Error encountered during build plan resolution or planning.
public enum PlanningError: Error, CustomStringConvertible, Equatable {
  case planFileNotFound(String)
  case targetNotFound(String)

  public var description: String {
    switch self {
    case let .planFileNotFound(path):
      return "Build plan file not found at '\(path)'."
    case let .targetNotFound(target):
      return "Target or product '\(target)' not found in build plan."
    }
  }
}
