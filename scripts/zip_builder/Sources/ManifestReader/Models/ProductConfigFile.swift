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

/// The raw, unvalidated configuration file schema decoded from `zip_builder.json`.
public struct ProductConfigFile: Codable, Sendable, Equatable {
  public let version: Version?
  public let projectName: String?
  public let bundleIdPrefix: String?
  public let versionMacroName: String?
  public let skippedProductFolders: [String]?
  public let baseProduct: BaseProduct?
  public let extraFiles: [ExtraFiles]?
  public let excludedProducts: [String]?
  public let extraProducts: [Config.ProductEntry]?
  public let products: [Config.ProductEntry]?
  public let renamedProducts: [String: String]?
  public let externalArtifacts: [ExternalArtifact]?
  public let deploymentTargets: [String: String]?
  public let publicHeaderFolderNames: [String]?
  public let filterWrapperTargets: Bool?
  public let stripExternalBinaryCodeSignatures: Bool?
  public let suppressedInternalFrameworks: [String]?
  public let productPlatformOverrides: [String: [Platform]]?
  public let extraFrameworksPerProduct: [String: [String]]?
  public let targetArchitectures: [String: [String]]?
  public let enableModuleVerifier: Bool?
  public let buildSettings: [String: String]?
  public let wrapperTargetNames: [String]?
  public let wrapperTargetPatterns: [String]?
  public let wrapperSourceFolderNames: [String]?
  public let aggregatePackageNames: [String]?
  public let baseHeaderSearchPaths: [String]?
  public let extraHeaderFolderNames: [String]?
  public let excludedHeaderPathSubstrings: [String]?
  public let companionModuleSuffixes: [String]?
  public let stubFileNames: [String]?
  public let stubFilePatterns: [String]?

  public init(version: Version? = nil,
              projectName: String? = nil,
              bundleIdPrefix: String? = nil,
              versionMacroName: String? = nil,
              skippedProductFolders: [String]? = nil,
              baseProduct: BaseProduct? = nil,
              extraFiles: [ExtraFiles]? = nil,
              excludedProducts: [String]? = nil,
              extraProducts: [Config.ProductEntry]? = nil,
              products: [Config.ProductEntry]? = nil,
              renamedProducts: [String: String]? = nil,
              externalArtifacts: [ExternalArtifact]? = nil,
              deploymentTargets: [String: String]? = nil,
              publicHeaderFolderNames: [String]? = nil,
              filterWrapperTargets: Bool? = nil,
              stripExternalBinaryCodeSignatures: Bool? = nil,
              suppressedInternalFrameworks: [String]? = nil,
              productPlatformOverrides: [String: [Platform]]? = nil,
              extraFrameworksPerProduct: [String: [String]]? = nil,
              targetArchitectures: [String: [String]]? = nil,
              enableModuleVerifier: Bool? = nil,
              buildSettings: [String: String]? = nil,
              wrapperTargetNames: [String]? = nil,
              wrapperTargetPatterns: [String]? = nil,
              wrapperSourceFolderNames: [String]? = nil,
              aggregatePackageNames: [String]? = nil,
              baseHeaderSearchPaths: [String]? = nil,
              extraHeaderFolderNames: [String]? = nil,
              excludedHeaderPathSubstrings: [String]? = nil,
              companionModuleSuffixes: [String]? = nil,
              stubFileNames: [String]? = nil,
              stubFilePatterns: [String]? = nil) {
    self.version = version
    self.projectName = projectName
    self.bundleIdPrefix = bundleIdPrefix
    self.versionMacroName = versionMacroName
    self.skippedProductFolders = skippedProductFolders
    self.baseProduct = baseProduct
    self.extraFiles = extraFiles
    self.excludedProducts = excludedProducts
    self.extraProducts = extraProducts
    self.products = products
    self.renamedProducts = renamedProducts
    self.externalArtifacts = externalArtifacts
    self.deploymentTargets = deploymentTargets
    self.publicHeaderFolderNames = publicHeaderFolderNames
    self.filterWrapperTargets = filterWrapperTargets
    self.stripExternalBinaryCodeSignatures = stripExternalBinaryCodeSignatures
    self.suppressedInternalFrameworks = suppressedInternalFrameworks
    self.productPlatformOverrides = productPlatformOverrides
    self.extraFrameworksPerProduct = extraFrameworksPerProduct
    self.targetArchitectures = targetArchitectures
    self.enableModuleVerifier = enableModuleVerifier
    self.buildSettings = buildSettings
    self.wrapperTargetNames = wrapperTargetNames
    self.wrapperTargetPatterns = wrapperTargetPatterns
    self.wrapperSourceFolderNames = wrapperSourceFolderNames
    self.aggregatePackageNames = aggregatePackageNames
    self.baseHeaderSearchPaths = baseHeaderSearchPaths
    self.extraHeaderFolderNames = extraHeaderFolderNames
    self.excludedHeaderPathSubstrings = excludedHeaderPathSubstrings
    self.companionModuleSuffixes = companionModuleSuffixes
    self.stubFileNames = stubFileNames
    self.stubFilePatterns = stubFilePatterns
  }

  /// Loads and parses the raw JSON config file, stripping single-line comments.
  public static func load(from url: URL) throws -> ProductConfigFile {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.allowsJSON5 = true

    return try decoder.decode(ProductConfigFile.self, from: data)
  }
}
