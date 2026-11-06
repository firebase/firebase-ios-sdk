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

import Foundation
@preconcurrency import PackageGraph
import Testing
@testable import ZipBuilder

/// Fixtures/MiniPackage, loaded once with a scratch directory outside the fixture.
enum MiniPackage {
  static let path = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // Planning
    .deletingLastPathComponent() // ZipBuilderTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // zip_builder
    .appendingPathComponent("Fixtures/MiniPackage").path

  static let graph = Task {
    let scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/MiniPackage").path
    return try await loadPackage(at: path, scratchPath: scratch)
  }

  /// A config for the fixture; `sections` are extra top-level keys, e.g. `"products": {…}`.
  static func config(_ sections: String = "") throws -> Config {
    let release = #""release": { "name": "Mini", "bundleIdPrefix": "com.example", "#
      + #""dependencyBundleIdPrefix": "org.example" }"#
    let json = "{ \(release)\(sections.isEmpty ? "" : ", \(sections)") }"
    return try JSONDecoder().decode(Config.self, from: Data(json.utf8))
  }

  static func plan(_ sections: String = "", product: String? = nil) async throws -> Plan {
    try await makePlan(graph.value, config(sections), version: "1.2.3", product: product)
  }

  /// The plan after `customize`.
  static func customizedPlan(_ sections: String, product: String? = nil) async throws -> Plan {
    let config = try config(sections)
    return try await customize(makePlan(graph.value, config, version: "1.2.3", product: product),
                               config, packageRoot: path, version: "1.2.3")
  }

  static func module(_ name: String) async throws -> ResolvedModule {
    try #require(await graph.value.module(for: name))
  }
}

extension Plan {
  func framework(_ name: String) throws -> Framework {
    try #require(frameworks.first { $0.name == name })
  }
}

struct MakePlanTests {
  @Test func shipsEveryLibraryProduct() async throws {
    let plan = try await MiniPackage.plan()
    #expect(plan.folders.map(\.name) == ["Mini", "MiniCore", "MiniHeaders", "MiniPrebuilt"])
    #expect(plan.folders.map(\.frameworks) == [
      ["CoreC", "CoreCInternal", "Mini-Extras", "SwiftLib"], ["CoreC"], ["HeaderOnly"],
      ["Prebuilt"],
    ])
    #expect(plan.folders.allSatisfy { $0.files.isEmpty })
  }

  @Test func frameworksAreInDependencyOrder() async throws {
    let plan = try await MiniPackage.plan()
    // Wrapper is a wrapper and SwiftLibTests is test-only, so neither is a framework.
    #expect(plan.frameworks.map(\.name) ==
      ["CoreC", "CoreCInternal", "HeaderOnly", "Mini-Extras", "SwiftLib"])
  }

  @Test func excludeAddAndOnly() async throws {
    let plan = try await MiniPackage.plan("""
    "products": { "exclude": ["Mini", "MiniPrebuilt"],
                  "add": [{ "name": "Extras", "targets": ["Mini-Extras"] }] }
    """)
    #expect(plan.folders.map(\.name) == ["Extras", "MiniCore", "MiniHeaders"])
    #expect(plan.frameworks.map(\.name) == ["CoreC", "HeaderOnly", "Mini-Extras"])
    #expect(plan.binaries.isEmpty)

    let mini = try await MiniPackage.plan(product: "Mini")
    #expect(mini.folders.map(\.name) == ["Mini"])
    #expect(mini.frameworks.map(\.name) == ["CoreC", "CoreCInternal", "Mini-Extras", "SwiftLib"])
    await #expect(throws: ZipBuilderError.self) { try await MiniPackage.plan(product: "Nope") }
  }

  @Test func wrappers() async throws {
    // Wrapper's only resource is a privacy manifest, so it's still a wrapper.
    #expect(try await isWrapper(MiniPackage.module("Wrapper")))
    // HeaderOnly's dummy.m is code-free, but its public header declares a protocol.
    #expect(try await !isWrapper(MiniPackage.module("HeaderOnly")))
    #expect(try await !isWrapper(MiniPackage.module("CoreC")))
    #expect(try await !isWrapper(MiniPackage.module("SwiftLib")))
    // Code-free, but ships a real resource.
    #expect(try await !isWrapper(MiniPackage.module("ResourceOnly")))
  }

  @Test func unsupportedFeaturesFail() async throws {
    #expect(try await unsupportedFeature(of: MiniPackage.module("CSystem")) ==
      "system library targets aren't supported")
    #expect(try await unsupportedFeature(of: MiniPackage.module("SwiftLib")) == nil)
    #expect(try await unsupportedFeature(of: MiniPackage.module("Prebuilt")) == nil)
    await #expect(throws: ZipBuilderError.self) {
      try await MiniPackage
        .plan(#""products": { "add": [{ "name": "S", "targets": ["SystemUser"] }] }"#)
    }
  }

  @Test func dependenciesKeepPlatformConditions() async throws {
    let wrapper = try await MiniPackage.module("Wrapper")
    #expect(dependencies(of: wrapper, wrappers: []) == [Dependency(
      name: "Prebuilt",
      platforms: [.ios]
    )])

    let plan = try await MiniPackage.plan()
    #expect(try plan.framework("SwiftLib").dependencies ==
      [Dependency(name: "CoreCInternal"), Dependency(name: "Mini-Extras")])
    #expect(try plan.framework("CoreCInternal").dependencies == [Dependency(name: "CoreC")])
  }

  @Test func wrapperDependenciesAreForwarded() async throws {
    // Treating CoreCInternal as a wrapper forwards its dependency on CoreC to SwiftLib.
    let swiftLib = try await MiniPackage.module("SwiftLib")
    #expect(dependencies(of: swiftLib, wrappers: ["CoreCInternal"]) ==
      [Dependency(name: "CoreC"), Dependency(name: "Mini-Extras")])
    #expect(dependencies(of: swiftLib, wrappers: ["CoreCInternal", "CoreC"]) ==
      [Dependency(name: "Mini-Extras")])
  }

  @Test func forwardedConditionsIntersect() {
    #expect(intersection(nil, [.ios]) == [.ios])
    #expect(intersection([.ios, .macos], nil) == [.ios, .macos])
    #expect(intersection([.ios, .macos], [.macos, .tvos]) == [.macos])
    #expect(intersection(nil, nil) == nil)
  }

  @Test func headers() async throws {
    let plan = try await MiniPackage.plan()
    #expect(try plan.framework("CoreC").headers == [
      Header(path: "Sources/CoreC/CCPrivate.h", visibility: .project),
      Header(path: "Sources/CoreC/include/CCThing.h", visibility: .public),
      Header(path: "Sources/CoreC/include/CoreC.h", visibility: .public),
    ])
    #expect(try plan.framework("CoreCInternal").headers == [
      Header(path: "Sources/CoreCInternal/Public/CoreCInternal/CCIHelper.h", visibility: .public),
    ])
    #expect(try plan.framework("Mini-Extras").headers.map(\.visibility) == [.public, .public])
    #expect(try plan.framework("SwiftLib").headers.isEmpty)
  }

  @Test func customModuleMap() async throws {
    let plan = try await MiniPackage
      .plan(#""products": { "add": [{ "name": "C", "targets": ["CustomMap"] }] }"#)
    #expect(try plan.framework("CustomMap").moduleMap ==
      "Sources/CustomMap/include/module.modulemap")
    // CoreC has an umbrella header, so SwiftPM generates its module map.
    #expect(try plan.framework("CoreC").moduleMap == nil)
  }

  @Test func sourcesAndResources() async throws {
    let plan = try await MiniPackage.plan()
    let coreC = try plan.framework("CoreC")
    #expect(coreC.sources == [Source(path: "Sources/CoreC/CCThing.m")])
    #expect(coreC.resources ==
      [Resource(path: "Sources/CoreC/PrivacyInfo.xcprivacy", rule: .process(localization: nil))])
    let swiftLib = try plan.framework("SwiftLib")
    #expect(swiftLib.sources == [Source(path: "Sources/SwiftLib/SwiftLib.swift")])
    #expect(swiftLib.resources == [Resource(path: "Sources/SwiftLib/Resources", rule: .copy)])
  }

  @Test func identity() async throws {
    let plan = try await MiniPackage.plan()
    let extras = try plan.framework("Mini-Extras")
    #expect(extras.moduleName == "Mini_Extras")
    #expect(extras.package == "Mini")
    #expect(extras.settings["PRODUCT_NAME"] == "Mini-Extras")
    #expect(extras.settings["PRODUCT_MODULE_NAME"] == "Mini_Extras")
    #expect(extras.bundleID == "com.example.Mini-Extras")
    #expect(extras.settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.example.Mini-Extras")
    #expect(extras.version == "1.2.3")
    #expect(extras.settings["MARKETING_VERSION"] == "1.2.3")
    #expect(extras.platforms == [.ios, .catalyst, .macos, .tvos, .watchos])
    #expect(extras.layout == Layout())
  }

  @Test func dynamicProduct() async throws {
    let plan = try await MiniPackage.plan()
    let headerOnly = try plan.framework("HeaderOnly")
    #expect(headerOnly.isDynamic)
    #expect(headerOnly.settings["MACH_O_TYPE"] == "mh_dylib")
    #expect(headerOnly.settings["DYLIB_INSTALL_NAME_BASE"] == "@rpath")
    #expect(try !plan.framework("CoreC").isDynamic)
    #expect(try plan.framework("CoreC").settings["MACH_O_TYPE"] == "staticlib")
    #expect(try plan.framework("CoreC").settings["DYLIB_INSTALL_NAME_BASE"] == nil)
  }

  @Test func binaryPlatformsComeFromInfoPlist() async throws {
    let plan = try await MiniPackage.plan()
    #expect(plan.binaries == [
      Binary(name: "Prebuilt", path: "Prebuilt.xcframework", platforms: [.ios], version: "1.2.3"),
    ])
  }

  @Test func catalystSlicesAreReadAsCatalyst() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/Catalyst.xcframework")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let libraries: [[String: String]] = [
      ["SupportedPlatform": "ios"],
      ["SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator"],
      ["SupportedPlatform": "ios", "SupportedPlatformVariant": "maccatalyst"],
      ["SupportedPlatform": "xros"],
    ]
    try PropertyListSerialization.data(fromPropertyList: ["AvailableLibraries": libraries],
                                       format: .xml, options: 0)
      .write(to: directory.appendingPathComponent("Info.plist"))
    #expect(try xcframeworkPlatforms(at: directory.path) == [.ios, .catalyst, .visionos])
  }

  @Test func headerSearchPaths() async throws {
    let plan = try await MiniPackage.plan()
    // Declared `.headerSearchPath(".")` and the own directory are the same path; its own public
    // headers directory is searched too, so its sources find their headers without header maps.
    #expect(try plan.framework("CoreC").settings["HEADER_SEARCH_PATHS"] ==
      ["Sources/CoreC", "Sources/CoreC/include"])
    let swiftLib = try #require(try plan.framework("SwiftLib").settings["HEADER_SEARCH_PATHS"])
    // Dependencies' headers come from their frameworks, not their sources, so nothing is defined
    // twice.
    #expect(swiftLib.list == ["Sources/SwiftLib"])
    #expect(try plan.framework("CoreCInternal").settings["HEADER_SEARCH_PATHS"] ==
      ["Sources/CoreCInternal", "Sources/CoreCInternal/Public"])
  }

  @Test func productRenamesNameFolders() async throws {
    let plan = try await MiniPackage.plan(#""products": { "rename": { "MiniCore": "Core" } }"#)
    #expect(plan.folders.map(\.name) == ["Core", "Mini", "MiniHeaders", "MiniPrebuilt"])
  }

  @Test func configDynamicFrameworksTranslateLinkerSettings() async throws {
    let plan = try await MiniPackage.plan(#""frameworks": { "dynamic": ["CoreC"] }"#)
    let coreC = try plan.framework("CoreC")
    #expect(coreC.isDynamic)
    #expect(coreC.settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
  }

  @Test func projectSettingsAndDeploymentTargets() async throws {
    let settings = try await MiniPackage.plan().settings
    #expect(settings["IPHONEOS_DEPLOYMENT_TARGET"] == "15.0")
    #expect(settings["MACOSX_DEPLOYMENT_TARGET"] == "11.0") // declared, not SwiftPM's 12.0
    #expect(settings["TVOS_DEPLOYMENT_TARGET"] == "15.0")
    #expect(settings["WATCHOS_DEPLOYMENT_TARGET"] == "9.0") // undeclared: SwiftPM's minimum
    #expect(settings["XROS_DEPLOYMENT_TARGET"] == "1.0")
    #expect(settings["IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"] == nil) // Catalyst matches iOS
    #expect(settings["SUPPORTED_PLATFORMS"] ==
      "iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator")
    #expect(settings["SUPPORTS_MACCATALYST"] == "YES")
    #expect(settings["TARGETED_DEVICE_FAMILY"] == "1,2,3,4,7")
    #expect(settings["USE_HEADERMAP"] == "NO")
    #expect(settings["GCC_PREPROCESSOR_DEFINITIONS"] == ["SWIFT_PACKAGE=1"])
    #expect(settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] == ["SWIFT_PACKAGE"])
    for key in ["BUILD_LIBRARY_FOR_DISTRIBUTION", "DEFINES_MODULE",
                "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES", "CLANG_ENABLE_OBJC_ARC",
                "CLANG_ENABLE_MODULES", "GENERATE_INFOPLIST_FILE"] {
      #expect(settings[key] == "YES")
    }
    #expect(settings["SKIP_INSTALL"] == "NO")
    #expect(settings["SWIFT_COMPILATION_MODE"] == "wholemodule")
    #expect(settings["CODE_SIGNING_ALLOWED"] == "NO")
    #expect(settings["CURRENT_PROJECT_VERSION"] == "1")
    #expect(settings["VERSIONING_SYSTEM"] == "apple-generic")
  }

  @Test func planJSONIsDeterministic() async throws {
    let plan = try await MiniPackage.plan()
    let first = try plan.json()
    let second = try await MiniPackage.plan().json()
    #expect(first == second)
    #expect(try JSONDecoder().decode(Plan.self, from: first) == plan)

    let binary = Binary(name: "B", path: "B.xcframework", platforms: [.watchos, .macos, .ios],
                        version: "1")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    for _ in 0 ..< 5 {
      #expect(try String(decoding: encoder.encode(binary), as: UTF8.self) ==
        #"{"name":"B","path":"B.xcframework","platforms":["ios","macos","watchos"],"version":"1"}"#)
    }
  }

  @Test func leavesTheFixtureClean() async throws {
    _ = try await MiniPackage.graph.value
    let contents = try FileManager.default.contentsOfDirectory(atPath: MiniPackage.path)
    #expect(!contents.contains(".build"))
    #expect(!contents.contains("Package.resolved"))
  }
}
