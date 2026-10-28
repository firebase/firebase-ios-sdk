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
import XcodeProj
@testable import ZipBuilder

/// `makeProject` on Fixtures/MiniPackage. Projects are written to a temporary directory and read
/// back with XcodeProj.
struct MakeProjectTests {
  /// A generated project, read back.
  struct Written {
    var project: XcodeProj
    var directory: URL // holds Mini.xcodeproj and Generated/

    var targets: [PBXNativeTarget] {
      project.pbxproj.nativeTargets.sorted { $0.name < $1.name }
    }

    func target(_ name: String) throws -> PBXNativeTarget {
      try #require(project.pbxproj.nativeTargets.first { $0.name == name })
    }

    func settings(_ target: String) throws -> [String: Any] {
      try #require(self.target(target).buildConfigurationList?.buildConfigurations.first)
        .buildSettings
    }

    var projectSettings: [String: Any] {
      project.pbxproj.rootObject?.buildConfigurationList.buildConfigurations.first?
        .buildSettings ?? [:]
    }
  }

  static func write(_ plan: Plan) throws -> Written {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/projects/\(UUID().uuidString)")
    let path = directory.appendingPathComponent("Mini.xcodeproj").path
    try makeProject(plan, packageRoot: MiniPackage.path, at: path)
    return try Written(project: XcodeProj(pathString: path), directory: directory)
  }

  static func write(_ sections: String = "") async throws -> Written {
    try await write(MiniPackage.customizedPlan(sections))
  }

  @Test func oneTargetPerFramework() async throws {
    let written = try await Self.write(#""zip": { "files": [{ "to": ".", "files": ["N"] }] }"#)
    #expect(written.targets.map(\.name) ==
      ["CoreC", "CoreCInternal", "HeaderOnly", "Mini-Extras", "SwiftLib"])
    // HeaderOnly is in a dynamic product; folders, including ".", aren't targets.
    #expect(try written.target("HeaderOnly").productType == .framework)
    #expect(try written.target("CoreC").productType == .staticFramework)
    #expect(written.project.pbxproj.rootObject?.projectDirPath == MiniPackage.path)
    let configurations = written.project.pbxproj.rootObject?.buildConfigurationList
      .buildConfigurations.map(\.name)
    #expect(configurations == ["Release"])
    // No localized resources: just the development region and Base.
    #expect(written.project.pbxproj.rootObject?.knownRegions == ["en", "Base"])
  }

  @Test func phases() async throws {
    let written = try await Self.write(#""frameworks": { "privateHeaders": ["CCThing.h"] }"#)
    let coreC = try written.target("CoreC")
    let headers = try #require(coreC.buildPhases.compactMap { $0 as? PBXHeadersBuildPhase }.first)
    #expect(headers.files?.map { $0.file?.path ?? "" } == [
      "Sources/CoreC/CCPrivate.h", "Sources/CoreC/include/CCThing.h",
      "Sources/CoreC/include/CoreC.h",
    ])
    #expect(headers.files?.map { $0.settings?["ATTRIBUTES"] as? [String] } ==
      [nil, ["Private"], ["Public"]])
    #expect(try coreC.sourceFiles().map(\.path) == ["Sources/CoreC/CCThing.m"])
    #expect(try coreC.resourcesBuildPhase()?.files?.map { $0.file?.path } ==
      ["Sources/CoreC/PrivacyInfo.xcprivacy"])
    // A copied resource directory is a folder reference.
    let copied = try #require(written.target("SwiftLib").resourcesBuildPhase()?.files?.first?.file)
    #expect(copied.path == "Sources/SwiftLib/Resources")
    #expect((copied as? PBXFileReference)?.lastKnownFileType == "folder")
  }

  /// Localized copies of a file share one variant group, named after the file and keyed by the
  /// directory holding the `.lproj`s, with one build file. Their localizations are known regions.
  @Test func localizedResourcesShareAVariantGroup() async throws {
    var plan = try await MiniPackage.customizedPlan("")
    let index = try #require(plan.frameworks.firstIndex { $0.name == "CoreC" })
    plan.frameworks[index].resources += [
      ("Sources/CoreC/Resources/en.lproj/Main.strings", "en"),
      ("Sources/CoreC/Resources/fr.lproj/Main.strings", "fr"),
      ("Sources/CoreC/Other/de.lproj/Main.strings", "de"), // another directory, another group
    ].map { Resource(path: $0.0, rule: .process(localization: $0.1)) }
    let written = try Self.write(plan)

    let files = try #require(written.target("CoreC").resourcesBuildPhase()?.files)
    #expect(files.map { $0.file?.name } == ["PrivacyInfo.xcprivacy", "Main.strings",
                                            "Main.strings"])
    let variantGroups = files.compactMap { $0.file as? PBXVariantGroup }
    #expect(variantGroups.map { $0.children.map(\.name) } == [["en", "fr"], ["de"]])
    #expect(variantGroups.first?.children.map(\.path) == [
      "Sources/CoreC/Resources/en.lproj/Main.strings",
      "Sources/CoreC/Resources/fr.lproj/Main.strings",
    ])
    let group = try #require(written.project.pbxproj.rootObject?.mainGroup.children
      .first { $0.name == "CoreC" } as? PBXGroup)
    #expect(group.children.compactMap { $0 as? PBXVariantGroup } == variantGroups)
    #expect(written.project.pbxproj.rootObject?.knownRegions == ["en", "Base", "fr", "de"])
  }

  @Test func platformFiltersOnSourcesAndDependencies() async throws {
    let written = try await Self.write("""
    "frameworks": { "merge": { "SwiftLib": ["CoreCInternal"] },
                    "platforms": { "CoreCInternal": ["ios"] } }
    """)
    let swiftLib = try written.target("SwiftLib")
    let sources = try #require(swiftLib.buildPhases.compactMap { $0 as? PBXSourcesBuildPhase }
      .first?.files)
    #expect(sources.map { $0.file?.path } ==
      ["Sources/CoreCInternal/CCIHelper.m", "Sources/SwiftLib/SwiftLib.swift"])
    #expect(sources.map(\.platformFilters) == [["ios"], nil])
    #expect(swiftLib.dependencies.map { $0.target?.name } == ["CoreC", "Mini-Extras"])
    #expect(swiftLib.dependencies.map(\.platformFilters) == [["ios"], nil])
    let linked = try #require(swiftLib.frameworksBuildPhase()?.files)
    #expect(linked.map { $0.file?.path } == ["CoreC.framework", "Mini-Extras.framework"])
    #expect(linked.map(\.platformFilters) == [["ios"], nil])
  }

  @Test func binariesAreLinkedWithFilters() async throws {
    var plan = try await MiniPackage.customizedPlan("")
    let index = try #require(plan.frameworks.firstIndex { $0.name == "CoreC" })
    plan.frameworks[index].dependencies = [Dependency(name: "Prebuilt", platforms: [.ios])]
    let written = try Self.write(plan)
    let linked = try #require(written.target("CoreC").frameworksBuildPhase()?.files?.first)
    let binary = try #require(linked.file as? PBXFileReference)
    #expect(binary.path == "Prebuilt.xcframework")
    #expect(binary.sourceTree == .sourceRoot)
    #expect(binary.lastKnownFileType == "wrapper.xcframework")
    #expect(linked.platformFilters == ["ios"])
    #expect(try written.target("CoreC").dependencies.isEmpty)
  }

  @Test func oneSchemePerDestination() async throws {
    let written = try await Self.write("""
    "build": { "platforms": ["ios", "catalyst", "macos"] },
    "frameworks": { "platforms": { "SwiftLib": ["ios"] } }
    """)
    let schemes = try #require(written.project.sharedData?.schemes).sorted { $0.name < $1.name }
    #expect(schemes.map(\.name) == ["catalyst", "ios", "ios-simulator", "macos"])
    func built(_ scheme: XCScheme) -> [String] {
      scheme.buildAction?.buildActionEntries.map(\.buildableReference.blueprintName) ?? []
    }
    #expect(built(schemes[1]) == ["CoreC", "CoreCInternal", "HeaderOnly", "Mini-Extras",
                                  "SwiftLib"])
    #expect(built(schemes[3]) == ["CoreC", "CoreCInternal", "HeaderOnly", "Mini-Extras"])
    #expect(schemes.allSatisfy { $0.archiveAction?.buildConfiguration == "Release" })
  }

  @Test func projectAndTargetSettings() async throws {
    let written = try await Self.write(#""frameworks": { "platforms": { "CoreC": ["ios"] } }"#)
    #expect(written.projectSettings["GCC_PREPROCESSOR_DEFINITIONS"] as? [String] ==
      ["SWIFT_PACKAGE=1"])
    #expect(written.projectSettings["SUPPORTS_MACCATALYST"] as? String == "YES")
    let coreC = try written.settings("CoreC")
    // Target lists start with $(inherited), so the project's definitions still apply.
    #expect(coreC["GCC_PREPROCESSOR_DEFINITIONS"] as? [String] == ["$(inherited)", "CORE_FLAG=1"])
    #expect(coreC["GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]"] as? [String] ==
      ["$(inherited)", "CORE_IOS_ONLY"])
    #expect(coreC["HEADER_SEARCH_PATHS"] as? [String] ==
      ["$(inherited)", "$(SRCROOT)/Sources/CoreC", "$(SRCROOT)/Sources/CoreC/include"])
    #expect(coreC["PRODUCT_NAME"] as? String == "CoreC")
    #expect(coreC["SUPPORTED_PLATFORMS"] as? String == "iphoneos iphonesimulator")
    #expect(coreC["SUPPORTS_MACCATALYST"] as? String == "NO")
    let swiftLib = try written.settings("SwiftLib")
    #expect(swiftLib["SUPPORTED_PLATFORMS"] as? String ==
      "iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator")
    #expect(swiftLib["SUPPORTS_MACCATALYST"] == nil)
  }

  @Test func synthesizedUmbrellaHeader() async throws {
    let written = try await Self.write()
    let umbrella = written.directory.appendingPathComponent("Generated/Mini-Extras/Mini_Extras.h")
    let text = try String(contentsOf: umbrella, encoding: .utf8)
    #expect(text.contains("#import <Mini-Extras/MEOne.h>\n#import <Mini-Extras/METwo.h>\n"))
    #expect(text.contains("FOUNDATION_EXPORT double Mini_ExtrasVersionNumber;"))
    let headers = try written.target("Mini-Extras").buildPhases
      .compactMap { $0 as? PBXHeadersBuildPhase }.first?.files ?? []
    #expect(headers.last?.file?.path == umbrella.path)
    #expect(headers.last?.settings?["ATTRIBUTES"] as? [String] == ["Public"])
    #expect(try written.settings("Mini-Extras")["VERSIONING_SYSTEM"] == nil) // set project-wide
    // CoreC has its own umbrella header, CoreC.h; SwiftLib (pure Swift) gets one too.
    let generated = try FileManager.default.contentsOfDirectory(
      atPath: written.directory.appendingPathComponent("Generated").path
    )
    #expect(generated.sorted() == ["CoreCInternal", "HeaderOnly", "Mini-Extras", "SwiftLib"])
  }

  @Test func umbrellaNextToAHeaderWithDeclarations() async throws {
    // After the rename, CCIHelper.h is named like the framework but declares a function.
    let written = try await Self
      .write(#""frameworks": { "rename": { "CoreCInternal": "CCIHelper" } }"#)
    let directory = written.directory.appendingPathComponent("Generated/CCIHelper")
    let umbrella = try String(contentsOf: directory.appendingPathComponent("CCIHelper-umbrella.h"),
                              encoding: .utf8)
    #expect(umbrella.contains("#import <CCIHelper/CCIHelper.h>\n"))
    let moduleMap = directory.appendingPathComponent("module.modulemap")
    #expect(try String(contentsOf: moduleMap, encoding: .utf8) == """
    framework module CCIHelper {
      umbrella header "CCIHelper-umbrella.h"
      export *
      module * { export * }
    }

    """)
    #expect(try written.settings("CCIHelper")["MODULEMAP_FILE"] as? String == moduleMap.path)
  }

  @Test func projectCommandReadsAPlan() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/projects/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let planPath = directory.appendingPathComponent("plan.json")
    try await MiniPackage.customizedPlan("").json().write(to: planPath)
    let configPath = directory.appendingPathComponent("config.json")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" } }"#.utf8)
      .write(to: configPath)
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "project", "--package-path", MiniPackage.path, "--config", configPath.path,
      "--work-dir", directory.path, "--plan", planPath.path,
    ]) as? ProjectCommand)
    try await command.run()
    let path = directory.appendingPathComponent("Mini.xcodeproj").path
    #expect(try XcodeProj(pathString: path).pbxproj.nativeTargets.count == 5)
  }
}
