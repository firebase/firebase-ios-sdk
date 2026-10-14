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
import Logging
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// Constructs `TargetDefinition` instances from `ResolvedModule` graph nodes.
public enum TargetDefinitionFactory: Sendable {
  private static let logger = Logger(label: "zip-builder.target-definition-factory")

  /// Converts a `ResolvedModule` into a fully resolved `TargetDefinition`.
  ///
  /// - Parameters:
  ///   - module: The resolved SwiftPM module node in the package graph.
  ///   - config: Build plan configuration settings.
  ///   - directDeps: Explicit direct dependency target names. When omitted, direct dependencies
  ///     are inferred from `module.dependencies`.
  ///   - recursiveDeps: Explicit recursive dependency target names. When omitted, transitive
  ///     dependencies are inferred from `module.recursiveModuleDependencies()`.
  ///   - dependencySearchPaths: Header search paths contributed by dependencies.
  ///   - isWrapper: Whether this target represents a synthetic wrapper target.
  /// - Returns: A fully resolved `TargetDefinition`.
  public static func makeTargetDefinition(module: ResolvedModule,
                                          config: Config,
                                          directDeps: [String]? = nil,
                                          recursiveDeps: [String]? = nil,
                                          dependencySearchPaths: [String] = [],
                                          isWrapper: Bool = false) throws -> TargetDefinition {
    let sources = collectSourcesAndHeaders(
      for: module,
      config: config
    )
    let resources = collectResources(
      for: module,
      companionSuffixes: config.companionModuleSuffixes,
      suppressedInternalFrameworks: config.suppressedInternalFrameworks
    )
    let (cSettings, extraHeaderPaths, linkerSettings) = try extractBuildSettings(from: module)

    let exportedSearchPaths = HeaderSearchPathBuilder.exportedSearchPaths(for: module)

    let headerSearchPaths = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
      ownHeaders: sources.filter(\.isHeaderFile),
      explicitSearchPaths: extraHeaderPaths,
      dependencySearchPaths: dependencySearchPaths + exportedSearchPaths,
      baseSearchPaths: config.baseHeaderSearchPaths
    )

    let publicHeadersPath: String? = (module.underlying as? ClangModule)?.includeDir.pathString
    let resolvedDirectDeps = directDeps ?? module.dependencies.map(\.name)
    let resolvedRecursiveDeps = recursiveDeps ??
      (try? module.recursiveModuleDependencies().map(\.name)) ?? []

    logger.debug(
      "Created target definition",
      metadata: [
        "target": "\(module.name)",
        "isBinary": "\(module.isBinary)",
        "isWrapper": "\(isWrapper)",
        "sourceCount": "\(sources.count)",
        "resourceCount": "\(resources.count)",
        "directDepCount": "\(resolvedDirectDeps.count)",
        "searchPathCount": "\(headerSearchPaths.count)",
      ]
    )

    return TargetDefinition(
      name: module.name,
      c99name: module.c99name,
      isBinary: module.isBinary,
      binaryPath: module.isBinary ? module.sources.root.pathString : nil,
      sources: sources,
      dependencies: resolvedDirectDeps,
      recursiveDependencies: resolvedRecursiveDeps,
      resources: resources,
      cSettings: cSettings,
      swiftSettings: [],
      headerSearchPaths: headerSearchPaths,
      exportedHeaderSearchPaths: exportedSearchPaths,
      publicHeadersPath: publicHeadersPath,
      linkerSettings: linkerSettings,
      isWrapper: isWrapper
    )
  }

  /// Converts a `ResolvedModule` into a `TargetDefinition` within an active `ResolutionContext`.
  ///
  /// - Parameters:
  ///   - module: The resolved module to construct a target definition for.
  ///   - directDeps: Explicit direct dependency target names.
  ///   - recursiveDeps: Explicit transitive dependency target names.
  ///   - context: Resolution context containing the module graph, aggregates, and configuration.
  /// - Returns: A fully resolved `TargetDefinition`.
  public static func makeTargetDefinition(module: ResolvedModule,
                                          directDeps: [String],
                                          recursiveDeps: [String],
                                          context: ResolutionContext) throws -> TargetDefinition {
    let depSearchPaths = try collectDependencyHeaderSearchPaths(
      dependencies: recursiveDeps + directDeps,
      context: context
    )
    let sources = collectSourcesAndHeaders(
      for: module,
      config: context.config
    )
    let isWrapper = TargetClassifier.isWrapperTarget(
      name: module.name,
      isBinary: module.isBinary,
      sources: sources,
      config: context.config
    )

    return try makeTargetDefinition(
      module: module,
      config: context.config,
      directDeps: directDeps,
      recursiveDeps: recursiveDeps,
      dependencySearchPaths: depSearchPaths,
      isWrapper: isWrapper
    )
  }

  /// Converts a `ResolvedModule` into a `TargetDefinition` using dependencies discovered from the
  /// context.
  public static func makeTargetDefinition(module: ResolvedModule,
                                          context: ResolutionContext) throws -> TargetDefinition {
    let directDeps = ProductResolver.directDependencies(for: module, context: context)
    let recursiveDeps = ProductResolver.transitiveDependencies(for: module, context: context)

    return try makeTargetDefinition(
      module: module,
      directDeps: directDeps,
      recursiveDeps: recursiveDeps,
      context: context
    )
  }

  // MARK: - Package Extraction Helpers

  /// Collects all source files and headers for a module, merging companion internal headers and
  /// configured extra header folders.
  package static func collectSourcesAndHeaders(for module: ResolvedModule, config: Config)
    -> [String] {
    var sources: [String] = []
    var seenPaths = Set<String>()

    func addPath(_ path: String) {
      if seenPaths.insert(path).inserted {
        sources.append(path)
      }
    }

    for path in module.sources.paths {
      addPath(path.pathString)
    }

    if let clangModule = module.underlying as? ClangModule {
      for header in clangModule.headers {
        addPath(header.pathString)
      }
    }

    // merge companion helper/internal headers (e.g. FirebaseAuthInternal, FirebaseSessionsObjC)
    let allCompanionDeps = (try? module.recursiveModuleDependencies()) ?? []
    for depMod in allCompanionDeps {
      if TargetClassifier.isCompanionModule(
        depMod.name,
        of: module.name,
        companionSuffixes: config.companionModuleSuffixes,
        suppressedInternalFrameworks: config.suppressedInternalFrameworks
      ) {
        if let clangDep = depMod.underlying as? ClangModule {
          for header in clangDep.headers.map(\.pathString) {
            let isExcluded = config.excludedHeaderPathSubstrings.contains(where: header.contains)
            if !isExcluded {
              addPath(header)
            }
          }
        }
      }
    }

    // include helper header directories configured via extraHeaderFolderNames (e.g. Typedefs/)
    for subDir in config.extraHeaderFolderNames {
      let dirPath = module.sources.root.parentDirectory.appending(components: subDir)
      if let contents = try? FileManager.default.contentsOfDirectory(atPath: dirPath.pathString) {
        for file in contents where file.isHeaderFile {
          addPath(dirPath.appending(components: file).pathString)
        }
      }
    }

    return sources
  }

  /// Collects all bundled resources declared by a module and any companion internal modules.
  /// - Parameters:
  ///   - module: The resolved module to extract resources from.
  ///   - companionSuffixes: Suffixes for identifying companion modules.
  ///   - suppressedInternalFrameworks: List of internal companion frameworks that should be merged.
  /// - Returns: An array of `ResourceDefinition` instances.
  package static func collectResources(for module: ResolvedModule,
                                       companionSuffixes: [String] = Config.Defaults
                                         .companionModuleSuffixes,
                                       suppressedInternalFrameworks: [String] = Config.Defaults
                                         .suppressedInternalFrameworks) -> [ResourceDefinition] {
    var resources: [ResourceDefinition] = []
    var seenPaths = Set<String>()

    func addResource(_ res: ResourceDefinition) {
      if seenPaths.insert(res.path).inserted {
        resources.append(res)
      }
    }

    for res in module.underlying.resources {
      addResource(ResourceDefinition(
        name: res.path.basename,
        path: res.path.pathString,
        rule: "\(res.rule)"
      ))
    }

    let allCompanionDeps = (try? module.recursiveModuleDependencies()) ?? []
    for depMod in allCompanionDeps {
      if TargetClassifier.isCompanionModule(
        depMod.name,
        of: module.name,
        companionSuffixes: companionSuffixes,
        suppressedInternalFrameworks: suppressedInternalFrameworks
      ) {
        for res in depMod.underlying.resources {
          addResource(ResourceDefinition(
            name: res.path.basename,
            path: res.path.pathString,
            rule: "\(res.rule)"
          ))
        }
      }
    }

    return resources
  }

  /// Extracts C compiler flags, explicit header search paths, and linker flags from a module's
  /// build settings.
  /// - Parameter module: The resolved module to extract settings from.
  /// - Returns: A tuple containing C compiler flags, explicit header search paths, and linker flag
  /// directives.
  package static func extractBuildSettings(from module: ResolvedModule) throws
    -> (cSettings: [String], headerSearchPaths: [String], linkerSettings: [String]) {
    var cSettings: [String] = []
    var headerSearchPaths: [String] = []
    var linkerSettings: Set<String> = []

    for (key, assignments) in module.underlying.buildSettings.assignments {
      let values = assignments.flatMap(\.values)
      switch key {
      case .HEADER_SEARCH_PATHS:
        try headerSearchPaths.append(contentsOf: values.compactMap { try resolveSearchPath(
          $0,
          relativeTo: module.sources.root
        ) })
      case .GCC_PREPROCESSOR_DEFINITIONS, .OTHER_CFLAGS, .OTHER_CPLUSPLUSFLAGS:
        cSettings.append(contentsOf: values)
      case .LINK_FRAMEWORKS:
        linkerSettings.formUnion(values.map { "framework:\($0)" })
      case .LINK_LIBRARIES:
        linkerSettings.formUnion(values.map { "library:\($0)" })
      default:
        break
      }
    }

    return (cSettings, headerSearchPaths, Array(linkerSettings).sorted())
  }

  /// Collects public and internal header search paths exposed by dependencies.
  /// - Parameters:
  ///   - dependencies: List of dependency module or target names.
  ///   - context: The resolution context providing access to aggregates and module maps.
  /// - Returns: A sorted array of unique directory search paths.
  package static func collectDependencyHeaderSearchPaths(dependencies: [String],
                                                         context: ResolutionContext) throws
    -> [String] {
    var paths = Set<String>()
    for depName in dependencies {
      try paths.formUnion(searchPaths(forDependency: depName, context: context))
    }

    return paths.sorted()
  }

  /// Resolves a raw header search path string, preserving Xcode macros or resolving relative paths
  /// against a base directory.
  ///
  /// - Parameters:
  ///   - path: The raw search path string to resolve.
  ///   - relativeTo: The base directory used to resolve relative paths.
  /// - Returns: A normalized path string, or `nil` if the input is empty or whitespace-only.
  /// - Throws: An error if the path cannot be validated as a valid filesystem path.
  private static func resolveSearchPath(_ path: String,
                                        relativeTo: AbsolutePath) throws -> String? {
    let trimmed = path.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    if HeaderSearchPathBuilder.isXcodeMacro(trimmed) {
      return trimmed
    }

    if let absolutePath = try? AbsolutePath(validating: trimmed) {
      return absolutePath.pathString
    }

    return try AbsolutePath(validating: trimmed, relativeTo: relativeTo).pathString
  }

  /// Resolves the header search paths that a dependency contributes to its consumers.
  ///
  /// For internal companions and wrapper modules (as determined by
  /// `context.shouldExposeInternalHeaders`),
  /// full internal search paths are exposed. For regular dependencies, only public exported search
  /// paths are returned.
  ///
  /// - Parameters:
  ///   - depName: Name of the dependency target or module.
  ///   - context: Active plan resolution context.
  /// - Returns: An array of resolved header search paths for the dependency.
  /// - Throws: An error if target definition construction fails.
  private static func searchPaths(forDependency depName: String,
                                  context: ResolutionContext) throws -> [String] {
    let mapped = context.mappedTargetName(for: depName)
    if let aggregate = context.aggregate(named: mapped) {
      return aggregate.exportedHeaderSearchPaths
    }

    guard let depMod = context.module(named: mapped) ?? context.module(named: depName) else {
      return []
    }

    if context.shouldExposeInternalHeaders(forDependency: mapped, module: depMod) {
      let companionTarget = try makeTargetDefinition(module: depMod, config: context.config)

      return HeaderSearchPathBuilder.filterConcretePaths(companionTarget.headerSearchPaths)
    } else {
      return HeaderSearchPathBuilder.exportedSearchPaths(for: depMod)
    }
  }
}
