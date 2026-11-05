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

/// Central authority for classifying project targets: identifying synthetic wrappers,
/// companion submodules, stub files, and internal libraries.
public enum TargetClassifier: Sendable {
  /// Evaluates whether a target is a synthetic wrapper based on configuration rules, file naming,
  /// and source content.
  ///
  /// ```swift
  /// // Matches explicit wrapper target name in config:
  /// isWrapperTarget(name: "ExplicitWrapperTarget", isBinary: false, sources: [...], config:
  /// config) // -> true
  ///
  /// // Matches wildcard pattern (*Wrapper):
  /// isWrapperTarget(name: "abslWrapper", isBinary: false, sources: [...], config: config) // ->
  /// true
  ///
  /// // Sources reside entirely within configured wrapper source directories:
  /// isWrapperTarget(name: "AnyTarget", isBinary: false, sources:
  /// ["/repo/SwiftPM-PlatformExclude/bridge.c"], config: config) // -> true
  ///
  /// // Target has empty sources:
  /// isWrapperTarget(name: "EmptyTarget", isBinary: false, sources: [], config: config) // -> true
  ///
  /// // Binary targets are never wrappers:
  /// isWrapperTarget(name: "ExplicitWrapperTarget", isBinary: true, sources: [], config: config) //
  /// -> false
  ///
  /// // Real library target with actual code:
  /// isWrapperTarget(name: "FirebaseCore", isBinary: false, sources: ["/repo/FIRApp.m"], config:
  /// config) // -> false
  /// ```
  public static func isWrapperTarget(name: String,
                                     isBinary: Bool,
                                     sources: [String],
                                     config: Config) -> Bool {
    guard !isBinary else { return false }

    if config.wrapperTargetNames.contains(name) {
      return true
    }

    if config.wrapperTargetPatterns.contains(where: name.matchesWildcard) {
      return true
    }

    // targets located entirely within configured wrapper source directories
    // (e.g. SwiftPM-PlatformExclude)
    if !config.wrapperSourceFolderNames.isEmpty && !sources.isEmpty {
      let allInWrapperFolder = sources.allSatisfy { path in
        config.wrapperSourceFolderNames.contains(where: path.contains)
      }
      if allInWrapperFolder {
        return true
      }
    }

    // targets with no sources
    if sources.isEmpty {
      return true
    }

    // targets whose sources contain only empty stub files
    if sources.allSatisfy({ isStubFile($0, config: config) }) {
      return true
    }

    return false
  }

  /// Checks whether a single file is a recognized stub file.
  ///
  /// ```swift
  /// // Matches configured stub file names (e.g. "dummy.m", "empty.h"):
  /// isStubFile("/path/to/dummy.m", config: config) // -> true
  /// isStubFile("/path/to/empty.h", config: config) // -> true
  ///
  /// // Matches configured stub wildcard pattern (e.g. "*Wrapper.swift"):
  /// isStubFile("/path/to/MyWrapper.swift", config: config) // -> true
  ///
  /// // A 0-byte (empty) file on disk:
  /// isStubFile("/path/to/empty_placeholder.c", config: config) // -> true
  ///
  /// // Real source file with contents:
  /// isStubFile("/path/to/FIRApp.m", config: config) // -> false
  /// ```
  public static func isStubFile(_ path: String, config: Config) -> Bool {
    let fileName = path.split(separator: "/").last.map(String.init) ?? path
    if config.stubFileNames.contains(fileName) ||
      config.stubFilePatterns.contains(where: fileName.matchesWildcard) {
      return true
    }

    return FileManager.default.fileIsEmpty(atPath: path)
  }

  /// Returns `true` if the path resides within a configured wrapper source directory.
  public static func isWrapperSourceRoot(path: String, config: Config) -> Bool {
    return config.wrapperSourceFolderNames.contains(where: path.contains)
  }

  /// Evaluates whether a dependency module name is an internal companion/submodule of a parent
  /// module.
  ///
  /// ```swift
  /// // Suffix match (e.g. "Internal"):
  /// isCompanionModule("FirebaseCoreInternal", of: "FirebaseCore") // -> true
  /// isCompanionModule("FirebaseAuthInternal", of: "FirebaseAuth") // -> true
  ///
  /// // Prefix delimiter match ("_" or "-"):
  /// isCompanionModule("GoogleUtilities_Environment", of: "GoogleUtilities") // -> true
  /// isCompanionModule("GoogleUtilities-Logger", of: "GoogleUtilities")      // -> true
  ///
  /// // Suppressed internal frameworks match:
  /// isCompanionModule("FirebaseSharedSwift", of: "Firebase", suppressedInternalFrameworks:
  /// ["FirebaseSharedSwift"]) // -> true
  ///
  /// // Different modules / self:
  /// isCompanionModule("FirebaseFirestore", of: "FirebaseAuth") // -> false
  /// isCompanionModule("FirebaseCore", of: "FirebaseCore")      // -> false (self is not a
  /// companion)
  /// ```
  public static func isCompanionModule(_ depName: String,
                                       of parentName: String,
                                       companionSuffixes: [String] = Config.Defaults
                                         .companionModuleSuffixes,
                                       suppressedInternalFrameworks: [String] = []) -> Bool {
    guard depName != parentName else { return false }

    if suppressedInternalFrameworks.contains(depName) && depName.hasPrefix(parentName) {
      return true
    }

    for suffix in companionSuffixes {
      if depName == "\(parentName)\(suffix)" || depName.hasPrefix("\(parentName)\(suffix)") {
        return true
      }
    }

    if depName.hasPrefix("\(parentName)_") || depName.hasPrefix("\(parentName)-") {
      return true
    }

    return false
  }

  /// Evaluates whether a target name represents an internal companion or suppressed framework.
  ///
  /// ```swift
  /// // Matches default companion suffix "Internal":
  /// isInternalCompanion(named: "FirebaseCoreInternal", config: config) // -> true
  ///
  /// // Matches explicit suppressedInternalFrameworks in config:
  /// isInternalCompanion(named: "FirebaseSharedSwift", config: config)  // -> true
  ///
  /// // Public product:
  /// isInternalCompanion(named: "FirebaseAuth", config: config)         // -> false
  /// ```
  public static func isInternalCompanion(named targetName: String,
                                         config: Config) -> Bool {
    if config.suppressedInternalFrameworks.contains(targetName) {
      return true
    }

    return config.companionModuleSuffixes.contains(where: targetName.hasSuffix)
  }
}
