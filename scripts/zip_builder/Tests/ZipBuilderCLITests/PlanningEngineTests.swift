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

import ArgumentParser
import Common
import Foundation
import Logging
import ManifestReader
import Testing
@testable import ZipBuilderCLI

struct PlanningEngineTests {
  private func resolve(planOptions: PlanOptions? = nil,
                       manifestOptions: ManifestOptions,
                       platformOptions: PlatformOptions? = nil,
                       targetOptions: TargetOptions? = nil,
                       logger: Logger) async throws -> BuildPlan {
    let options = try manifestOptions.buildOptions(
      platformOptions: platformOptions,
      targetOptions: targetOptions
    )
    return try await PlanningEngine.resolve(
      planURL: planOptions?.planURL,
      options: options,
      logger: logger
    )
  }

  @Test
  func resolveBuildPlanFromPlanFileWithOverrides() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_plan_res_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let dummyTarget = TargetDefinition(
      name: "TestTarget",
      c99name: "TestTarget",
      isBinary: false,
      sources: ["/path/to/source.swift"],
      dependencies: [],
      recursiveDependencies: [],
      resources: [],
      cSettings: [],
      swiftSettings: [],
      headerSearchPaths: [],
      publicHeadersPath: nil,
      linkerSettings: []
    )

    let dummyProduct = ProductPlan(
      name: "TestProduct",
      targets: [dummyTarget],
      binaryTargets: [],
      extraFrameworks: [],
      declaredTargetNames: ["TestTarget"],
      platforms: [.ios],
      dynamicFrameworks: [],
      resourceBundles: [],
      customCompilerFlags: [:]
    )

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "OriginalProject",
      bundleIdPrefix: "com.original.sdk",
      deploymentTargets: ["iOS": "13.0"]
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: [dummyProduct]
    )

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")

    // 1. Resolve without overrides
    let planOptionsNoOverride = try PlanOptions.parse(["--plan", planFile.path])
    let manifestOptionsNoOverride = try ManifestOptions.parse([])

    let resolvedPlan = try await resolve(
      planOptions: planOptionsNoOverride,
      manifestOptions: manifestOptionsNoOverride,
      logger: logger
    )

    #expect(resolvedPlan.config.version == "1.0.0")
    #expect(resolvedPlan.config.projectName == "OriginalProject")
    #expect(resolvedPlan.config.bundleIdPrefix == "com.original.sdk")
    #expect(resolvedPlan.products.count == 1)
    #expect(resolvedPlan.products.first?.name == "TestProduct")

    // 2. Resolve with CLI overrides in manifestOptions
    let manifestOptionsWithOverrides = try ManifestOptions.parse([
      "--version", "2.5.0",
      "--project-name", "OverriddenProject",
      "--bundle-id-prefix", "com.overridden.sdk",
    ])

    let overriddenPlan = try await resolve(
      planOptions: planOptionsNoOverride,
      manifestOptions: manifestOptionsWithOverrides,
      logger: logger
    )

    #expect(overriddenPlan.config.version == "2.5.0")
    #expect(overriddenPlan.config.projectName == "OverriddenProject")
    #expect(overriddenPlan.config.bundleIdPrefix == "com.overridden.sdk")
    #expect(overriddenPlan.products.count == 1)
  }

  @Test
  func resolveBuildPlanWithTargetFilter() async throws {
    let dummyTargetA = TargetDefinition(
      name: "TargetA",
      c99name: "TargetA",
      isBinary: false,
      sources: ["/path/to/A.swift"]
    )
    let dummyTargetB = TargetDefinition(
      name: "TargetB",
      c99name: "TargetB",
      isBinary: false,
      sources: ["/path/to/B.swift"]
    )
    let productA = ProductPlan(name: "ProductA", targets: [dummyTargetA])
    let productB = ProductPlan(name: "ProductB", targets: [dummyTargetB])

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "MultiProduct",
      bundleIdPrefix: "com.test"
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: [productA, productB]
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_target_filter_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")

    let planOptions = try PlanOptions.parse(["--plan", planFile.path])
    let manifestOptions = try ManifestOptions.parse([])
    let targetOptions = try TargetOptions.parse(["-t", "ProductA"])

    let filteredPlan = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      targetOptions: targetOptions,
      logger: logger
    )

    #expect(filteredPlan.products.count == 1)
    #expect(filteredPlan.products.first?.name == "ProductA")
  }

  @Test
  func planCLIArgumentParsing() throws {
    let planCommand = try Plan.parse([
      "--package-path", "/dummy/repo",
      "--platforms", "ios",
      "--platforms", "tvos",
      "-t", "FirebaseAuth",
      "--summary",
    ])

    #expect(planCommand.manifestOptions.packagePath == "/dummy/repo")
    #expect(planCommand.platformOptions.platforms == [.ios, .tvos])
    #expect(planCommand.targetOptions.target == "FirebaseAuth")
    #expect(planCommand.format == .summary)
  }

  @Test
  func resolveBuildPlanWithPlatformFiltering() async throws {
    let dummyTarget = TargetDefinition(
      name: "TestTarget",
      c99name: "TestTarget",
      isBinary: false,
      sources: ["/path/to/source.swift"]
    )
    let dummyProduct = ProductPlan(
      name: "MultiPlatformProduct",
      targets: [dummyTarget],
      platforms: [.ios, .macos, .tvos, .watchos, .catalyst]
    )
    let watchOSOnlyProduct = ProductPlan(
      name: "WatchOSOnlyProduct",
      targets: [dummyTarget],
      platforms: [.watchos]
    )
    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "MultiPlatformProject",
      bundleIdPrefix: "com.test.sdk",
      targetPlatforms: [.ios, .macos, .tvos, .watchos, .catalyst]
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: [dummyProduct, watchOSOnlyProduct]
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_platform_filter_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")
    let planOptions = try PlanOptions.parse(["--plan", planFile.path])
    let manifestOptions = try ManifestOptions.parse([])
    let platformOptions = try PlatformOptions.parse(["--platforms", "ios", "--platforms", "macos"])

    let resolvedPlan = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      platformOptions: platformOptions,
      logger: logger
    )

    #expect(resolvedPlan.config.targetPlatforms == [.ios, .macos])
    #expect(resolvedPlan.products.count == 1)
    #expect(resolvedPlan.products.first?.name == "MultiPlatformProduct")
    #expect(resolvedPlan.products.first?.platforms == [.ios, .macos])
    #expect(resolvedPlan.products.contains(where: { $0.name == "WatchOSOnlyProduct" }) == false)
  }

  @Test
  func newFlagsParsingAndResolution() async throws {
    let manifestOptions = try ManifestOptions.parse([
      "--strip-external-code-signatures",
      "--no-filter-wrapper-targets",
    ])
    #expect(manifestOptions.stripExternalBinaryCodeSignatures == true)
    #expect(manifestOptions.noFilterWrapperTargets == true)

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "TestProj",
      bundleIdPrefix: "com.test",
      filterWrapperTargets: true,
      stripExternalBinaryCodeSignatures: false
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: []
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_flags_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")
    let planOptions = try PlanOptions.parse(["--plan", planFile.path])

    let resolved = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      logger: logger
    )
    #expect(resolved.config.stripExternalBinaryCodeSignatures == true)
    #expect(resolved.config.filterWrapperTargets == false)
  }

  @Test
  func enableModuleVerifierFlagAndOverride() async throws {
    let manifestOptions = try ManifestOptions.parse([
      "--enable-module-verifier",
    ])
    #expect(manifestOptions.enableModuleVerifier == true)

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "TestProj",
      bundleIdPrefix: "com.test",
      enableModuleVerifier: false
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: []
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_mv_flags_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")
    let planOptions = try PlanOptions.parse(["--plan", planFile.path])

    let resolved = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      logger: logger
    )
    #expect(resolved.config.enableModuleVerifier == true)
  }

  @Test
  func customBuildSettingsFlagAndOverride() async throws {
    let manifestOptions = try ManifestOptions.parse([
      "-s", "SWIFT_OPTIMIZATION_LEVEL=-Onone",
      "--build-setting", "OTHER_SWIFT_FLAGS=-DDEBUG",
    ])
    let parsed = manifestOptions.parsedBuildSettings()
    #expect(parsed["SWIFT_OPTIMIZATION_LEVEL"] == "-Onone")
    #expect(parsed["OTHER_SWIFT_FLAGS"] == "-DDEBUG")

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "TestProj",
      bundleIdPrefix: "com.test",
      buildSettings: [
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "EXISTING_SETTING": "VAL",
      ]
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: []
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_bs_flags_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")
    let planOptions = try PlanOptions.parse(["--plan", planFile.path])

    let resolved = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      logger: logger
    )
    #expect(resolved.config.buildSettings["SWIFT_OPTIMIZATION_LEVEL"] == "-Onone")
    #expect(resolved.config.buildSettings["OTHER_SWIFT_FLAGS"] == "-DDEBUG")
    #expect(resolved.config.buildSettings["EXISTING_SETTING"] == "VAL")
  }

  @Test
  func customWrapperPatternAndCompanionSuffixCLIFlags() async throws {
    let manifestOptions = try ManifestOptions.parse([
      "--wrapper-target-pattern", "*CustomWrapper",
      "--wrapper-target-pattern", "*Synthetic",
      "--companion-module-suffix", "Companion",
      "--companion-module-suffix", "Support",
    ])
    #expect(manifestOptions.wrapperTargetPatterns == ["*CustomWrapper", "*Synthetic"])
    #expect(manifestOptions.companionModuleSuffixes == ["Companion", "Support"])

    let dummyConfig = Config(
      version: "1.0.0",
      projectName: "TestProj",
      bundleIdPrefix: "com.test"
    )
    let dummyPlan = BuildPlan(
      config: dummyConfig,
      products: []
    )

    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_pattern_flags_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let planFile = tempDir.appendingPathComponent("plan.json")
    try dummyPlan.write(to: planFile)

    let logger = Logger(label: "test")
    let planOptions = try PlanOptions.parse(["--plan", planFile.path])

    let resolved = try await resolve(
      planOptions: planOptions,
      manifestOptions: manifestOptions,
      logger: logger
    )
    #expect(resolved.config.wrapperTargetPatterns == ["*CustomWrapper", "*Synthetic"])
    #expect(resolved.config.companionModuleSuffixes == ["Companion", "Support"])
  }

  @Test
  func defaultZipBuilderConfigSearchPath() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let defaultConfigFile = repoRoot.appendingPathComponent("zip_builder.jsonc")
    #expect(FileManager.default.fileExists(atPath: defaultConfigFile.path))

    let logger = Logger(label: "test")
    let resolvedPlan = try await PlanningEngine.resolve(
      packageURL: repoRoot,
      configURL: nil,
      logger: logger
    )

    #expect(resolvedPlan.config.projectName == "Firebase")
    #expect(resolvedPlan.config.bundleIdPrefix == "com.google.firebase")
    #expect(!resolvedPlan.products.isEmpty)
  }

  @Test
  func productConfigFileSupportsJsonAndJsoncExtensions() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_jsonc_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let contentWithComments = """
    {
      // Single-line comment in config
      "projectName": "CustomProject",
      "bundleIdPrefix": "com.custom.sdk"
    }
    """

    let jsonURL = tempDir.appendingPathComponent("zip_builder.json")
    let jsoncURL = tempDir.appendingPathComponent("zip_builder.jsonc")
    try contentWithComments.write(to: jsonURL, atomically: true, encoding: .utf8)
    try contentWithComments.write(to: jsoncURL, atomically: true, encoding: .utf8)

    let parsedJson = try ProductConfigFile.load(from: jsonURL)
    let parsedJsonc = try ProductConfigFile.load(from: jsoncURL)

    #expect(parsedJson.projectName == "CustomProject")
    #expect(parsedJson.bundleIdPrefix == "com.custom.sdk")
    #expect(parsedJsonc == parsedJson)
  }
}
