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
import Testing
@testable import ZipBuilder

/// `customize` on Fixtures/MiniPackage. Before customizing, the frameworks are CoreC,
/// CoreCInternal, HeaderOnly, Mini-Extras and SwiftLib, and the binary is Prebuilt (iOS only).
struct CustomizeTests {
  private func folder(_ plan: Plan, _ name: String) throws -> [String] {
    try #require(plan.folders.first { $0.name == name }).frameworks
  }

  @Test func emptyConfigChangesNothing() async throws {
    #expect(try await MiniPackage.customizedPlan("") == MiniPackage.plan())
  }

  @Test func mergingCompanions() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "merge": { "SwiftLib": ["CoreCInternal"] },
                    "platforms": { "CoreCInternal": ["ios"] } }
    """)
    #expect(plan.frameworks.map(\.name) == ["CoreC", "HeaderOnly", "Mini-Extras", "SwiftLib"])
    let swiftLib = try plan.framework("SwiftLib")
    // The companion's sources and dependencies only apply on its platforms.
    #expect(swiftLib.sources == [
      Source(path: "Sources/CoreCInternal/CCIHelper.m", platforms: [.ios]),
      Source(path: "Sources/SwiftLib/SwiftLib.swift"),
    ])
    #expect(swiftLib.headers == [
      Header(path: "Sources/CoreCInternal/Public/CoreCInternal/CCIHelper.h", visibility: .public),
    ])
    #expect(swiftLib.dependencies ==
      [Dependency(name: "CoreC", platforms: [.ios]), Dependency(name: "Mini-Extras")])
    #expect(swiftLib.settings["PRODUCT_NAME"] == "SwiftLib")
    #expect(swiftLib.settings["SWIFT_VERSION"] == "5.0")
    let searchPaths = try #require(swiftLib.settings["HEADER_SEARCH_PATHS"]).list
    #expect(searchPaths.first == "Sources/SwiftLib")
    #expect(searchPaths.contains("Sources/CoreCInternal"))
    #expect(try folder(plan, "Mini") == ["CoreC", "Mini-Extras", "SwiftLib"])
  }

  @Test func mergingDropsTheCompanionsUmbrellaHeader() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "merge": { "CoreCInternal": ["CoreC"] } }
    """)
    let merged = try plan.framework("CoreCInternal")
    #expect(merged.headers == [
      Header(path: "Sources/CoreC/CCPrivate.h", visibility: .project),
      Header(path: "Sources/CoreC/include/CCThing.h", visibility: .public),
      Header(path: "Sources/CoreCInternal/Public/CoreCInternal/CCIHelper.h", visibility: .public),
    ])
    #expect(merged.resources.map(\.path) == ["Sources/CoreC/PrivacyInfo.xcprivacy"])
    #expect(merged.dependencies.isEmpty)
    #expect(merged.settings["GCC_PREPROCESSOR_DEFINITIONS"] == ["CORE_FLAG=1"])
    #expect(merged.settings["GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]"] ==
      ["$(inherited)", "CORE_IOS_ONLY"])
    #expect(merged.settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.example.CoreCInternal")
    #expect(try folder(plan, "MiniCore") == ["CoreCInternal"])
    #expect(try folder(plan, "Mini") == ["CoreCInternal", "Mini-Extras", "SwiftLib"])
  }

  @Test func renaming() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "rename": { "Mini-Extras": "Extras", "Nope": "X" } }
    """)
    let extras = try plan.framework("Extras")
    #expect(extras.moduleName == "Extras")
    #expect(extras.bundleID == "com.example.Extras")
    #expect(extras.settings["PRODUCT_NAME"] == "Extras")
    #expect(extras.settings["PRODUCT_MODULE_NAME"] == "Extras")
    #expect(extras.settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.example.Extras")
    #expect(try plan.framework("SwiftLib").dependencies.map(\.name) == ["CoreCInternal", "Extras"])
    #expect(try folder(plan, "Mini") == ["CoreC", "CoreCInternal", "Extras", "SwiftLib"])
  }

  @Test func customModuleMapsThroughMergeRenameAndAggregate() async throws {
    let add = #""products": { "add": [{ "name": "C", "targets": ["CustomMap"] }] }, "#
    let map = "Sources/CustomMap/include/module.modulemap"
    // A parent keeps its map; a companion's is dropped, like its umbrella header.
    let parent = try await MiniPackage
      .customizedPlan(add + #""frameworks": { "merge": { "CustomMap": ["CoreC"] } }"#)
    #expect(try parent.framework("CustomMap").moduleMap == map)
    let companion = try await MiniPackage
      .customizedPlan(add + #""frameworks": { "merge": { "CoreC": ["CustomMap"] } }"#)
    #expect(try companion.framework("CoreC").moduleMap == nil)
    // Renaming keeps it (the module name is substituted when it's written); aggregating drops it.
    let renamed = try await MiniPackage
      .customizedPlan(add + #""frameworks": { "rename": { "CustomMap": "Mapped" } }"#)
    #expect(try renamed.framework("Mapped").moduleMap == map)
    let aggregated = try await MiniPackage
      .customizedPlan(add + #""frameworks": { "aggregate": ["Mini"] }"#)
    #expect(try aggregated.framework("Mini").moduleMap == nil)
  }

  @Test func aggregatingAPackage() async throws {
    let plan = try await MiniPackage.customizedPlan(#""frameworks": { "aggregate": ["Mini"] }"#)
    #expect(plan.frameworks.map(\.name) == ["Mini"])
    let mini = try plan.framework("Mini")
    #expect(mini.moduleName == "Mini")
    #expect(mini.bundleID == "com.example.Mini")
    #expect(mini.version == "1.2.3")
    #expect(!mini.isDynamic)
    #expect(mini.settings["MACH_O_TYPE"] == "staticlib")
    // Single values come from the first part (CoreC, with the tools version's default).
    #expect(mini.settings["SWIFT_VERSION"] == "6.0")
    #expect(mini.sources.count == 5)
    #expect(mini.dependencies.isEmpty)
    // The parts' public headers, except CoreC's own umbrella header CoreC.h.
    #expect(mini.headers.filter { $0.visibility == .public }.map(\.path) == [
      "Sources/CoreC/include/CCThing.h",
      "Sources/CoreCInternal/Public/CoreCInternal/CCIHelper.h",
      "Sources/HeaderOnly/include/HOProtocol.h",
      "Sources/MiniExtras/include/MEOne.h",
      "Sources/MiniExtras/include/METwo.h",
    ])
    #expect(plan.folders.map(\.frameworks) == [["Mini"], ["Mini"], ["Mini"], ["Prebuilt"]])
  }

  @Test func addingPublicHeaders() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "publicHeaders": {
      "SwiftLib": ["Sources/CoreC/include", "Sources/CoreCInternal/"] } }
    """)
    #expect(try plan.framework("SwiftLib").headers == [
      Header(path: "Sources/CoreC/include/CCThing.h", visibility: .public),
      Header(path: "Sources/CoreC/include/CoreC.h", visibility: .public),
      Header(path: "Sources/CoreCInternal/Public/CoreCInternal/CCIHelper.h", visibility: .public),
    ])
  }

  @Test func privateAndHiddenHeaders() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "privateHeaders": ["CCThing.h"], "hiddenHeaders": ["ME*.h"] }
    """)
    #expect(try plan.framework("CoreC").headers.map(\.visibility) == [.project, .private, .public])
    #expect(try plan.framework("Mini-Extras").headers.map(\.visibility) == [.project, .project])
  }

  @Test func restrictingPlatforms() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "products": { "platforms": { "Mini": ["ios", "tvos"], "MiniPrebuilt": ["tvos"] } },
    "frameworks": { "platforms": { "CoreC": ["ios", "macos"] } },
    "build": { "platforms": ["ios", "macos", "tvos"] }
    """)
    #expect(try plan.framework("CoreCInternal").platforms == [.ios, .tvos])
    #expect(try plan.framework("SwiftLib").platforms == [.ios, .tvos])
    // In Mini and MiniCore (all release platforms), restricted to iOS and macOS.
    #expect(try plan.framework("CoreC").platforms == [.ios, .macos])
    #expect(try plan.framework("HeaderOnly").platforms == [.ios, .macos, .tvos])
    // CoreC is only built on iOS of CoreCInternal's platforms.
    #expect(try plan.framework("CoreCInternal").dependencies ==
      [Dependency(name: "CoreC", platforms: [.ios])])
    #expect(try plan.framework("SwiftLib").dependencies ==
      [Dependency(name: "CoreCInternal"), Dependency(name: "Mini-Extras")])
    // Prebuilt only has iOS slices, but MiniPrebuilt ships on tvOS only, so it's dropped.
    #expect(plan.binaries.isEmpty)
  }

  @Test func buildMode() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "build": { "defineSwiftPackage": false, "defines": ["COCOAPODS=1"],
               "swiftConditions": ["COCOAPODS"], "versionMacro": "Mini_VERSION",
               "swiftVersion": { "*": "5.0", "SwiftLib": "6.0" },
               "architectures": { "watchos": ["arm64", "arm64_32"] },
               "deploymentTargets": { "ios": "16.0" } },
    "frameworks": { "dynamic": ["CoreC"] }
    """)
    #expect(plan.settings["GCC_PREPROCESSOR_DEFINITIONS"] == ["COCOAPODS=1", "Mini_VERSION=1.2.3"])
    #expect(plan.settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] == ["COCOAPODS"])
    #expect(plan.settings["ARCHS[sdk=watchos*]"] == ["arm64", "arm64_32"])
    #expect(plan.settings["IPHONEOS_DEPLOYMENT_TARGET"] == "16.0")
    // Mac Catalyst follows iOS up.
    #expect(plan.settings["IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"] == nil)
    #expect(try plan.framework("SwiftLib").settings["SWIFT_VERSION"] == "6.0")
    #expect(try plan.framework("CoreC").settings["SWIFT_VERSION"] == "5.0")
    #expect(try plan.framework("CoreC").isDynamic)
    #expect(try plan.framework("CoreC").settings["MACH_O_TYPE"] == "mh_dylib")
  }

  @Test func settingsReplaceEveryVariant() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "build": { "settings": { "GCC_PREPROCESSOR_DEFINITIONS": "X=1" } }
    """)
    #expect(plan.settings["GCC_PREPROCESSOR_DEFINITIONS"] == "X=1")
    let coreC = try plan.framework("CoreC")
    #expect(!coreC.settings.keys.contains { $0.hasPrefix("GCC_PREPROCESSOR_DEFINITIONS") })
  }

  @Test func layout() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "layout": { "privacyBundle": { "*": "{target}_Privacy", "Mini-Extras": "Unused" },
                "resourceBundles": { "SwiftLib": "SwiftLibResources" },
                "infoPlist": { "MinimumOSVersion": "100.0" } }
    """)
    let infoPlist = ["MinimumOSVersion": "100.0"]
    #expect(try plan.framework("CoreC").layout ==
      Layout(privacyBundle: "CoreC_Privacy", infoPlist: infoPlist))
    // No privacy manifest, so no privacy bundle.
    #expect(try plan.framework("Mini-Extras").layout == Layout(infoPlist: infoPlist))
    #expect(try plan.framework("SwiftLib").layout ==
      Layout(resourceBundle: "SwiftLibResources", infoPlist: infoPlist))
  }

  @Test func arrangingFolders() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "products": { "withoutFolder": ["MiniHeaders"],
                  "base": { "product": "Mini", "frameworks": ["CoreC"] },
                  "rename": { "MiniPrebuilt": "Prebuilt" },
                  "extraFrameworks": { "Prebuilt": ["HeaderOnly"] } }
    """)
    #expect(plan.folders.map(\.name) == ["Mini", "MiniCore", "Prebuilt"])
    #expect(plan.folders.map(\.frameworks) == [
      ["CoreC", "CoreCInternal", "Mini-Extras", "SwiftLib"], [], ["HeaderOnly", "Prebuilt"],
    ])
    // Products without a folder are still built.
    #expect(try plan.framework("HeaderOnly").isDynamic)
  }

  @Test func zipFilesGoInFolders() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "zip": { "files": [{ "to": ".", "files": ["NOTICES"] },
                       { "to": "MiniCore", "files": ["run", "upload"] },
                       { "to": "Missing", "files": ["x"] }] }
    """)
    #expect(plan.folders.map(\.name) == [".", "Mini", "MiniCore", "MiniHeaders", "MiniPrebuilt"])
    #expect(plan.folders[0] == Folder(name: ".", frameworks: [], files: ["NOTICES"]))
    #expect(plan.folders[2].files == ["run", "upload"])
  }
}
