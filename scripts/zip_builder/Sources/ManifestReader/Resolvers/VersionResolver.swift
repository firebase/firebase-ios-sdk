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

/// Resolves release version strings from command-line overrides, configuration files, or
/// manifest inspection.
public enum VersionResolver: Sendable {
  private static let logger = Logger(label: "zip-builder.version-resolver")

  /// Resolves the release version for a project.
  ///
  /// - Parameters:
  ///   - config: The parsed configuration file schema.
  ///   - graph: The resolved SwiftPM package graph.
  ///   - projectName: The resolved project name.
  ///   - version: Optional CLI version override.
  /// - Returns: The resolved semantic `Version`.
  /// - Throws: `LoadConfigError.missingVersion` if version cannot be determined.
  public static func resolveVersion(config: ProductConfigFile,
                                    graph: ModulesGraph,
                                    projectName: String,
                                    version: Version?) throws -> Version {
    // 1. Explicit CLI Argument
    if let version {
      logger.debug("Overriding version via CLI argument", metadata: [
        "version": "\(version)",
      ])
      return version
    }

    // 2. Config File
    if let version = config.version {
      logger.debug("Resolved version from config file", metadata: [
        "version": "\(version)",
      ])
      return version
    }

    // 3. Parse Package.swift text
    let repoRoot = graph.rootPackages.first?.path.pathString ?? ""
    if let inferred = try inferVersionFromPackage(path: repoRoot, projectName: projectName) {
      logger.debug("Inferred version from Package.swift", metadata: [
        "version": "\(inferred)",
      ])
      return inferred
    }

    throw LoadConfigError.missingVersion
  }

  /// Scans `Package.swift` line by line for the version string.
  ///
  /// Can be either format:
  /// - `let version = "X.Y.Z"`
  /// - `let projectVersion = "X.Y.Z"`
  ///
  /// Where `project` is the name of the project, and `X.Y.Z` is the version string.
  public static func inferVersionFromPackage(path: String,
                                             projectName: String) throws -> Version? {
    guard !path.isEmpty else { return nil }

    let packageURL = URL(filePath: path).appending(path: "Package.swift")
    guard let content = try? String(contentsOf: packageURL, encoding: .utf8) else {
      logger.warning("Failed to read Package.swift", metadata: [
        "path": "\(packageURL.absoluteString)",
      ])

      return nil
    }

    return try extractVersion(fromManifestContent: content, projectName: projectName)
  }

  /// Extracts the version from the content of a `Package.swift` manifest.
  public static func extractVersion(fromManifestContent content: String,
                                    projectName: String) throws -> Version? {
    let lowerProject = projectName.lowercased().replacingOccurrences(of: "-", with: "")
    let acceptedNames = Set([
      "version",
      "\(lowerProject)version",
    ])

    for rawLine in content.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespaces).lowercased()

      // skip comments
      if line.hasPrefix("//") || line.hasPrefix("/*") || line.hasPrefix("*") {
        continue
      }

      for name in acceptedNames {
        guard let versionString = line.substringAfter("let \(name) = ") else {
          continue
        }

        let unquotedVersion = versionString.replacingOccurrences(of: "\"", with: "")
          .trimmingCharacters(in: .whitespaces)
        return try Version(versionString: unquotedVersion, usesLenientParsing: true)
      }
    }

    return nil
  }
}
