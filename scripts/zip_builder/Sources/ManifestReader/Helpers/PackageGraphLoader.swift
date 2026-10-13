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
import PackageGraph
import PackageLoading
import PackageModel
import Workspace

/// Responsible for parsing `Package.swift` and loading the full SwiftPM `ModulesGraph`
/// using official `libSwiftPM` workspace APIs.
public struct PackageGraphLoader: Sendable {
  private let logger = Logger(label: "zip-builder.manifest-reader")
  /// File system URL pointing to the root Swift package directory containing `Package.swift`.
  public let packagePath: URL

  /// Initializes the loader with a target package directory path.
  /// - Parameter packagePath: File URL to the root package directory.
  public init(packagePath: URL) {
    self.packagePath = packagePath
  }

  /// Evaluates `Package.swift`, resolves package dependencies from `Package.resolved`,
  /// and returns the complete in-memory `ModulesGraph`.
  ///
  /// - Returns: Fully resolved `ModulesGraph` representing all packages, modules, and products.
  /// - Throws: An error if manifest evaluation or package dependency resolution fails.
  public func loadGraph() async throws -> ModulesGraph {
    logger.info("Loading package graph", metadata: ["path": "\(packagePath.path)"])

    let absolutePath = try AbsolutePath(validating: packagePath.path)
    let observability = ObservabilitySystem { scope, diagnostic in
      let metadata: Logger.Metadata = [
        "scope": "\(scope.description)",
        "message": "\(diagnostic.message)",
      ]

      switch diagnostic.severity {
      case .error:
        logger.error("Package diagnostic", metadata: metadata)
      case .warning:
        logger.warning("Package diagnostic", metadata: metadata)
      case .info:
        logger.info("Package diagnostic", metadata: metadata)
      case .debug:
        logger.debug("Package diagnostic", metadata: metadata)
      @unknown default:
        logger.info("Package diagnostic", metadata: metadata)
      }
    }

    let workspace = try Workspace(
      fileSystem: localFileSystem,
      location: .init(forRootPackage: absolutePath, fileSystem: localFileSystem)
    )

    let rootInput = PackageGraphRootInput(packages: [absolutePath])
    let graph = try await workspace.loadPackageGraph(
      rootInput: rootInput,
      observabilityScope: observability.topScope
    )
    logger.debug(
      "Package graph loaded successfully",
      metadata: [
        "packageCount": "\(graph.packages.count)",
        "productCount": "\(graph.allProducts.count)",
        "targetCount": "\(graph.allModules.count)",
      ]
    )

    return graph
  }
}
