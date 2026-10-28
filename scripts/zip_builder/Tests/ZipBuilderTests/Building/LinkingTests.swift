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

/// SyntheticPackage's plan with every framework dynamic, and C depending on A:
/// `C` → `A` → `B`, `Bin`.
private func dynamicPlan() -> Plan {
  var plan = SyntheticPackage.plan
  for index in plan.frameworks.indices {
    plan.frameworks[index].isDynamic = true
    plan.frameworks[index].settings["MACH_O_TYPE"] = "mh_dylib"
  }
  plan.frameworks[2].dependencies = [Dependency(name: "A")]
  return plan
}

/// Writes `<name>.xcframework` into `root`, with one iOS framework slice whose binary is compiled
/// from C: a static archive, or a dynamic library. Only `file` reads it, so it's built for the
/// host.
private func writeXCFramework(named name: String, in root: URL, isStatic: Bool) async throws {
  let xcframework = root.appendingPathComponent("\(name).xcframework")
  let framework = xcframework.appendingPathComponent("ios-arm64/\(name).framework")
  try? FileManager.default.removeItem(at: xcframework)
  try FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
  let library: [String: Any] = ["LibraryIdentifier": "ios-arm64",
                                "LibraryPath": "\(name).framework", "SupportedPlatform": "ios"]
  try PropertyListSerialization.data(fromPropertyList: ["AvailableLibraries": [library]],
                                     format: .xml, options: 0)
    .write(to: xcframework.appendingPathComponent("Info.plist"))
  let source = framework.appendingPathComponent("code.c")
  try "int code(void) { return 1; }\n".write(to: source, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: source) }
  if isStatic {
    try await shell("xcrun", ["clang", "-c", "code.c", "-o", "code.o"], in: framework.path)
    try await shell("xcrun", ["libtool", "-static", "-o", name, "code.o"], in: framework.path)
    try FileManager.default.removeItem(at: framework.appendingPathComponent("code.o"))
  } else {
    try await shell("xcrun", ["clang", "-dynamiclib", "code.c", "-o", name], in: framework.path)
  }
}

/// The names (without extensions) and platform filters of what `target` links in a project made
/// from `plan`.
private func linked(by target: String, in plan: Plan, root: URL) throws -> [String] {
  let path = root.appendingPathComponent("build-\(UUID().uuidString)/Frameworks.xcodeproj").path
  try makeProject(plan, packageRoot: root.path, at: path)
  let project = try XcodeProj(pathString: path)
  let native = try #require(project.pbxproj.nativeTargets.first { $0.name == target })
  let files = native.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }.first?.files ?? []
  return files.map { file in
    let name = URL(fileURLWithPath: file.file?.path ?? "").deletingPathExtension()
      .lastPathComponent
    return name + " " + (file.platformFilters ?? []).joined(separator: ",")
  }.sorted()
}

struct LinkingTests {
  @Test func reachedDependenciesCarryThePlatformsOfTheirPaths() {
    // C → B → A → Bin (iOS only).
    var plan = SyntheticPackage.plan
    plan.frameworks[1].dependencies = [Dependency(name: "Bin", platforms: [.ios])]
    plan.frameworks[0].dependencies = [Dependency(name: "A")]
    plan.frameworks[2].dependencies = [Dependency(name: "B")]
    plan.frameworks[2].platforms = [.ios, .macos]
    #expect(reachedDependencies(from: plan.frameworks[2], in: plan) == [
      Dependency(name: "A"), Dependency(name: "B"), Dependency(name: "Bin", platforms: [.ios]),
    ])
    #expect(reachedDependencies(from: plan.frameworks[1], in: plan) == [
      Dependency(name: "Bin", platforms: [.ios]),
    ])
  }

  @Test func findsTheStaticBinariesDynamicFrameworksReach() async throws {
    let package = try SyntheticPackage()
    try await writeXCFramework(named: "Static", in: package.root, isStatic: true)
    try await writeXCFramework(named: "Dynamic", in: package.root, isStatic: false)
    let root = package.root.path
    #expect(try await isStaticLibrary(xcframework: root + "/Static.xcframework"))
    #expect(try await !isStaticLibrary(xcframework: root + "/Dynamic.xcframework"))
    // SyntheticPackage's `Bin` is a text file, so it can't be told; nor can a missing one.
    #expect(try await !isStaticLibrary(xcframework: root + "/Bin.xcframework"))
    #expect(try await !isStaticLibrary(xcframework: root + "/Missing.xcframework"))

    var plan = dynamicPlan()
    plan.binaries += ["Static", "Dynamic", "Unused"].map {
      Binary(name: $0, path: "\($0).xcframework", platforms: [.ios], version: "1")
    }
    plan.frameworks[0].dependencies = [Dependency(name: "Static"), Dependency(name: "Dynamic")]
    #expect(try await staticBinaries(reachedByDynamicFrameworksIn: plan, packageRoot: root)
      == ["Static"])
    // Static frameworks may link static binaries; their binaries aren't even inspected.
    #expect(try await staticBinaries(reachedByDynamicFrameworksIn: SyntheticPackage.plan,
                                     packageRoot: "/nonexistent").isEmpty)
  }

  @Test func dynamicFrameworksMustNotReachStaticBinaries() throws {
    // A (dynamic) → B (static) → Bin.
    var plan = SyntheticPackage.plan
    plan.frameworks[1].dependencies = [Dependency(name: "B")]
    plan.frameworks[0].dependencies = [Dependency(name: "Bin")]
    plan.frameworks[1].isDynamic = true
    let error = #expect(throws: ZipBuilderError.self) {
      try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: ["Bin"])
    }
    #expect(error?.description == """
    A is dynamic, but it depends on the static binary Bin, directly or through its dependencies, \
    so Bin's code would be copied into it. Build Bin from source (some packages offer a source \
    form, e.g. through an environment variable), or keep A static (frameworks.static).
    """)
    // Each dynamic framework is named.
    plan.frameworks[0].isDynamic = true
    let both = #expect(throws: ZipBuilderError.self) {
      try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: ["Bin"])
    }
    #expect(both?.description.split(separator: "\n").map { $0.prefix(2) } == ["B ", "A "])
    // A static framework, or a binary that isn't static, is fine.
    try checkDynamicFrameworksLinkNothingStatic(SyntheticPackage.plan, staticBinaries: ["Bin"])
    try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: [])
  }

  /// In a dynamic release, a framework `frameworks.static` keeps static counts like a static
  /// binary; a static framework that isn't kept doesn't, so static releases build as before.
  @Test func dynamicFrameworksMustNotReachKeptStaticFrameworks() throws {
    var plan = dynamicPlan() // C → A → B
    plan.frameworks[0].isDynamic = false
    // A static release: dynamic frameworks may absorb B.
    try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: [])
    plan.keptStatic = ["B"]
    let error = #expect(throws: ZipBuilderError.self) {
      try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: [])
    }
    #expect(error?.description == """
    A is dynamic, but it depends on the static framework B, directly or through its dependencies, \
    so B's code would be copied into it. Make B dynamic, or keep A static too, e.g. by listing it \
    in frameworks.static.
    C is dynamic, but it depends on the static framework B, directly or through its dependencies, \
    so B's code would be copied into it. Make B dynamic, or keep C static too, e.g. by listing it \
    in frameworks.static.
    """)
    // A kept framework may reach dynamic ones: C → A → B, with only C static.
    var topStatic = dynamicPlan()
    topStatic.frameworks[2].isDynamic = false
    topStatic.keptStatic = ["C"]
    try checkDynamicFrameworksLinkNothingStatic(topStatic, staticBinaries: [])
  }

  /// The fixture's plans: in a dynamic release, CoreC can't stay static, since dynamic frameworks
  /// reach it, but SwiftLib, which nothing reaches, can. A static release may still make SwiftLib
  /// dynamic, absorbing the static frameworks it reaches.
  @Test func checksTheFixturesPlans() async throws {
    let dynamicRelease = #""build": { "linkage": "dynamic" }"#
    let coreC = try await MiniPackage.customizedPlan(
      #""frameworks": { "static": ["CoreC"] }, "# + dynamicRelease
    )
    let error = #expect(throws: ZipBuilderError.self) {
      try checkDynamicFrameworksLinkNothingStatic(coreC, staticBinaries: [])
    }
    #expect(error?.description.split(separator: "\n").map { $0.prefix { $0 != "," } }.sorted() == [
      "CoreCInternal is dynamic", "SwiftLib is dynamic",
    ])
    #expect(error?.description.contains("depends on the static framework CoreC") == true)
    let swiftLib = try await MiniPackage.customizedPlan(
      #""frameworks": { "static": ["SwiftLib"] }, "# + dynamicRelease
    )
    try checkDynamicFrameworksLinkNothingStatic(swiftLib, staticBinaries: [])
    let staticRelease = try await MiniPackage.customizedPlan(
      #""frameworks": { "dynamic": ["SwiftLib"] }"#
    )
    #expect(try staticRelease.framework("SwiftLib").isDynamic)
    try checkDynamicFrameworksLinkNothingStatic(staticRelease, staticBinaries: [])
  }

  /// The check runs before anything is built or written.
  @Test func buildingFailsOnAStaticBinaryInADynamicFramework() async throws {
    let package = try SyntheticPackage()
    try await writeXCFramework(named: "Bin", in: package.root, isStatic: true)
    var plan = SyntheticPackage.plan
    plan.frameworks[1].isDynamic = true // A → Bin
    let workDir = package.root.appendingPathComponent("work")
    let error = await #expect(throws: ZipBuilderError.self) {
      try await buildXCFrameworks(plan, packageRoot: package.root.path, workDir: workDir.path,
                                  cache: nil)
    }
    #expect(error?.description.contains("A is dynamic, but it depends on the static binary Bin")
      == true)
    #expect(!FileManager.default.fileExists(atPath: workDir.path))
  }

  /// A dynamic framework links everything it reaches, with or without a cache; a static one only
  /// links the binaries it reaches once something is cached.
  @Test func dynamicFrameworksLinkWhatTheyReach() {
    let plan = dynamicPlan()
    let built = replacingCachedFrameworks(plan, with: [:])
    #expect(built.frameworks.map(\.name) == plan.frameworks.map(\.name))
    #expect(built.frameworks.map(\.dependencies) == [
      [], // B
      [Dependency(name: "B"), Dependency(name: "Bin")], // A
      [Dependency(name: "A"), Dependency(name: "B"), Dependency(name: "Bin")], // C
    ])
    // A static plan with nothing cached is unchanged.
    var staticPlan = plan
    for index in staticPlan.frameworks.indices {
      staticPlan.frameworks[index].isDynamic = false
    }
    #expect(replacingCachedFrameworks(staticPlan, with: [:]) == staticPlan)
  }

  /// The defensive half of the static-binary rule: the swap never adds one to a dynamic framework,
  /// while a static framework still links every binary it reaches.
  @Test func theSwapNeverLinksStaticBinariesIntoDynamicFrameworks() {
    var plan = dynamicPlan()
    plan.frameworks[1].dependencies = [Dependency(name: "B")] // A → B → Bin
    plan.frameworks[0].dependencies = [Dependency(name: "Bin")]
    plan.frameworks[0].isDynamic = false
    let built = replacingCachedFrameworks(plan, with: ["B": "/cache/1/B.xcframework"],
                                          staticBinaries: ["Bin"])
    #expect(built.frameworks.map(\.name) == ["A", "C"])
    #expect(built.frameworks[0].dependencies == [Dependency(name: "B")])
    #expect(built.frameworks[1].dependencies == [Dependency(name: "A"), Dependency(name: "B")])
  }

  /// Cached and uncached builds of a dynamic framework link the same things, so they produce the
  /// same binary.
  @Test func aDynamicFrameworksLinksDontDependOnTheCache() throws {
    let package = try SyntheticPackage()
    let plan = dynamicPlan()
    let uncached = replacingCachedFrameworks(plan, with: [:])
    let cached = replacingCachedFrameworks(plan, with: ["B": "/cache/1/B.xcframework"])
    #expect(cached.frameworks.map(\.name) == ["A", "C"])
    for target in ["A", "C"] {
      #expect(try linked(by: target, in: uncached, root: package.root)
        == linked(by: target, in: cached, root: package.root))
    }
    #expect(try linked(by: "C", in: cached, root: package.root) == ["A ", "B ", "Bin "])
  }
}
