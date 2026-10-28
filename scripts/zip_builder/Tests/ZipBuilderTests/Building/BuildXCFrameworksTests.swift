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

struct BuildXCFrameworksTests {
  @Test func cachedFrameworksBecomeBinaries() throws {
    let cached = ["B": "/cache/123/B.xcframework"]
    let plan = replacingCachedFrameworks(SyntheticPackage.plan, with: cached)
    #expect(plan.frameworks.map(\.name) == ["A", "C"])
    #expect(plan.binaries.map(\.name) == ["Bin", "B"])
    let binary = try #require(plan.binaries.last)
    #expect(binary.path == "/cache/123/B.xcframework")
    #expect(binary.platforms == [.ios, .macos])
    #expect(binary.version == "1.0.0")
    #expect(replacingCachedFrameworks(SyntheticPackage.plan, with: [:]) == SyntheticPackage.plan)
  }

  @Test func dependentsAlsoLinkBinariesTheyReachThroughCachedFrameworks() {
    // C → B → A → Bin (iOS only); A and B are cached.
    var plan = SyntheticPackage.plan
    plan.frameworks[1].dependencies = [Dependency(name: "Bin", platforms: [.ios])]
    plan.frameworks[0].dependencies = [Dependency(name: "A")]
    plan.frameworks[2].dependencies = [Dependency(name: "B")]
    plan.frameworks[2].platforms = [.ios, .macos]
    let built = replacingCachedFrameworks(plan, with: ["A": "/cache/1/A.xcframework",
                                                       "B": "/cache/2/B.xcframework"])
    #expect(built.frameworks.map(\.name) == ["C"])
    #expect(built.frameworks[0].dependencies == [
      Dependency(name: "A"), Dependency(name: "B"), Dependency(name: "Bin", platforms: [.ios]),
    ])
  }

  @Test func dependentsLinkCachedFrameworks() throws {
    let package = try SyntheticPackage()
    let cachedPath = "/cache/123/B.xcframework"
    let plan = replacingCachedFrameworks(SyntheticPackage.plan, with: ["B": cachedPath])
    let projectPath = package.root.appendingPathComponent("build/Frameworks.xcodeproj").path
    try makeProject(plan, packageRoot: package.root.path, at: projectPath)
    let project = try XcodeProj(pathString: projectPath)
    #expect(project.pbxproj.nativeTargets.map(\.name).sorted() == ["A", "C"])
    let a = try #require(project.pbxproj.nativeTargets.first { $0.name == "A" })
    let linked = a.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }.first?.files?
      .compactMap { $0.file?.path } ?? []
    #expect(linked.contains(cachedPath))
    #expect(linked.contains("Bin.xcframework"))
    #expect(a.dependencies.isEmpty) // B is no longer a target to build first
  }

  @Test func firstErrors() throws {
    let log = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/\(UUID().uuidString).log")
    try FileManager.default.createDirectory(at: log.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try Data("ok\n/a.m:1:2: error: boom\nnote\n/a.m:1:2: error: boom\nb.m: error: two\n".utf8)
      .write(to: log)
    #expect(ZipBuilder.firstErrors(in: log.path) == "/a.m:1:2: error: boom\nb.m: error: two")
    #expect(ZipBuilder.firstErrors(in: "/nonexistent") == "(no error: lines)")
    // At most `limit` distinct lines, in order.
    try Data((1 ... 5).map { "error: \($0)\n" }.joined().utf8).write(to: log)
    #expect(ZipBuilder.firstErrors(in: log.path, limit: 3) == "error: 1\nerror: 2\nerror: 3")
  }

  /// `<workDir>/xcframeworks`, standardized like the other work-dir paths.
  @Test func xcframeworksDirectoryIsInTheWorkDir() {
    #expect(xcframeworksDirectory(workDir: "/repo/build").path == "/repo/build/xcframeworks")
    #expect(xcframeworksDirectory(workDir: "/repo/tmp/../build/").path
      == "/repo/build/xcframeworks")
  }
}

/// Builds Fixtures/MiniPackage for iOS with `xcodebuild`, three times. Slow, so it only runs with
/// `ZIP_BUILDER_E2E=1`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ZIP_BUILDER_E2E"] != nil))
struct BuildEndToEndTests {
  @Test func buildsAndThenReusesTheCache() async throws {
    let plan = try await MiniPackage.customizedPlan(#""build": { "platforms": ["ios"] }, "#
      + #""layout": { "privacyBundle": { "*": "{target}_Privacy" } }"#)
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    // A copy of the fixture, so a source can change without touching the fixture.
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let workDir = root.appendingPathComponent("work")
    let cache = FrameworkCache(directory: root.appendingPathComponent("cache/frameworks").path)
    func build() async throws -> [Path] {
      try await buildXCFrameworks(plan, packageRoot: package.path, workDir: workDir.path,
                                  cache: cache)
    }

    // Cold: everything compiles.
    let paths = try await build()
    #expect(paths.count == plan.frameworks.count + plan.binaries.count)
    #expect(FileManager.default.fileExists(atPath: workDir.path + "/archives/ios.xcarchive"))
    let coreC = workDir.appendingPathComponent("xcframeworks/CoreC.xcframework")
    #expect(FileManager.default.fileExists(
      atPath: coreC.path + "/ios-arm64/CoreC.framework/CoreC_Privacy.bundle/PrivacyInfo.xcprivacy"
    ))

    // Unchanged: everything comes from the cache, so nothing is archived.
    #expect(try await build() == paths)
    #expect(!FileManager.default.fileExists(atPath: workDir.path + "/archives"))

    // CoreCInternal changes: it and its dependent SwiftLib compile, linking the cached rest.
    let source = package.appendingPathComponent("Sources/CoreCInternal/CCIHelper.m")
    let handle = try FileHandle(forWritingTo: source)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("// changed\n".utf8))
    try handle.close()
    #expect(try await build() == paths)
    let project = try XcodeProj(pathString: workDir.path + "/build-project/Frameworks.xcodeproj")
    #expect(project.pbxproj.nativeTargets.map(\.name).sorted() == ["CoreCInternal", "SwiftLib"])
    func linked(by target: String) throws -> [String] {
      let native = try #require(project.pbxproj.nativeTargets.first { $0.name == target })
      return native.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }.first?.files?
        .compactMap { $0.file?.path }.filter { $0.hasPrefix(cache.directory) }
        .map { URL(fileURLWithPath: $0).lastPathComponent }.sorted() ?? []
    }
    #expect(try linked(by: "CoreCInternal") == ["CoreC.xcframework"])
    #expect(try linked(by: "SwiftLib") == ["CoreC.xcframework", "Mini-Extras.xcframework"])
    let entries = try FileManager.default.contentsOfDirectory(atPath: cache.directory)
    #expect(entries.count == plan.frameworks.count + 2)
  }

  /// `linkage: dynamic`: every framework is a dynamic library with an `@rpath` install name and
  /// keeps the `Info.plist` Xcode generates, and a second build comes entirely from the cache.
  /// The fixture's only binary, `Prebuilt`, has no compiled slice and no framework links it, so
  /// the static-binary check passes; `LinkingTests` covers it failing.
  @Test func buildsDynamicFrameworks() async throws {
    let plan = try await MiniPackage.customizedPlan(
      #""build": { "platforms": ["ios"], "linkage": "dynamic" }, "#
        + #""layout": { "infoPlist": { "MinimumOSVersion": "100.0" } }"#
    )
    #expect(plan.frameworks.allSatisfy { $0.isDynamic })
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e-dynamic/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let workDir = root.appendingPathComponent("work")
    let cache = FrameworkCache(directory: root.appendingPathComponent("cache/frameworks").path)
    func build() async throws -> [Path] {
      try await buildXCFrameworks(plan, packageRoot: package.path, workDir: workDir.path,
                                  cache: cache)
    }

    let paths = try await build()
    #expect(paths.count == plan.frameworks.count + plan.binaries.count)
    for name in plan.frameworks.map(\.name) {
      let framework = workDir.path + "/xcframeworks/\(name).xcframework/ios-arm64/\(name).framework"
      let kind = try await shell("file", ["-b", framework + "/" + name])
      #expect(kind.contains("dynamically linked shared library"), "\(name): \(kind)")
      let installName = try await shell("otool", ["-D", framework + "/" + name])
        .split(separator: "\n").last.map(String.init)
      #expect(installName == "@rpath/\(name).framework/\(name)")
      let info = try #require(NSDictionary(contentsOfFile: framework + "/Info.plist"))
      #expect(info["CFBundleExecutable"] as? String == name)
      #expect(info["MinimumOSVersion"] as? String != "100.0", "\(name)")
    }

    // Unchanged: everything comes from the cache, so nothing is archived.
    #expect(try await build() == paths)
    #expect(!FileManager.default.fileExists(atPath: workDir.path + "/archives"))
  }

  /// `linkage: dynamic` with SwiftLib in `frameworks.static`: SwiftLib is a static library that
  /// depends on dynamic ones, and nothing reaches it, so the linkage check passes.
  @Test func buildsADynamicReleaseWithAStaticFramework() async throws {
    let plan = try await MiniPackage.customizedPlan(
      #""build": { "platforms": ["ios"], "linkage": "dynamic" }, "#
        + #""frameworks": { "static": ["SwiftLib"] }"#
    )
    #expect(plan.keptStatic == ["SwiftLib"])
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e-static-in-dynamic/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let workDir = root.appendingPathComponent("work")

    let paths = try await buildXCFrameworks(plan, packageRoot: package.path,
                                            workDir: workDir.path, cache: nil)
    #expect(paths.count == plan.frameworks.count + plan.binaries.count)
    for name in plan.frameworks.map(\.name) {
      let binary = workDir.path
        + "/xcframeworks/\(name).xcframework/ios-arm64/\(name).framework/\(name)"
      let kind = try await shell("file", ["-b", binary])
      let expected = name == "SwiftLib" ? "ar archive" : "dynamically linked shared library"
      #expect(kind.contains(expected), "\(name): \(kind)")
    }
  }

  /// C++ sources include their dependencies by paths only the dependencies' include directories
  /// serve (`<cpp_base/value.h>`, `"MEOne.h"`), and dynamic C++ frameworks link.
  @Test func buildsCppFrameworksThatIncludeByIncludeDirectoryPaths() async throws {
    let plan = try await MiniPackage.customizedPlan(
      #""build": { "platforms": ["ios"], "linkage": "dynamic" }, "#
        + #""products": { "add": [{ "name": "MiniCpp", "targets": ["CppUser"] }] }"#,
      product: "MiniCpp"
    )
    #expect(plan.frameworks.map(\.name).sorted() == ["CppBase", "CppUser", "Mini-Extras"])
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e-cpp/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let workDir = root.appendingPathComponent("work")

    _ = try await buildXCFrameworks(plan, packageRoot: package.path, workDir: workDir.path,
                                    cache: nil)
    for name in plan.frameworks.map(\.name) {
      let binary = workDir.path
        + "/xcframeworks/\(name).xcframework/ios-arm64/\(name).framework/\(name)"
      let kind = try await shell("file", ["-b", binary])
      #expect(kind.contains("dynamically linked shared library"), "\(name): \(kind)")
    }
  }

  /// `release --product Mini --without-dependencies`: Mini's folder holds only SwiftLib, its
  /// dependencies are built into `xcframeworks/` but not zipped, and verify links against them
  /// (`release` fails if it doesn't pass).
  @Test func releasesOneProductWithoutItsDependencies() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e-without-dependencies/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let configPath = root.appendingPathComponent("zip_builder.json").path
    try #"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" }, "#
      .appending(#""build": { "platforms": ["ios"] } }"#)
      .write(toFile: configPath, atomically: true, encoding: .utf8)
    let workDir = root.appendingPathComponent("work").path
    let release = try #require(try ZipBuilderCommand.parseAsRoot([
      "release", "--package-path", package.path, "--config", configPath, "--work-dir", workDir,
      "--cache-dir", root.appendingPathComponent("cache").path, "--version", "1.2.3",
      "--product", "Mini", "--without-dependencies",
    ]) as? ReleaseCommand)

    try await release.run()

    let config = try Config.load(from: configPath)
    let distribution = try await readDistribution(at: distributionRoot(workDir: workDir,
                                                                       config: config).path)
    #expect(distribution.folders.map(\.name) == ["Mini"])
    #expect(distribution.xcframeworks.map(\.name) == ["SwiftLib"])
    let xcframeworks = xcframeworksDirectory(workDir: workDir).path
    #expect(try FileManager.default.contentsOfDirectory(atPath: xcframeworks).sorted() == [
      "CoreC.xcframework", "CoreCInternal.xcframework", "Mini-Extras.xcframework",
      "SwiftLib.xcframework",
    ])
    let checks = try await verify(distribution, baseFolder: nil, skippedImports: [],
                                  requireSignatures: false,
                                  dependencies: readXCFrameworks(in: xcframeworks))
    #expect(checks[0].title.hasSuffix("(with 3 dependencies)"))
    let failed = checks.contains(where: \.failed)
    #expect(!failed, "\(renderVerification(checks, of: workDir))")
  }
}
