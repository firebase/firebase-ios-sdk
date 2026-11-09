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

@preconcurrency import Basics
import Foundation
@preconcurrency import PackageGraph
import Workspace

/// Loads the package at `path` and its dependencies.
///
/// Dependencies that are already resolved are reused, so no network is needed. `scratchPath`
/// replaces `<path>/.build` and also holds `Package.resolved`, e.g. to keep a fixture clean.
func loadPackage(at path: Path, scratchPath: Path? = nil) async throws -> ModulesGraph {
  let root = try absolutePath(path)
  var location = try Workspace.Location(forRootPackage: root, fileSystem: localFileSystem)
  if let scratchPath {
    location.scratchDirectory = try absolutePath(scratchPath)
    location.resolvedVersionsFile = location.scratchDirectory.appending("Package.resolved")
  }
  let observability = ObservabilitySystem { _, diagnostic in
    switch diagnostic.severity {
    case .error: logger.error("SwiftPM: \(diagnostic.message)")
    case .warning: warn("SwiftPM: \(diagnostic.message)")
    case .info, .debug: logger.debug("SwiftPM: \(diagnostic.message)")
    }
  }
  let workspace = try Workspace(fileSystem: localFileSystem, location: location)
  let graph = try await workspace.loadPackageGraph(
    rootInput: PackageGraphRootInput(packages: [root]),
    observabilityScope: observability.topScope
  )
  if observability.topScope.errorsReported {
    throw ZipBuilderError("Couldn't load the package at \(path); see the errors above.")
  }
  return graph
}

private func absolutePath(_ path: Path) throws -> AbsolutePath {
  try AbsolutePath(validating: URL(fileURLWithPath: path).standardizedFileURL.path)
}
