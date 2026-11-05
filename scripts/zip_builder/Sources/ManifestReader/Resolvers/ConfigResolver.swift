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

/// Resolves complete, immutable `Config` instances by combining configuration file declarations,
/// SwiftPM package graph inference, and CLI options.
public enum ConfigResolver: Sendable {
  private static let logger = Logger(label: "zip-builder.config-resolver")

  /// Loads, parses, and resolves a complete `Config` instance from an optional configuration file
  /// URL, the resolved SwiftPM package graph, and build options.
  public static func resolve(from configURL: URL?,
                             graph: ModulesGraph,
                             options: BuildOptions? = nil) throws -> Config {
    let fileConfig: ProductConfigFile
    if let configURL {
      fileConfig = try ProductConfigFile.load(from: configURL)
    } else {
      fileConfig = ProductConfigFile()
    }

    let bundleIdPrefix = try resolveBundleIdPrefix(
      config: fileConfig,
      bundleIdPrefix: options?.bundleIdPrefix
    )
    let projectName = try resolveProjectName(
      config: fileConfig,
      graph: graph,
      projectName: options?.projectName
    )
    let version = try VersionResolver.resolveVersion(
      config: fileConfig,
      graph: graph,
      projectName: projectName,
      version: options?.version
    )
    let deploymentTargets = resolveDeploymentTargets(config: fileConfig, graph: graph)

    // merge build settings (CLI options override file config)
    var effectiveBuildSettings = fileConfig.buildSettings ?? [:]
    if let overrideSettings = options?.buildSettings {
      for (k, v) in overrideSettings {
        effectiveBuildSettings[k] = v
      }
    }

    let targetLower = options?.target?.lowercased()
    let rawExtraFiles = fileConfig.extraFiles ?? []
    let effectiveExtraFiles: [ExtraFiles]
    if let targetLower {
      // only include extra files if they belong to the target, or if they're top level extra files
      effectiveExtraFiles = rawExtraFiles.filter {
        $0.destination.lowercased() == targetLower || $0.destination == "."
      }
    } else {
      effectiveExtraFiles = rawExtraFiles
    }

    let rawExternalArtifacts = fileConfig.externalArtifacts ?? []
    let effectiveExternalArtifacts: [ExternalArtifact]
    if let targetLower {
      // only include external artifacts belonging to the target
      effectiveExternalArtifacts = rawExternalArtifacts.filter {
        $0.productName.lowercased() == targetLower
      }
    } else {
      effectiveExternalArtifacts = rawExternalArtifacts
    }

    let filterWrapper = options?.filterWrapperTargets ?? fileConfig.filterWrapperTargets
    let stripSignatures = options?.stripExternalBinaryCodeSignatures ?? fileConfig
      .stripExternalBinaryCodeSignatures
    let enableVerifier = options?.enableModuleVerifier ?? fileConfig.enableModuleVerifier
    let targetPlatforms = options?.targetPlatforms
    let productPlatformOverrides = options?.productPlatformOverrides ?? fileConfig
      .productPlatformOverrides
    let buildSettings = effectiveBuildSettings.isEmpty ? nil : effectiveBuildSettings
    let wrapperTargetNames = options?.wrapperTargetNames ?? fileConfig.wrapperTargetNames
    let wrapperTargetPatterns = options?.wrapperTargetPatterns ?? fileConfig.wrapperTargetPatterns
    let companionModuleSuffixes = options?.companionModuleSuffixes ?? fileConfig
      .companionModuleSuffixes
    let stubFileNames = options?.stubFileNames ?? fileConfig.stubFileNames
    let stubFilePatterns = options?.stubFilePatterns ?? fileConfig.stubFilePatterns

    return Config(
      version: version,
      projectName: projectName,
      bundleIdPrefix: bundleIdPrefix,
      deploymentTargets: deploymentTargets,
      versionMacroName: fileConfig.versionMacroName,
      skippedProductFolders: fileConfig.skippedProductFolders,
      baseProduct: fileConfig.baseProduct,
      extraFiles: effectiveExtraFiles,
      excludedProducts: fileConfig.excludedProducts,
      extraProducts: fileConfig.extraProducts,
      products: fileConfig.products,
      renamedProducts: fileConfig.renamedProducts,
      externalArtifacts: effectiveExternalArtifacts,
      publicHeaderFolderNames: fileConfig.publicHeaderFolderNames,
      filterWrapperTargets: filterWrapper,
      stripExternalBinaryCodeSignatures: stripSignatures,
      suppressedInternalFrameworks: fileConfig.suppressedInternalFrameworks,
      productPlatformOverrides: productPlatformOverrides,
      extraFrameworksPerProduct: fileConfig.extraFrameworksPerProduct,
      targetArchitectures: fileConfig.targetArchitectures,
      enableModuleVerifier: enableVerifier,
      buildSettings: buildSettings,
      targetPlatforms: targetPlatforms,
      wrapperTargetNames: wrapperTargetNames,
      wrapperTargetPatterns: wrapperTargetPatterns,
      wrapperSourceFolderNames: fileConfig.wrapperSourceFolderNames,
      aggregatePackageNames: fileConfig.aggregatePackageNames,
      baseHeaderSearchPaths: fileConfig.baseHeaderSearchPaths,
      extraHeaderFolderNames: fileConfig.extraHeaderFolderNames,
      excludedHeaderPathSubstrings: fileConfig.excludedHeaderPathSubstrings,
      companionModuleSuffixes: companionModuleSuffixes,
      stubFileNames: stubFileNames,
      stubFilePatterns: stubFilePatterns
    )
  }

  /// Constructs an updated `Config` by applying options and overrides to an existing configuration.
  ///
  /// Used when a build plan is specified via an argument instead of automatically created.
  public static func apply(options: BuildOptions, to config: Config) -> Config {
    let newVersion = options.version ?? config.version
    let newProjectName = options.projectName ?? config.projectName
    let newBundleIdPrefix = options.bundleIdPrefix ?? config.bundleIdPrefix
    let newFilterWrapper = options.filterWrapperTargets ?? config.filterWrapperTargets
    let newStripSignatures = options
      .stripExternalBinaryCodeSignatures ?? config.stripExternalBinaryCodeSignatures
    let newEnableVerifier = options.enableModuleVerifier ?? config.enableModuleVerifier
    let newTargetPlatforms = options.targetPlatforms ?? config.targetPlatforms

    var effectiveBuildSettings = config.buildSettings
    if let overrideSettings = options.buildSettings {
      for (k, v) in overrideSettings {
        effectiveBuildSettings[k] = v
      }
    }

    let targetLower = options.target?.lowercased()
    let effectiveExtraFiles: [ExtraFiles]
    let effectiveExternalArtifacts: [ExternalArtifact]
    if let targetLower {
      effectiveExtraFiles = config.extraFiles.filter {
        $0.destination.lowercased() == targetLower || $0.destination == "."
      }
      effectiveExternalArtifacts = config.externalArtifacts.filter {
        $0.productName.lowercased() == targetLower
      }
    } else {
      effectiveExtraFiles = config.extraFiles
      effectiveExternalArtifacts = config.externalArtifacts
    }

    return Config(
      version: newVersion,
      projectName: newProjectName,
      bundleIdPrefix: newBundleIdPrefix,
      deploymentTargets: config.deploymentTargets,
      versionMacroName: config.versionMacroName,
      skippedProductFolders: config.skippedProductFolders,
      baseProduct: config.baseProduct,
      extraFiles: effectiveExtraFiles,
      excludedProducts: config.excludedProducts,
      extraProducts: config.extraProducts,
      products: config.products,
      renamedProducts: config.renamedProducts,
      externalArtifacts: effectiveExternalArtifacts,
      publicHeaderFolderNames: config.publicHeaderFolderNames,
      filterWrapperTargets: newFilterWrapper,
      stripExternalBinaryCodeSignatures: newStripSignatures,
      suppressedInternalFrameworks: config.suppressedInternalFrameworks,
      productPlatformOverrides: options.productPlatformOverrides ?? config
        .productPlatformOverrides,
      extraFrameworksPerProduct: config.extraFrameworksPerProduct,
      targetArchitectures: config.targetArchitectures,
      enableModuleVerifier: newEnableVerifier,
      buildSettings: effectiveBuildSettings,
      targetPlatforms: newTargetPlatforms,
      wrapperTargetNames: options.wrapperTargetNames ?? config.wrapperTargetNames,
      wrapperTargetPatterns: options.wrapperTargetPatterns ?? config.wrapperTargetPatterns,
      wrapperSourceFolderNames: config.wrapperSourceFolderNames,
      aggregatePackageNames: config.aggregatePackageNames,
      baseHeaderSearchPaths: config.baseHeaderSearchPaths,
      extraHeaderFolderNames: config.extraHeaderFolderNames,
      excludedHeaderPathSubstrings: config.excludedHeaderPathSubstrings,
      companionModuleSuffixes: options.companionModuleSuffixes ?? config
        .companionModuleSuffixes,
      stubFileNames: options.stubFileNames ?? config.stubFileNames,
      stubFilePatterns: options.stubFilePatterns ?? config.stubFilePatterns
    )
  }

  private static func resolveBundleIdPrefix(config: ProductConfigFile,
                                            bundleIdPrefix: String?) throws -> String {
    if let bundleIdPrefix, !bundleIdPrefix.isEmpty {
      logger.debug("Overriding bundleIdPrefix", metadata: [
        "bundleIdPrefix": "\(bundleIdPrefix)",
      ])
      return bundleIdPrefix
    }

    guard let prefix = config.bundleIdPrefix, !prefix.isEmpty else {
      throw LoadConfigError.missingBundleIdPrefix
    }
    return prefix
  }

  /// Resolves the Xcode project name according to the following precedence:
  /// 1. Explicit CLI argument (`--project-name`).
  /// 2. Declared project name in config file (`config.projectName`).
  /// 3. Inferred root package manifest name (the `name:` parameter of `Package(name: ...)` in
  /// `Package.swift`).
  ///
  /// - Throws: `LoadConfigError.missingProjectName` if all sources are missing or empty.
  private static func resolveProjectName(config: ProductConfigFile,
                                         graph: ModulesGraph,
                                         projectName: String?) throws -> String {
    if let projectName, !projectName.isEmpty {
      logger.debug("Overriding project name", metadata: [
        "projectName": "\(projectName)",
      ])
      return projectName
    }

    if let projectName = config.projectName, !projectName.isEmpty {
      logger.debug("Using project name from config", metadata: [
        "projectName": "\(projectName)",
      ])
      return projectName
    }

    guard let manifestName = graph.rootPackages.first?.manifest.displayName,
          !manifestName.isEmpty else {
      throw LoadConfigError.missingProjectName
    }

    logger.debug("Resolved project name from root package", metadata: [
      "projectName": "\(manifestName)",
    ])
    return manifestName
  }

  /// Resolves the minimum deployment targets for all supported Apple platforms.
  ///
  /// If deployment targets are omitted from configuration, they are inferred directly from
  /// the root package manifest (`Package.swift` `platforms: [...]`)
  ///
  /// Any explicit targets defined in `config.deploymentTargets` override these manifest
  /// baselines.
  private static func resolveDeploymentTargets(config: ProductConfigFile,
                                               graph: ModulesGraph) -> DeploymentTargets {
    guard let rootPackage = graph.rootPackages.first else {
      return DeploymentTargets()
    }

    let standardPlatforms: [PackageModel.Platform] = [
      .iOS, .macOS, .tvOS, .watchOS, .visionOS, .macCatalyst,
    ]

    var platformVersions: [PackageModel.Platform: PlatformVersion] = [:]

    for standard in standardPlatforms {
      let supported = rootPackage.getSupportedPlatform(for: standard, usingXCTest: false)
      platformVersions[standard] = supported.version
    }
    logger.debug("Resolved baseline deployment targets from root package", metadata: [
      "platformVersions": "\(platformVersions)",
    ])

    // versions defined in the config override the baseline versions
    if let configOverrides = config.deploymentTargets {
      for (key, val) in configOverrides {
        guard !val.isEmpty else { continue }
        logger.debug("Overwriting deployment target", metadata: [
          "platform": "\(key)",
          "target": "\(val)",
        ])

        let spmPlatform = Platform.from(platformName: key).spmPlatform
        platformVersions[spmPlatform] = PlatformVersion(val)
      }
    }

    return DeploymentTargets(platforms: platformVersions.map { SupportedPlatform(
      platform: $0.key,
      version: $0.value
    ) })
  }
}
