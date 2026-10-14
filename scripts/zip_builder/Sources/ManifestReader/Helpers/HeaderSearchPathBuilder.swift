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
import Common
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// Utility responsible for discovering, sanitizing, and constructing header search paths
/// (`HEADER_SEARCH_PATHS`) for compiled C/Objective-C/Swift targets in the generated Xcode project.
public enum HeaderSearchPathBuilder: Sendable {
  /// Default base search paths included for all generated project targets.
  public static let defaultBaseSearchPaths: [String] = Config.Defaults.baseHeaderSearchPaths

  /// Default directory names excluded from header search paths to prevent pollution.
  public static let excludedFolderNames: Set<String> = [
    ".build",
    "checkouts",
  ]

  /// Validates an absolute path against excluded directory names and returns its string
  /// representation.
  ///
  /// - Parameter path: The candidate absolute directory path.
  /// - Returns: The path string if allowed, or `nil` if the directory is excluded (e.g. `.build` or
  ///   `checkouts`).
  public static func validateSearchPath(_ path: AbsolutePath) -> String? {
    return !excludedFolderNames.contains(path.basename) ? path.pathString : nil
  }

  /// Validates and normalizes a candidate header search path or Xcode macro string.
  ///
  /// Empty or whitespace-only strings are ignored and return `nil`. Xcode build setting macros
  /// (starting with `$`, such as `$(inherited)` or `$(PROJECT_DIR)/GeneratedModules`) are allowed
  /// verbatim. Concrete paths must be valid absolute paths and not end in an excluded directory
  /// name.
  ///
  /// - Parameter path: The candidate search path string or Xcode macro.
  /// - Returns: The normalized path or macro string if valid and allowed, or `nil` if excluded or
  ///   empty.
  /// - Throws: An error if the path cannot be validated as a valid absolute path.
  public static func validateSearchPath(_ path: String) throws -> String? {
    let trimmed = path.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Xcode macros (e.g. $(inherited), $(PROJECT_DIR)/GeneratedModules) are always allowed.
    if trimmed.hasPrefix("$") {
      return trimmed
    }

    let absPath = try AbsolutePath(validating: trimmed)
    return validateSearchPath(absPath)
  }

  /// Extracts the public header search paths that a Clang module exports to dependent targets.
  ///
  /// Leverages SwiftPM's `includeDir` as the single source of truth and includes any immediate
  /// module namespace subfolders (e.g. `Public/FirebaseCore` or `spm_headers/nanopb`) to support
  /// both modular (`#import <FirebaseCore/FIRApp.h>`) and unqualified (`#import "FIRApp.h"`)
  /// imports.
  ///
  /// - Parameter clangModule: The Clang module to inspect.
  /// - Returns: Sorted array of unique exported search paths.
  public static func exportedSearchPaths(for clangModule: ClangModule) -> [String] {
    let includeDir = clangModule.includeDir
    var searchPaths = Set<String>()

    if let path = validateSearchPath(includeDir) {
      searchPaths.insert(path)
    }

    for header in clangModule.headers where header.isDescendantOfOrEqual(to: includeDir) {
      let parent = header.parentDirectory
      if parent != includeDir, let path = validateSearchPath(parent) {
        searchPaths.insert(path)
      }
    }

    return Array(searchPaths).sorted()
  }

  /// Extracts the exported public header search paths for a resolved module.
  ///
  /// - Parameter module: The resolved module to inspect.
  /// - Returns: Sorted array of unique exported search paths, or empty array if not a Clang module.
  public static func exportedSearchPaths(for module: ResolvedModule) -> [String] {
    guard let clangModule = module.underlying as? ClangModule else { return [] }
    return exportedSearchPaths(for: clangModule)
  }

  /// Computes exported header search paths from a public include directory and optional header file
  /// paths.
  ///
  /// - Parameters:
  ///   - includeDir: The base include directory path.
  ///   - headerPaths: List of header file paths located within or under the include directory.
  /// - Returns: Sorted array of unique exported search paths.
  /// - Throws: An error if `includeDir` or any `headerPaths` entry cannot be validated as an
  /// absolute path.
  public static func exportedSearchPaths(includeDir: String,
                                         headerPaths: [String] = []) throws -> [String] {
    let includePath = try AbsolutePath(validating: includeDir)
    guard let validatedIncludePath = validateSearchPath(includePath) else { return [] }

    var searchPaths = Set<String>([validatedIncludePath])
    for header in headerPaths {
      let headerPath = try AbsolutePath(validating: header)
      let parent = headerPath.parentDirectory
      if parent != includePath,
         parent.isDescendantOfOrEqual(to: includePath),
         let path = validateSearchPath(parent) {
        searchPaths.insert(path)
      }
    }

    return Array(searchPaths).sorted()
  }

  /// Constructs the complete, sanitized header search paths for compiling a target.
  ///
  /// Combines:
  /// 1. Base project search paths (`$(inherited)`, `GeneratedModules`).
  /// 2. Header search paths exported by direct and transitive dependencies.
  /// 3. Explicit compiler search paths declared on the target (e.g. `cSettings:
  /// [.headerSearchPath(...)]`).
  /// 4. Directories containing the target's own header files (for internal includes).
  ///
  /// - Parameters:
  ///   - ownHeaders: Header file paths belonging directly to the target.
  ///   - explicitSearchPaths: Search paths extracted from build settings assignments.
  ///   - dependencySearchPaths: Exported header search paths collected from dependencies.
  ///   - baseSearchPaths: Base header search paths applied to all targets.
  /// - Returns: Sorted array of unique, cleaned header search paths.
  /// - Throws: An error if any concrete search path or header path cannot be validated as an
  /// absolute path.
  public static func buildTargetHeaderSearchPaths(ownHeaders: [String] = [],
                                                  explicitSearchPaths: [String] = [],
                                                  dependencySearchPaths: [String] = [],
                                                  baseSearchPaths: [String] =
                                                    defaultBaseSearchPaths) throws -> [String] {
    var searchPaths = Set<String>()

    func addSearchPath(_ path: String) throws {
      if let path = try validateSearchPath(path) {
        searchPaths.insert(path)
      }
    }

    for path in baseSearchPaths {
      try addSearchPath(path)
    }

    for path in dependencySearchPaths {
      try addSearchPath(path)
    }

    for path in explicitSearchPaths {
      try addSearchPath(path)
    }

    for header in ownHeaders {
      let trimmed = header.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      let headerPath = try AbsolutePath(validating: trimmed)
      try addSearchPath(headerPath.parentDirectory.pathString)
    }

    return Array(searchPaths).sorted()
  }

  /// Returns a Boolean value indicating whether a path string represents an unresolved Xcode build
  /// setting macro (e.g. `$(inherited)` or `$(SRCROOT)`).
  ///
  /// - Parameter path: The path string to inspect.
  /// - Returns: `true` if the path starts with `$`; otherwise, `false`.
  public static func isXcodeMacro(_ path: String) -> Bool {
    path.hasPrefix("$")
  }

  /// Filters an array of paths to exclude any Xcode build setting macros, returning only concrete
  /// filesystem paths.
  ///
  /// - Parameter paths: An array of path strings that may include Xcode build setting macros.
  /// - Returns: An array containing only concrete filesystem paths.
  public static func filterConcretePaths(_ paths: [String]) -> [String] {
    paths.filter { !isXcodeMacro($0) }
  }
}
