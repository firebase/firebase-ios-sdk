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
import ManifestReader
@preconcurrency import PackageGraph
import Testing

struct ManifestReaderTests {
  @Test func loaderInit() {
    let testPath = URL(filePath: "/tmp/firebase-ios-sdk")
    let loader = PackageGraphLoader(packagePath: testPath)
    #expect(loader.packagePath.path == "/tmp/firebase-ios-sdk")
  }

  @Test func configFileSchemaDecoding() throws {
    let json = """
    {
      "version": "12.18.0",
      "products": [
        {
          "name": "FirebaseAuth",
          "targets": ["FirebaseAuth"],
          "resourceBundles": [],
          "customCompilerFlags": {}
        }
      ]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(ProductConfigFile.self, from: data)
    #expect(config.version == "12.18.0")
    #expect(config.products?.count == 1)
    #expect(config.products?.first?.name == "FirebaseAuth")
    #expect(config.products?.first?.targets == ["FirebaseAuth"])
  }

  @Test func renamedProductsDecoding() throws {
    let json = """
    {
      "products": [],
      "renamedProducts": {
        "GTMSessionFetcherCore": "GTMSessionFetcher"
      }
    }
    """
    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(ProductConfigFile.self, from: data)
    #expect(config.renamedProducts?["GTMSessionFetcherCore"] == "GTMSessionFetcher")
  }

  @Test func externalArtifactDecoding() throws {
    let json = """
    {
      "products": [],
      "externalArtifacts": [
        {
          "productName": "GoogleSignIn",
          "url": "https://dl.google.com/dl/firebase/ios/carthage/{version}/GoogleSignIn.zip",
          "subpath": "GoogleSignIn"
        }
      ]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(ProductConfigFile.self, from: data)
    #expect(config.externalArtifacts?.count == 1)
    #expect(config.externalArtifacts?.first?.productName == "GoogleSignIn")
  }

  @Test func distributionConfigDecoding() throws {
    let json = """
    {
      "projectName": "Firebase",
      "bundleIdPrefix": "com.google.firebase",
      "versionMacroName": "Firebase_VERSION",
      "skippedProductFolders": ["Firebase", "FirebaseCore"],
      "baseProduct": {
        "product": "FirebaseAnalytics",
        "frameworks": ["FirebaseCore", "GoogleUtilities"]
      },
      "extraFiles": [
        {
          "product": "FirebaseCrashlytics",
          "files": ["Crashlytics/run"]
        },
        {
          "destination": ".",
          "files": ["CoreOnly/NOTICES", "CoreOnly/Sources/Firebase.h"]
        }
      ],
      "products": []
    }
    """
    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(ProductConfigFile.self, from: data)
    #expect(config.projectName == "Firebase")
    #expect(config.bundleIdPrefix == "com.google.firebase")
    #expect(config.versionMacroName == "Firebase_VERSION")
    #expect(config.skippedProductFolders == ["Firebase", "FirebaseCore"])
    #expect(config.baseProduct?.product == "FirebaseAnalytics")
    #expect(config.baseProduct?.frameworks == ["FirebaseCore", "GoogleUtilities"])
    #expect(config.extraFiles?.count == 2)
    #expect(config.extraFiles?.first?.destination == "FirebaseCrashlytics")
    #expect(config.extraFiles?.first?.files == ["Crashlytics/run"])
    #expect(config.extraFiles?.last?.destination == ".")
    #expect(config.extraFiles?.last?.files == ["CoreOnly/NOTICES", "CoreOnly/Sources/Firebase.h"])
  }

  @Test func packageGraphTargetResolution() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent() // ManifestReaderTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // zip_builder
      .deletingLastPathComponent() // scripts
      .deletingLastPathComponent() // repo root
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()
    let configFile = repoRoot
      .appendingPathComponent("zip_builder.json")
    let config = try ConfigResolver.resolve(from: configFile, graph: graph)
    let plan = try BuildPlanResolver.resolveBuildPlan(from: graph, config: config)

    guard let appCheck = plan.products.first(where: { $0.name == "FirebaseAppCheck" }) else {
      Issue.record("FirebaseAppCheck product not found")
      return
    }
    let targetNames = appCheck.targets.map(\.name)
    #expect(targetNames.contains("AppCheckRecaptchaProvider"))
    #expect(targetNames.contains("AppCheckCore"))
  }

  @Test func exportedSearchPathsWithNamespaceSubfolder() throws {
    let includeDir = "/repo/FirebaseCore/Sources/Public"
    let headerPaths = [
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FIRApp.h",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FIRConfiguration.h",
    ]
    let paths = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(paths == [
      "/repo/FirebaseCore/Sources/Public",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore",
    ])
  }

  @Test func exportedSearchPathsWithNonStandardIncludeDir() throws {
    // nanopb uses spm_headers
    let includeDir = "/repo/nanopb/spm_headers"
    let headerPaths = [
      "/repo/nanopb/spm_headers/pb.h",
      "/repo/nanopb/spm_headers/nanopb/pb.h",
    ]
    let paths = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(paths == [
      "/repo/nanopb/spm_headers",
      "/repo/nanopb/spm_headers/nanopb",
    ])
  }

  @Test func exportedSearchPathsFlatCHeaders() throws {
    let includeDir = "/repo/flatlib/include"
    let headerPaths = [
      "/repo/flatlib/include/lib.h",
    ]
    let paths = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(paths == [
      "/repo/flatlib/include",
    ])
  }

  @Test func validateSearchPathSanitization() throws {
    #expect(try HeaderSearchPathBuilder.validateSearchPath("/repo/.build") == nil)
    #expect(try HeaderSearchPathBuilder.validateSearchPath("/repo/.build/checkouts") == nil)
    #expect(try HeaderSearchPathBuilder.validateSearchPath("   ") == nil)
    #expect(try HeaderSearchPathBuilder
      .validateSearchPath("/repo/MyModule/Sources/Public") == "/repo/MyModule/Sources/Public")
    #expect(try HeaderSearchPathBuilder
      .validateSearchPath("/repo/nanopb/spm_headers") == "/repo/nanopb/spm_headers")
  }

  @Test func buildTargetHeaderSearchPathsComposition() throws {
    let ownHeaders = [
      "/repo/FirebaseCore/Sources/FIRBundleUtil.h",
    ]
    let explicitSearchPaths = [
      "/repo", // from cSettings: [.headerSearchPath("../..")]
    ]
    let depSearchPaths = [
      "/repo/GoogleUtilities/Environment/Public",
      "/repo/GoogleUtilities/Environment/Public/GoogleUtilities",
    ]

    let paths = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
      ownHeaders: ownHeaders,
      explicitSearchPaths: explicitSearchPaths,
      dependencySearchPaths: depSearchPaths
    )

    // Base search paths
    #expect(paths.contains("$(inherited)"))
    #expect(paths.contains("$(PROJECT_DIR)/GeneratedModules"))

    // Target's own header directory
    #expect(paths.contains("/repo/FirebaseCore/Sources"))

    // Target's explicit cSettings (repo root)
    #expect(paths.contains("/repo"))

    // Dependency exported search paths
    #expect(paths.contains("/repo/GoogleUtilities/Environment/Public"))
    #expect(paths.contains("/repo/GoogleUtilities/Environment/Public/GoogleUtilities"))

    // Does NOT contain arbitrary package roots or .build
    #expect(paths.contains("/repo/.build") == false)
  }

  @Test func configMissingBundleIdPrefixThrows() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()

    // Missing bundleIdPrefix with nil config and no overrides throws .missingBundleIdPrefix
    #expect(throws: LoadConfigError.missingBundleIdPrefix) {
      try ConfigResolver.resolve(from: nil, graph: graph)
    }

    // CLI override satisfies bundleIdPrefix
    let options = BuildOptions(bundleIdPrefix: "com.example.test")
    let config = try ConfigResolver.resolve(from: nil, graph: graph, options: options)
    #expect(config.bundleIdPrefix == "com.example.test")
  }

  @Test func configProjectNameAndVersionInference() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()

    let options = BuildOptions(bundleIdPrefix: "com.google.firebase")
    let config = try ConfigResolver.resolve(from: nil, graph: graph, options: options)
    #expect(config.projectName == "Firebase")
    #expect(config.version.description.isEmpty == false)
  }

  @Test func platformEnumAndInferPlatforms() throws {
    #expect(Platform.allCases.count == 6)
    #expect(Platform.ios.rawValue == "ios")
    #expect(Platform.macos.rawValue == "macos")
    #expect(Platform.tvos.rawValue == "tvos")
    #expect(Platform.watchos.rawValue == "watchos")
    #expect(Platform.catalyst.rawValue == "catalyst")
    #expect(Platform.visionos.rawValue == "visionos")

    #expect(Platform.defaultPlatforms == [.ios, .macos, .tvos, .watchos, .catalyst])
    #expect(Platform.preferredPlatformOrder == [
      .ios,
      .macos,
      .tvos,
      .watchos,
      .catalyst,
      .visionos,
    ])

    #expect(Platform.ios.requiresSimulatorSlice)
    #expect(Platform.tvos.requiresSimulatorSlice)
    #expect(Platform.watchos.requiresSimulatorSlice)
    #expect(Platform.visionos.requiresSimulatorSlice)
    #expect(Platform.macos.requiresSimulatorSlice == false)
    #expect(Platform.catalyst.requiresSimulatorSlice == false)

    let dummyGraph = try ModulesGraph(
      rootPackages: [],
      rootDependencies: [],
      packages: [],
      dependencies: [],
      binaryArtifacts: [:]
    )
    let context = ResolutionContext(
      graph: dummyGraph,
      config: Config(version: Version(1, 0, 0), projectName: "Test", bundleIdPrefix: "com.test"),
      repoRoot: "/test",
      packageRoots: ["/test"],
      modulesMap: [:],
      aggregates: [:],
      subtargetMap: [:]
    )
    let inferred = ProductResolver.inferPlatforms(
      forTargetNames: ["NonExistentTarget"],
      context: context
    )
    #expect(inferred == [.ios, .macos, .tvos, .watchos, .catalyst])
  }

  @Test func targetDefinitionExportedHeaderSearchPaths() throws {
    let target = TargetDefinition(
      name: "FirebaseCore",
      c99name: "FirebaseCore",
      isBinary: false,
      sources: ["/repo/FirebaseCore/Sources/FIRApp.m"],
      headerSearchPaths: ["$(inherited)", "/repo/FirebaseCore/Sources/Public"],
      exportedHeaderSearchPaths: [
        "/repo/FirebaseCore/Sources/Public",
        "/repo/FirebaseCore/Sources/Public/FirebaseCore",
      ],
      publicHeadersPath: "/repo/FirebaseCore/Sources/Public"
    )

    #expect(target.exportedHeaderSearchPaths == [
      "/repo/FirebaseCore/Sources/Public",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore",
    ])

    let data = try JSONEncoder().encode(target)
    let decoded = try JSONDecoder().decode(TargetDefinition.self, from: data)
    #expect(decoded.exportedHeaderSearchPaths == target.exportedHeaderSearchPaths)
  }

  @Test func targetDefinitionAggregateCombinesExportedSearchPaths() {
    let subtarget1 = TargetDefinition(
      name: "GoogleUtilities-Environment",
      c99name: "GoogleUtilities_Environment",
      isBinary: false,
      exportedHeaderSearchPaths: ["/repo/GoogleUtilities/Environment/Public"]
    )
    let subtarget2 = TargetDefinition(
      name: "GoogleUtilities-Logger",
      c99name: "GoogleUtilities_Logger",
      isBinary: false,
      exportedHeaderSearchPaths: ["/repo/GoogleUtilities/Logger/Public"]
    )

    let aggregate = TargetDefinition.aggregate(
      name: "GoogleUtilities",
      subtargets: [subtarget1, subtarget2]
    )

    #expect(aggregate.exportedHeaderSearchPaths == [
      "/repo/GoogleUtilities/Environment/Public",
      "/repo/GoogleUtilities/Logger/Public",
    ])
  }

  @Test func targetDefinitionIsWrapperWithFilterToggle() {
    let wrapperTarget = TargetDefinition(
      name: "abslWrapper",
      c99name: "abslWrapper",
      isBinary: false,
      sources: ["/path/to/dummy.m"],
      isWrapper: true
    )

    // With filterWrapperTargets: true (default)
    #expect(wrapperTarget.isWrapper)
    #expect(wrapperTarget.isWrapper(filterWrapperTargets: true))

    // With filterWrapperTargets: false
    #expect(wrapperTarget.isWrapper(filterWrapperTargets: false) == false)

    let nonWrapperTarget = TargetDefinition(
      name: "RealTarget",
      c99name: "RealTarget",
      isBinary: false,
      sources: ["/path/to/source.m"],
      isWrapper: false
    )
    #expect(nonWrapperTarget.isWrapper == false)
    #expect(nonWrapperTarget.isWrapper(filterWrapperTargets: true) == false)
    #expect(nonWrapperTarget.isWrapper(filterWrapperTargets: false) == false)
  }

  @Test func wrapperTargetDetectionRules() {
    let config = Config(
      version: "1.0.0",
      projectName: "Test",
      bundleIdPrefix: "com.test",
      wrapperTargetNames: ["ExplicitWrapperTarget"],
      wrapperTargetPatterns: ["*Wrapper", "*Wrap"],
      wrapperSourceFolderNames: ["SwiftPM-PlatformExclude"]
    )

    // 1. Explicit name match
    #expect(TargetClassifier.isWrapperTarget(
      name: "ExplicitWrapperTarget",
      isBinary: false,
      sources: ["/path/to/something.m"],
      config: config
    ))

    // 2. Pattern match with stubs
    #expect(TargetClassifier.isWrapperTarget(
      name: "abslWrapper",
      isBinary: false,
      sources: ["/path/to/dummy.m"],
      config: config
    ))

    // Pattern match without stubs (real sources)
    #expect(TargetClassifier.isWrapperTarget(
      name: "abslWrapper",
      isBinary: false,
      sources: ["/path/to/real_implementation.m"],
      config: config
    ))

    // 3. Wrapper source folder (SwiftPM-PlatformExclude)
    #expect(TargetClassifier.isWrapperTarget(
      name: "AnyTarget",
      isBinary: false,
      sources: ["/path/to/SwiftPM-PlatformExclude/bridge.c"],
      config: config
    ))

    // 4. Empty sources
    #expect(TargetClassifier.isWrapperTarget(
      name: "EmptyTarget",
      isBinary: false,
      sources: [],
      config: config
    ))

    // 5. Binary targets are never wrappers
    #expect(TargetClassifier.isWrapperTarget(
      name: "ExplicitWrapperTarget",
      isBinary: true,
      sources: [],
      config: config
    ) == false)

    // 6. Normal target with real sources
    #expect(TargetClassifier.isWrapperTarget(
      name: "FirebaseCore",
      isBinary: false,
      sources: ["/path/to/FIRApp.m"],
      config: config
    ) == false)
  }

  @Test func wrapperTargetPatternMatching() {
    #expect("abslWrapper".matchesWildcard("*Wrapper"))
    #expect("grpcWrap".matchesWildcard("*Wrap"))
    #expect("ExactMatch".matchesWildcard("ExactMatch"))
    #expect("PrefixTarget".matchesWildcard("Prefix*"))
    #expect("abslWrapperInternal".matchesWildcard("*Wrapper") == false)
  }

  @Test func configFileSchemaWithNewOptionsDecoding() throws {
    let json = """
    {
      "publicHeaderFolderNames": ["Public", "include", "spm_headers", "Interop"],
      "filterWrapperTargets": true,
      "stripExternalBinaryCodeSignatures": true,
      "wrapperTargetNames": ["Firebase"],
      "wrapperTargetPatterns": ["*Wrapper", "*Wrap"],
      "wrapperSourceFolderNames": ["SwiftPM-PlatformExclude"],
      "companionModuleSuffixes": ["Internal", "Private", "Core"],
      "stubFileNames": ["dummy.m", "custom_stub.m"],
      "stubFilePatterns": ["*Wrapper.swift", "*Shim.swift"]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(ProductConfigFile.self, from: data)
    #expect(config.publicHeaderFolderNames == ["Public", "include", "spm_headers", "Interop"])
    #expect(config.filterWrapperTargets == true)
    #expect(config.stripExternalBinaryCodeSignatures == true)
    #expect(config.wrapperTargetNames == ["Firebase"])
    #expect(config.wrapperTargetPatterns == ["*Wrapper", "*Wrap"])
    #expect(config.wrapperSourceFolderNames == ["SwiftPM-PlatformExclude"])
    #expect(config.companionModuleSuffixes == ["Internal", "Private", "Core"])
    #expect(config.stubFileNames == ["dummy.m", "custom_stub.m"])
    #expect(config.stubFilePatterns == ["*Wrapper.swift", "*Shim.swift"])
  }

  @Test func configDefaultsPropagation() throws {
    // 1. Direct initialization with minimal arguments
    let directConfig = Config(
      version: "1.0.0",
      projectName: "Test",
      bundleIdPrefix: "com.test"
    )
    #expect(directConfig.stubFileNames == Config.Defaults.stubFileNames)
    #expect(directConfig.stubFilePatterns == Config.Defaults.stubFilePatterns)
    #expect(directConfig.wrapperTargetPatterns == Config.Defaults.wrapperTargetPatterns)
    #expect(directConfig.companionModuleSuffixes == Config.Defaults.companionModuleSuffixes)
    #expect(directConfig.publicHeaderFolderNames == Config.Defaults.publicHeaderFolderNames)
    #expect(directConfig.filterWrapperTargets == Config.Defaults.filterWrapperTargets)
    #expect(directConfig.stripExternalBinaryCodeSignatures == Config.Defaults
      .stripExternalBinaryCodeSignatures)
    #expect(directConfig.enableModuleVerifier == Config.Defaults.enableModuleVerifier)
    #expect(directConfig.targetPlatforms == Config.Defaults.targetPlatforms)

    // 2. Decoded from minimal JSON
    let minimalJSON = """
    {
      "version": "1.0.0",
      "projectName": "Test",
      "bundleIdPrefix": "com.test"
    }
    """
    let decodedConfig = try JSONDecoder().decode(
      Config.self,
      from: #require(minimalJSON.data(using: .utf8))
    )
    #expect(decodedConfig.stubFileNames == Config.Defaults.stubFileNames)
    #expect(decodedConfig.stubFilePatterns == Config.Defaults.stubFilePatterns)
    #expect(decodedConfig.wrapperTargetPatterns == Config.Defaults.wrapperTargetPatterns)
    #expect(decodedConfig.companionModuleSuffixes == Config.Defaults.companionModuleSuffixes)
    #expect(decodedConfig.publicHeaderFolderNames == Config.Defaults.publicHeaderFolderNames)
    #expect(decodedConfig.filterWrapperTargets == Config.Defaults.filterWrapperTargets)
    #expect(decodedConfig.stripExternalBinaryCodeSignatures == Config.Defaults
      .stripExternalBinaryCodeSignatures)
    #expect(decodedConfig.enableModuleVerifier == Config.Defaults.enableModuleVerifier)
    #expect(decodedConfig.targetPlatforms == Config.Defaults.targetPlatforms)

    // 3. Applying empty options preserves defaults
    let overriddenConfig = ConfigResolver.apply(options: BuildOptions(), to: directConfig)
    #expect(overriddenConfig.stubFileNames == Config.Defaults.stubFileNames)
    #expect(overriddenConfig.stubFilePatterns == Config.Defaults.stubFilePatterns)
  }

  @Test func isStubFileDefaultConfiguration() {
    let defaultConfig = Config(
      version: "1.0.0",
      projectName: "Test",
      bundleIdPrefix: "com.test"
    )

    // Verify defaults propagated into Config instance
    #expect(defaultConfig.stubFileNames == Config.Defaults.stubFileNames)
    #expect(defaultConfig.stubFilePatterns == Config.Defaults.stubFilePatterns)

    // Default stub file names
    #expect(TargetClassifier.isStubFile("/some/path/dummy.m", config: defaultConfig))
    #expect(TargetClassifier.isStubFile("/some/path/dummy.h", config: defaultConfig))
    #expect(TargetClassifier.isStubFile("/some/path/empty.m", config: defaultConfig))
    #expect(TargetClassifier.isStubFile("/some/path/empty.h", config: defaultConfig))

    // Default wildcard patterns
    #expect(TargetClassifier.isStubFile("/some/path/MyWrapper.swift", config: defaultConfig))
    #expect(TargetClassifier.isStubFile("/some/path/MyWrap.swift", config: defaultConfig))

    // Non-stub filenames that don't exist
    #expect(TargetClassifier
      .isStubFile("/some/path/RealCode.swift", config: defaultConfig) == false)
    #expect(TargetClassifier.isStubFile("/some/path/MyShim.swift", config: defaultConfig) == false)

    // 0-byte file on filesystem
    let tempFile = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".swift")
    FileManager.default.createFile(atPath: tempFile.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: tempFile) }
    #expect(TargetClassifier.isStubFile(tempFile.path, config: defaultConfig))

    // Non-empty file on filesystem
    let nonEmptyFile = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".swift")
    FileManager.default.createFile(
      atPath: nonEmptyFile.path,
      contents: Data("import Foundation".utf8)
    )
    defer { try? FileManager.default.removeItem(at: nonEmptyFile) }
    #expect(TargetClassifier.isStubFile(nonEmptyFile.path, config: defaultConfig) == false)
  }

  @Test func isStubFileCustomConfiguration() {
    let customConfig = Config(
      version: "1.0.0",
      projectName: "Test",
      bundleIdPrefix: "com.test",
      stubFileNames: ["custom_empty.c"],
      stubFilePatterns: ["*Shim.swift"]
    )

    // Configured custom names and patterns
    #expect(TargetClassifier.isStubFile("/path/custom_empty.c", config: customConfig))
    #expect(TargetClassifier.isStubFile("/path/ModuleShim.swift", config: customConfig))

    // Default names/patterns are replaced by custom configuration
    #expect(TargetClassifier.isStubFile("/path/dummy.m", config: customConfig) == false)
    #expect(TargetClassifier.isStubFile("/path/MyWrapper.swift", config: customConfig) == false)
  }

  @Test func wrapperTargetDetectionWithCustomStubConfig() {
    let customConfig = Config(
      version: "1.0.0",
      projectName: "Test",
      bundleIdPrefix: "com.test",
      wrapperTargetPatterns: ["*Wrapper"],
      stubFilePatterns: ["*Shim.swift"]
    )

    // Target matching wrapperTargetPatterns and source matching stubFilePatterns -> is wrapper
    #expect(TargetClassifier.isWrapperTarget(
      name: "FeatureWrapper",
      isBinary: false,
      sources: ["/path/FeatureShim.swift"],
      config: customConfig
    ))

    // Target whose name does not match wrapperTargetPatterns and source has default wrapper pattern
    // which is no
    // longer in custom config -> not a wrapper
    #expect(TargetClassifier.isWrapperTarget(
      name: "FeatureModule",
      isBinary: false,
      sources: ["/path/FeatureWrapper.swift"],
      config: customConfig
    ) == false)
  }

  @Test func platformModelAndProperties() {
    #expect(Platform.ios.canonicalName == "iOS")
    #expect(Platform.macos.canonicalName == "macOS")
    #expect(Platform.catalyst.canonicalName == "macCatalyst")
    #expect(Platform.visionos.canonicalName == "visionOS")

    #expect(Platform.ios.deploymentTargetSettingKey == "IPHONEOS_DEPLOYMENT_TARGET")
    #expect(Platform.macos.deploymentTargetSettingKey == "MACOSX_DEPLOYMENT_TARGET")
    #expect(Platform.catalyst.deploymentTargetSettingKey == nil)

    #expect(Platform.macos.isVersionedBundle)
    #expect(Platform.catalyst.isVersionedBundle)
    #expect(Platform.ios.isVersionedBundle == false)

    #expect(Platform.macos.minVersionPlistKey == "LSMinimumSystemVersion")
    #expect(Platform.ios.minVersionPlistKey == "MinimumOSVersion")

    let custom = Platform.from(platformName: "driverKit")
    #expect(custom == .custom("driverKit"))
    #expect(custom.canonicalName == "driverKit")
    #expect(custom.rawValue == "driverkit")

    #expect(Platform(rawValue: "ios") == .ios)
    #expect(Platform(rawValue: "unknownOS") == .custom("unknownOS"))

    // Destination properties and simulator requirement
    #expect(Platform.ios.requiresSimulatorSlice)
    #expect(Platform.tvos.requiresSimulatorSlice)
    #expect(Platform.watchos.requiresSimulatorSlice)
    #expect(Platform.visionos.requiresSimulatorSlice)
    #expect(Platform.macos.requiresSimulatorSlice == false)
    #expect(Platform.catalyst.requiresSimulatorSlice == false)

    #expect(Platform.ios.destinations == [.iOS, .iOSSimulator])
    #expect(Platform.Destination.iOS.platform == .ios)
    #expect(Platform.Destination.iOS.isSimulator == false)
    #expect(Platform.Destination.iOSSimulator.isSimulator)
    #expect(Platform.Destination.macCatalyst.platform == .catalyst)
    #expect(Platform.Destination.allPlatforms.count == 10)

    // Typealias compatibility
    let aliasDestination: Platform.Destination = .macOS
    #expect(aliasDestination.platform == .macos)
  }

  @Test func deploymentTargetsBehavior() throws {
    let targets: DeploymentTargets = [
      "iOS": "16.0",
      "macOS": "13.0",
      "tvOS": "16.0",
      "watchOS": "9.0",
      "visionOS": "1.0",
    ]

    // Platform subscripting
    #expect(targets[.ios]?.version.versionString == "16.0")
    #expect(targets[.macos]?.version.versionString == "13.0")

    // Catalyst fallback to iOS when not explicitly provided
    #expect(targets[.catalyst] == nil)
    #expect(targets.version(for: .catalyst).versionString == "16.0")

    // Xcode build settings dictionary
    let settings = targets.xcodeBuildSettings
    #expect(settings["IPHONEOS_DEPLOYMENT_TARGET"] == "16.0")
    #expect(settings["MACOSX_DEPLOYMENT_TARGET"] == "13.0")
    #expect(settings["TVOS_DEPLOYMENT_TARGET"] == "16.0")
    #expect(settings["WATCHOS_DEPLOYMENT_TARGET"] == "9.0")
    #expect(settings["XROS_DEPLOYMENT_TARGET"] == "1.0")

    // JSON round-trip
    let encoder = JSONEncoder()
    let data = try encoder.encode(targets)
    let decoded = try JSONDecoder().decode(DeploymentTargets.self, from: data)
    #expect(decoded[.ios]?.version.versionString == "16.0")
    #expect(decoded[.macos]?.version.versionString == "13.0")
  }

  @Test func configLoadAndOverridesPrecedence() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()

    let options = BuildOptions(
      versionString: "99.1.2",
      projectName: "OverriddenProject",
      bundleIdPrefix: "com.custom.override",
      targetPlatforms: [.ios, .catalyst],
      filterWrapperTargets: false,
      stripExternalBinaryCodeSignatures: true,
      enableModuleVerifier: true,
      buildSettings: ["CUSTOM_FLAG": "1"]
    )

    let config = try ConfigResolver.resolve(from: nil, graph: graph, options: options)
    #expect(config.version == "99.1.2")
    #expect(config.projectName == "OverriddenProject")
    #expect(config.bundleIdPrefix == "com.custom.override")
    #expect(config.filterWrapperTargets == false)
    #expect(config.stripExternalBinaryCodeSignatures)
    #expect(config.enableModuleVerifier)
    #expect(config.buildSettings["CUSTOM_FLAG"] == "1")
    #expect(config.targetPlatforms == [.ios, .catalyst])
    #expect(config.deploymentTargets[.ios] != nil)
  }

  @Test func configCodableRoundtrip() throws {
    let originalConfig = Config(
      version: "12.3.4",
      projectName: "MyCustomSDK",
      bundleIdPrefix: "com.custom.sdk",
      deploymentTargets: DeploymentTargets(dictionary: ["iOS": "16.0", "macOS": "13.0"]),
      versionMacroName: "SDK_VERSION",
      skippedProductFolders: ["Wrapper"],
      baseProduct: BaseProduct(product: "Core", frameworks: ["SubCore"]),
      extraFiles: [ExtraFiles(destination: "Core", files: ["NOTICE"])],
      excludedProducts: ["OldProduct"],
      extraProducts: [Config.ProductEntry(name: "Extra", targets: ["ExtraTarget"])],
      products: [Config.ProductEntry(name: "Main", targets: ["MainTarget"])],
      renamedProducts: ["Old": "New"],
      externalArtifacts: [ExternalArtifact(productName: "Ext", url: "https://example.com/ext.zip")],
      publicHeaderFolderNames: ["Public", "Headers"],
      filterWrapperTargets: false,
      stripExternalBinaryCodeSignatures: true,
      suppressedInternalFrameworks: ["InternalFwk"],
      productPlatformOverrides: ["Main": [.ios, .catalyst]],
      extraFrameworksPerProduct: ["Main": ["ExtraFwk"]],
      targetArchitectures: ["ios": ["arm64"]],
      enableModuleVerifier: true,
      buildSettings: ["MY_SETTING": "YES"],
      targetPlatforms: [.ios, .macos],
      baseHeaderSearchPaths: ["$(inherited)", "/custom/headers"]
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(originalConfig)
    let decodedConfig = try JSONDecoder().decode(Config.self, from: data)

    #expect(decodedConfig == originalConfig)
  }

  @Test func buildPlanConfigCompositionAndLegacyDecoding() throws {
    let config = Config(
      version: "1.0.0",
      projectName: "TestProj",
      bundleIdPrefix: "com.test",
      targetPlatforms: [.ios]
    )
    let product = ProductPlan(name: "TestProduct", targets: [])
    let plan = BuildPlan(config: config, products: [product])

    // Verify config properties work seamlessly
    #expect(plan.config.version == "1.0.0")
    #expect(plan.config.projectName == "TestProj")
    #expect(plan.config.bundleIdPrefix == "com.test")
    #expect(plan.config.targetPlatforms == [.ios])
    #expect(plan.config == config)

    // Encode to JSON and verify "config" is a nested object
    let encoder = JSONEncoder()
    let data = try encoder.encode(plan)
    let jsonDict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(jsonDict["config"] != nil)
    #expect(jsonDict["products"] != nil)

    // Roundtrip decode
    let decoded = try JSONDecoder().decode(BuildPlan.self, from: data)
    #expect(decoded == plan)
    #expect(decoded.config.version == "1.0.0")
  }

  @Test func targetDefinitionAggregate() {
    let subtarget1 = TargetDefinition(
      name: "SubmoduleA",
      c99name: "SubmoduleA",
      isBinary: false,
      sources: ["/path/Sources/A.m", "/path/Sources/Shared.h"],
      dependencies: ["SubmoduleB", "ExternalDep1"],
      recursiveDependencies: ["SubmoduleB", "ExternalDep1", "ExternalDep2"],
      resources: [ResourceDefinition(name: "resA", path: "/path/resA.bundle", rule: "process")],
      cSettings: ["-DFLAG_A"],
      linkerSettings: ["framework:UIKit"]
    )

    let subtarget2 = TargetDefinition(
      name: "SubmoduleB",
      c99name: "SubmoduleB",
      isBinary: false,
      sources: ["/path/Sources/B.m", "/path/Sources/Shared.h"],
      dependencies: ["SubmoduleA", "ExternalDep3"],
      recursiveDependencies: ["SubmoduleA", "ExternalDep3"],
      resources: [ResourceDefinition(name: "resB", path: "/path/resB.bundle", rule: "copy")],
      cSettings: ["-DFLAG_A", "-DFLAG_B"],
      linkerSettings: ["library:z", "framework:UIKit"]
    )

    let aggregate = TargetDefinition.aggregate(
      name: "UnifiedAggregate",
      subtargets: [subtarget1, subtarget2],
      headerSearchPaths: ["/include/SearchPath"],
      publicHeadersPath: "Public"
    )

    #expect(aggregate.name == "UnifiedAggregate")
    #expect(aggregate.c99name == "UnifiedAggregate")
    #expect(aggregate.isBinary == false)

    // Sources should be combined and de-duplicated
    #expect(aggregate.sources == [
      "/path/Sources/A.m",
      "/path/Sources/Shared.h",
      "/path/Sources/B.m",
    ])

    // Resources should be combined
    #expect(aggregate.resources.count == 2)
    #expect(aggregate.resources.map(\.name) == ["resA", "resB"])

    // Compiler flags should be combined and de-duplicated
    #expect(aggregate.cSettings == ["-DFLAG_A", "-DFLAG_B"])

    // Linker flags should be combined and sorted
    #expect(aggregate.linkerSettings == ["framework:UIKit", "library:z"])

    // Internal subtarget references should be filtered out
    #expect(aggregate.dependencies.contains("SubmoduleA") == false)
    #expect(aggregate.dependencies.contains("SubmoduleB") == false)
    #expect(aggregate.dependencies == ["ExternalDep1", "ExternalDep3"])

    #expect(aggregate.recursiveDependencies.contains("SubmoduleA") == false)
    #expect(aggregate.recursiveDependencies.contains("SubmoduleB") == false)
    #expect(aggregate.recursiveDependencies == ["ExternalDep1", "ExternalDep2", "ExternalDep3"])

    #expect(aggregate.headerSearchPaths == ["/include/SearchPath"])
    #expect(aggregate.publicHeadersPath == "Public")
    #expect(aggregate.isWrapper == false)
  }

  @Test func buildPlanResolverAggregatesResolution() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent() // ManifestReaderTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // zip_builder
      .deletingLastPathComponent() // scripts
      .deletingLastPathComponent() // repo root
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()
    let configFile = repoRoot
      .appendingPathComponent("zip_builder.json")
    let config = try ConfigResolver.resolve(from: configFile, graph: graph)

    let (aggregates, subtargetMap, submodules) = try BuildPlanResolver.resolveAggregates(
      from: graph,
      config: config
    )

    // 1. GoogleUtilities must be detected and aggregated
    guard let googleUtilities = aggregates["GoogleUtilities"] else {
      Issue.record("GoogleUtilities aggregate target not resolved")
      return
    }

    // 2. Sources and headers from all submodules should be combined
    #expect(googleUtilities.sources.isEmpty == false)
    #expect(googleUtilities.sources.contains(where: { $0.contains("Environment") }))
    #expect(googleUtilities.sources.contains(where: { $0.contains("GULLogger") }))

    // 3. Intra-package dependencies must NOT appear in external dependencies
    let internalSubmoduleNames = Set(submodules.map(\.name))
    for dep in googleUtilities.dependencies {
      #expect(
        internalSubmoduleNames.contains(dep) == false,
        "Aggregate target should not depend on its own internal submodule: \(dep)"
      )
    }

    // 4. Products, module names, and C99 names must map to the aggregate package name
    #expect(subtargetMap["GULEnvironment"] == "GoogleUtilities")
    #expect(subtargetMap["GULLogger"] == "GoogleUtilities")
    #expect(subtargetMap["GoogleUtilities-Environment"] == "GoogleUtilities")
    #expect(subtargetMap["GoogleUtilities_Environment"] == "GoogleUtilities")

    // 5. Submodules collection must only contain submodules of aggregated packages (no graph
    // pollution)
    #expect(submodules.isEmpty == false)
    #expect(submodules.contains(where: { $0.name == "GoogleUtilities-Environment" }))
    #expect(submodules.contains(where: { $0.name == "GoogleUtilities-Logger" }))
    #expect(
      submodules
        .contains(where: { $0.name == "FirebaseCore" || $0.name == "FirebaseAuth" }) == false,
      "Submodules must not pollute with non-aggregate reachable modules"
    )
  }

  @Test func buildPlanResolverShouldAggregateDetection() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent() // ManifestReaderTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // zip_builder
      .deletingLastPathComponent() // scripts
      .deletingLastPathComponent() // repo root
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()
    let configFile = repoRoot
      .appendingPathComponent("zip_builder.json")
    let baseConfig = try ConfigResolver.resolve(from: configFile, graph: graph)

    let rootPackageIdentities = Set(graph.rootPackages.map(\.identity))

    // 1. Root package must NEVER be aggregated
    if let rootPkg = graph.rootPackages.first {
      #expect(BuildPlanResolver.shouldAggregate(
        rootPkg,
        rootPackageIdentities: rootPackageIdentities,
        config: baseConfig
      ) == false, "Root package should never be aggregated")
    }

    // 2. GoogleUtilities should be detected for aggregation
    if let guPackage = graph.packages
      .first(where: { $0.manifest.displayName == "GoogleUtilities" }) {
      #expect(BuildPlanResolver.shouldAggregate(
        guPackage,
        rootPackageIdentities: rootPackageIdentities,
        config: baseConfig
      ), "GoogleUtilities should be detected as an aggregate package")

      // 3. When explicit aggregatePackageNames is configured, unlisted packages are excluded
      let restrictiveConfig = Config(
        version: baseConfig.version,
        projectName: baseConfig.projectName,
        bundleIdPrefix: baseConfig.bundleIdPrefix,
        aggregatePackageNames: ["SomeOtherPackage"]
      )
      #expect(BuildPlanResolver.shouldAggregate(
        guPackage,
        rootPackageIdentities: rootPackageIdentities,
        config: restrictiveConfig
      ) == false,
      "Unlisted package should be excluded when aggregatePackageNames is explicitly configured")

      // 4. When explicitly listed in aggregatePackageNames, package is aggregated
      let explicitConfig = Config(
        version: baseConfig.version,
        projectName: baseConfig.projectName,
        bundleIdPrefix: baseConfig.bundleIdPrefix,
        aggregatePackageNames: ["GoogleUtilities"]
      )
      #expect(BuildPlanResolver.shouldAggregate(
        guPackage,
        rootPackageIdentities: rootPackageIdentities,
        config: explicitConfig
      ), "Package explicitly listed in aggregatePackageNames should be aggregated")
    }

    // 5. Single-module package (nanopb) should NOT be aggregated by default
    if let nanopbPackage = graph.packages.first(where: { $0.manifest.displayName == "nanopb" }) {
      #expect(BuildPlanResolver.shouldAggregate(
        nanopbPackage,
        rootPackageIdentities: rootPackageIdentities,
        config: baseConfig
      ) == false, "Single-module package should not be aggregated")
    }
  }

  @Test func extractVersionFromManifestContent() throws {
    // 1. Firebase standard declaration
    let firebaseContent = """
    // Package.swift
    import PackageDescription

    let firebaseVersion = "12.19.0"

    let package = Package(
      name: "Firebase"
    )
    """
    #expect(try VersionResolver.extractVersion(
      fromManifestContent: firebaseContent,
      projectName: "Firebase"
    ) == Version(12, 19, 0))

    // 2. Generic version declaration
    let genericContent = """
    let version = "2.4.1"
    """
    #expect(try VersionResolver.extractVersion(
      fromManifestContent: genericContent,
      projectName: "MyLibrary"
    ) == Version(2, 4, 1))

    // 3. Project-specific version declaration
    let projectVersionContent = """
    let anyProjectVersion = "3.0.0-beta.2"
    """
    #expect(try VersionResolver.extractVersion(
      fromManifestContent: projectVersionContent,
      projectName: "AnyProject"
    ) == Version(3, 0, 0, prereleaseIdentifiers: ["beta", "2"]))

    // 4. Comments should be ignored
    let commentedContent = """
    // let firebaseVersion = "10.0.0"
    /* let firebaseVersion = "9.0.0" */
    let firebaseVersion = "12.19.0"
    """
    #expect(try VersionResolver.extractVersion(
      fromManifestContent: commentedContent,
      projectName: "Firebase"
    ) == Version(12, 19, 0))

    // 5. Unrelated version-like variables should NOT be matched
    let unrelatedContent = """
    let swiftToolsVersion = "5.9"
    let minimumMacOSVersion = "10.15"
    let libraryDescription = "A great library"
    """
    #expect(try VersionResolver.extractVersion(
      fromManifestContent: unrelatedContent,
      projectName: "MyLibrary"
    ) == nil)
  }

  @Test func versionResolutionPrecedence() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent() // ManifestReaderTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // zip_builder
      .deletingLastPathComponent() // scripts
      .deletingLastPathComponent() // repo root
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()

    // 1. Explicit CLI argument wins over config and Package.swift
    let fileSchemaWithVersion = ProductConfigFile(
      version: Version(2, 0, 0)
    )
    let v1 = try VersionResolver.resolveVersion(
      config: fileSchemaWithVersion,
      graph: graph,
      projectName: "Firebase",
      version: Version(9, 9, 9)
    )
    #expect(v1 == Version(9, 9, 9))

    // 2. Config file version wins over Package.swift
    let v2 = try VersionResolver.resolveVersion(
      config: fileSchemaWithVersion,
      graph: graph,
      projectName: "Firebase",
      version: nil
    )
    #expect(v2 == Version(2, 0, 0))

    // 3. Fallback: Parse Package.swift text
    let fileSchemaWithoutVersion = ProductConfigFile(
      version: nil
    )
    let packageInferred = try #require(try VersionResolver.inferVersionFromPackage(
      path: repoRoot.path,
      projectName: "Firebase"
    ))
    #expect(packageInferred >= Version(12, 0, 0))

    let v3 = try VersionResolver.resolveVersion(
      config: fileSchemaWithoutVersion,
      graph: graph,
      projectName: "Firebase",
      version: nil
    )
    #expect(v3 == packageInferred)
  }

  @Test func stringIsHeaderFile() {
    #expect("Foo.h".isHeaderFile)
    #expect("Bar.hpp".isHeaderFile)
    #expect("/path/to/Header.h".isHeaderFile)
    #expect("Foo.m".isHeaderFile == false)
    #expect("Foo.swift".isHeaderFile == false)
    #expect("Foo.c".isHeaderFile == false)
    #expect("Foo.cpp".isHeaderFile == false)
  }

  @Test func isCompanionModule() {
    // Exact match is not companion
    #expect(TargetClassifier.isCompanionModule("FirebaseAuth", of: "FirebaseAuth") == false)

    // Suffixes
    #expect(TargetClassifier.isCompanionModule(
      "FirebaseAuthInternal",
      of: "FirebaseAuth"
    ))
    #expect(TargetClassifier.isCompanionModule(
      "FirebaseSessionsObjC",
      of: "FirebaseSessions"
    ))
    #expect(TargetClassifier.isCompanionModule("MyModuleSwift", of: "MyModule"))
    #expect(TargetClassifier.isCompanionModule("FirebaseAuth_iOS", of: "FirebaseAuth"))

    // Prefixes
    #expect(TargetClassifier.isCompanionModule(
      "GoogleUtilities_Environment",
      of: "GoogleUtilities"
    ))
    #expect(TargetClassifier.isCompanionModule("MyPackage-Sub", of: "MyPackage"))

    // Suppressed internal frameworks config
    #expect(TargetClassifier.isCompanionModule(
      "CustomInternalDep",
      of: "Custom",
      suppressedInternalFrameworks: ["CustomInternalDep"]
    ))
    #expect(TargetClassifier.isCompanionModule(
      "UnrelatedInternalDep",
      of: "Custom",
      suppressedInternalFrameworks: ["UnrelatedInternalDep"]
    ) == false)

    // Unrelated modules
    #expect(TargetClassifier.isCompanionModule(
      "FirebaseFirestore",
      of: "FirebaseAuth"
    ) == false)

    // Custom companion suffixes configuration
    #expect(TargetClassifier.isCompanionModule(
      "MyLibPrivate",
      of: "MyLib",
      companionSuffixes: ["Private", "Impl"]
    ))
    #expect(TargetClassifier.isCompanionModule(
      "MyLibImpl",
      of: "MyLib",
      companionSuffixes: ["Private", "Impl"]
    ))
    #expect(TargetClassifier.isCompanionModule(
      "MyLibInternal",
      of: "MyLib",
      companionSuffixes: ["Private", "Impl"]
    ) == false)
  }

  @Test func targetDefinitionUpdatingHeaderSearchPaths() {
    let target = TargetDefinition(
      name: "MyTarget",
      c99name: "MyTarget",
      isBinary: false,
      sources: ["/path/to/source.m"],
      headerSearchPaths: ["/old/path"]
    )
    let updated = target.updatingHeaderSearchPaths(["/new/path/1", "/new/path/2"])
    #expect(updated.name == target.name)
    #expect(updated.c99name == target.c99name)
    #expect(updated.sources == target.sources)
    #expect(updated.headerSearchPaths == ["/new/path/1", "/new/path/2"])
  }

  @Test func wrapperSourceRootDetection() {
    let config = Config(
      version: Version(1, 0, 0),
      projectName: "Test",
      bundleIdPrefix: "com.test",
      wrapperSourceFolderNames: ["SwiftPM-PlatformExclude", "CustomWrapper"]
    )
    #expect(TargetClassifier.isWrapperSourceRoot(
      path: "/path/to/SwiftPM-PlatformExclude/Sources",
      config: config
    ))
    #expect(TargetClassifier.isWrapperSourceRoot(
      path: "/Sources/CustomWrapper",
      config: config
    ))
    #expect(TargetClassifier.isWrapperSourceRoot(
      path: "/path/to/NormalTarget/Sources",
      config: config
    ) == false)
  }

  @Test func resourceDefinitionHashableAndDeduplication() {
    let res1 = ResourceDefinition(
      name: "PrivacyInfo.xcprivacy",
      path: "/path/to/PrivacyInfo.xcprivacy",
      rule: "process"
    )
    let res2 = ResourceDefinition(
      name: "PrivacyInfo.xcprivacy",
      path: "/path/to/PrivacyInfo.xcprivacy",
      rule: "process"
    )
    let res3 = ResourceDefinition(name: "Logo.png", path: "/path/to/Logo.png", rule: "copy")

    #expect(res1 == res2)
    #expect(res1.hashValue == res2.hashValue)

    let set: Set<ResourceDefinition> = [res1, res2, res3]
    #expect(set.count == 2)
  }

  @Test func targetDefinitionFactoryWithResolvedModule() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()

    guard let coreModule = graph.reachableModules.first(where: { $0.name == "FirebaseCore" }) else {
      Issue.record("FirebaseCore module not found in graph")
      return
    }

    let config = Config(
      version: Version(1, 0, 0),
      projectName: "Firebase",
      bundleIdPrefix: "com.google.firebase"
    )

    // Unified makeTargetDefinition with default dependency inference
    let targetDef = try TargetDefinitionFactory.makeTargetDefinition(
      module: coreModule,
      config: config
    )
    #expect(targetDef.name == "FirebaseCore")
    #expect(targetDef.c99name == "FirebaseCore")
    #expect(targetDef.isBinary == false)
    #expect(targetDef.isWrapper == false)
    #expect(targetDef.sources.isEmpty == false)
    #expect(targetDef.dependencies.isEmpty == false)
  }

  @Test func buildPlanResolverWithOverrides() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()
    let configFile = repoRoot
      .appendingPathComponent("zip_builder.json")
    let config = try ConfigResolver.resolve(from: configFile, graph: graph)

    let options = BuildOptions(
      version: Version(99, 0, 0),
      projectName: "OverriddenProject",
      targetPlatforms: [.ios]
    )
    let plan = try BuildPlanResolver.resolveBuildPlan(
      from: graph,
      config: config,
      options: options
    )
    #expect(plan.config.version == Version(99, 0, 0))
    #expect(plan.config.projectName == "OverriddenProject")
    #expect(plan.config.targetPlatforms == [.ios])
    for product in plan.products {
      #expect(product.platforms.allSatisfy { $0 == .ios })
    }
  }

  @Test func buildPlanResolverPlatformFilteringExcludesUnsupportedProducts() async throws {
    let repoRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let loader = PackageGraphLoader(packagePath: repoRoot)
    let graph = try await loader.loadGraph()
    let configFile = repoRoot
      .appendingPathComponent("zip_builder.json")
    let baseConfig = try ConfigResolver.resolve(from: configFile, graph: graph)

    let options = BuildOptions(
      targetPlatforms: [Common.Platform.macos]
    )
    let plan = try BuildPlanResolver.resolveBuildPlan(
      from: graph,
      config: baseConfig,
      options: options
    )
    #expect(plan.config.targetPlatforms == [Common.Platform.macos])
    #expect(plan.products.isEmpty == false)
    for product in plan.products {
      #expect(product.platforms.allSatisfy { $0 == Common.Platform.macos })
    }
    // RecaptchaInterop and FirebaseInAppMessaging are configured as iOS/Catalyst only and must be
    // excluded
    #expect(plan.products.contains(where: { $0.name == "RecaptchaInterop" }) == false)
    #expect(plan.products.contains(where: { $0.name == "FirebaseInAppMessaging" }) == false)
    // FirebaseDatabase supports macOS and must be included
    #expect(plan.products.contains(where: { $0.name == "FirebaseDatabase" }))
  }

  @Test func resolutionContextPlatformsAndExtraFrameworks() throws {
    let dummyGraph = try ModulesGraph(
      rootPackages: [],
      rootDependencies: [],
      packages: [],
      dependencies: [],
      binaryArtifacts: [:]
    )
    let config = Config(
      version: Version(1, 0, 0),
      projectName: "Test",
      bundleIdPrefix: "com.test",
      productPlatformOverrides: ["CustomProd": [.macos]],
      extraFrameworksPerProduct: ["CustomProd": ["Security"]]
    )
    let context = ResolutionContext(
      graph: dummyGraph,
      config: config,
      repoRoot: "/test",
      packageRoots: ["/test"],
      modulesMap: [:],
      aggregates: [:],
      subtargetMap: [:]
    )

    let entryWithOverride = Config.ProductEntry(
      name: "CustomProd",
      targets: ["TargetA"],
      extraFrameworks: ["UIKit"],
      platforms: [Common.Platform.ios]
    )
    #expect(context.platforms(for: entryWithOverride) == [Common.Platform.macos])
    #expect(context.platforms(for: entryWithOverride, filter: [Common.Platform.ios]) == [])
    #expect(context
      .platforms(for: entryWithOverride, filter: [Common.Platform.macos]) ==
      [Common.Platform.macos])
    #expect(context.extraFrameworks(for: entryWithOverride) == ["Security", "UIKit"])
  }

  @Test func resolutionContextCompanionAndWrapperDetectionDefaults() throws {
    let dummyGraph = try ModulesGraph(
      rootPackages: [],
      rootDependencies: [],
      packages: [],
      dependencies: [],
      binaryArtifacts: [:]
    )
    let config = Config(
      version: Version(1, 0, 0),
      projectName: "Test",
      bundleIdPrefix: "com.test"
    )
    let context = ResolutionContext(
      graph: dummyGraph,
      config: config,
      repoRoot: "/test",
      packageRoots: ["/test"],
      modulesMap: [:],
      aggregates: [:],
      subtargetMap: [:]
    )

    // Test default companion suffixes: Internal, ObjC, Swift, _iOS
    #expect(context.isInternalCompanion(named: "FirebaseCoreInternal"))
    #expect(context.isInternalCompanion(named: "FirebaseCoreObjC"))
    #expect(context.isInternalCompanion(named: "FirebaseCoreSwift"))
    #expect(context.isInternalCompanion(named: "GoogleUtilities_iOS"))
    #expect(context.isInternalCompanion(named: "FirebaseCore") == false)
    #expect(context.isInternalCompanion(named: "FirebaseSessions") == false)

    // Test default wrapper target patterns: *Wrapper, *Wrap
  }

  @Test func resolutionContextCustomCompanionAndWrapperPatterns() throws {
    let dummyGraph = try ModulesGraph(
      rootPackages: [],
      rootDependencies: [],
      packages: [],
      dependencies: [],
      binaryArtifacts: [:]
    )
    let config = Config(
      version: Version(1, 0, 0),
      projectName: "Test",
      bundleIdPrefix: "com.test",
      wrapperTargetNames: ["ExplicitWrapperTarget"],
      wrapperTargetPatterns: ["*CustomWrap", "Synthetic*"],
      companionModuleSuffixes: ["Companion", "Support"]
    )
    let context = ResolutionContext(
      graph: dummyGraph,
      config: config,
      repoRoot: "/test",
      packageRoots: ["/test"],
      modulesMap: [:],
      aggregates: [:],
      subtargetMap: [:]
    )

    // Custom companion module suffixes: Companion, Support
    #expect(context.isInternalCompanion(named: "MyModuleCompanion"))
    #expect(context.isInternalCompanion(named: "MyModuleSupport"))
    #expect(context
      .isInternalCompanion(named: "MyModuleInternal") ==
      false) // Default Internal not in custom list

    // shouldExposeInternalHeaders
    #expect(context.shouldExposeInternalHeaders(
      forDependency: "MyModuleCompanion",
      module: nil
    ))
    #expect(context.shouldExposeInternalHeaders(forDependency: "AnyCustomWrap", module: nil))
    #expect(context.shouldExposeInternalHeaders(
      forDependency: "SyntheticModule",
      module: nil
    ))
    #expect(context.shouldExposeInternalHeaders(
      forDependency: "StandardInternal",
      module: nil
    ) == false)
    #expect(context.shouldExposeInternalHeaders(
      forDependency: "UnrelatedProduct",
      module: nil
    ) == false)
  }

  @Test func resolveProductThrowsForMissingDeclaredRootTarget() throws {
    let dummyGraph = try ModulesGraph(
      rootPackages: [],
      rootDependencies: [],
      packages: [],
      dependencies: [],
      binaryArtifacts: [:]
    )
    let context = ResolutionContext(
      graph: dummyGraph,
      config: Config(version: Version(1, 0, 0), projectName: "Test", bundleIdPrefix: "com.test"),
      repoRoot: "/test",
      packageRoots: ["/test"],
      modulesMap: [:],
      aggregates: [:],
      subtargetMap: [:]
    )
    let entry = Config.ProductEntry(name: "MissingTargetProd", targets: ["DeclaredMissingTarget"])

    #expect(throws: PlanningError.targetNotFound("DeclaredMissingTarget")) {
      try ProductResolver.resolveProduct(
        platforms: [.ios],
        entry: entry,
        context: context
      )
    }
  }
}
