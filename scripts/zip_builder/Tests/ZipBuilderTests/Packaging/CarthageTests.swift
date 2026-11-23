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
import Foundation
import Testing
@testable import ZipBuilder

/// A distribution with `Base/{Core,Vendor}.xcframework`, `Other/Core.xcframework` and a root
/// `NOTICES`. Vendor is signed, as vendors' binaries are in an unsigned distribution.
private func makeDistribution(in root: URL) throws -> URL {
  let dist = root.appendingPathComponent("dist/Mini")
  try write("core", to: "Base/Core.xcframework/ios-arm64/Core.framework/Core", in: dist)
  try write("core", to: "Other/Core.xcframework/ios-arm64/Core.framework/Core", in: dist)
  try write("vendor", to: "Base/Vendor.xcframework/ios-arm64/Vendor.framework/Vendor", in: dist)
  try write("signature", to: "Base/Vendor.xcframework/_CodeSignature/CodeSignature", in: dist)
  try write("notices", to: "NOTICES", in: dist)
  return dist
}

private let umbrella = Config.UmbrellaFramework(
  folder: "Base", name: "Mini", header: "Sources/Mini.h", binary: "dummy_lib",
  bundleIdentifier: "com.example.Mini-Mini"
)

struct CarthageTests {
  @Test func makesTheUmbrellaFramework() throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    try write("#import <Core/Core.h>\n", to: "Sources/Mini.h", in: root)
    try write("placeholder", to: "dummy_lib", in: root)

    try makeUmbrellaFramework(umbrella, in: dist, version: "13.2.0-beta",
                              iOSDeploymentTarget: "15.0", packageRoot: root.path)

    let framework = dist.appendingPathComponent("Base/Mini.framework")
    #expect(files(in: framework.path) == ["Headers/Mini.h", "Info.plist", "Mini",
                                          "Modules/module.modulemap"])
    #expect(try String(contentsOf: framework.appendingPathComponent("Headers/Mini.h"),
                       encoding: .utf8) == "#import <Core/Core.h>\n")
    #expect(try String(contentsOf: framework.appendingPathComponent("Mini"), encoding: .utf8)
      == "placeholder")
    #expect(try String(contentsOf: framework.appendingPathComponent("Modules/module.modulemap"),
                       encoding: .utf8)
        == "framework module Mini {\n  header \"Mini.h\"\n  export *\n}\n")
    let plist = try #require(NSDictionary(contentsOf: framework.appendingPathComponent(
      "Info.plist"
    )) as? [String: String])
    #expect(plist == [
      "CFBundleExecutable": "Mini",
      "CFBundleIdentifier": "com.example.Mini-Mini",
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": "Mini",
      "CFBundlePackageType": "FMWK",
      "CFBundleShortVersionString": "13.2.0",
      "CFBundleVersion": "13.2.0",
      "MinimumOSVersion": "15.0",
    ])
  }

  @Test func theUmbrellaFrameworkHasNoMinimumOSVersionWithoutAnIOSTarget() {
    let plist = umbrellaInfoPlist(umbrella, version: "1.0.0", iOSDeploymentTarget: nil)
    #expect(plist["MinimumOSVersion"] == nil)
    #expect(plist["CFBundleVersion"] == "1.0.0")
  }

  @Test func theUmbrellaFrameworkNeedsItsFolderAndFiles() throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    func make(_ umbrella: Config.UmbrellaFramework) throws {
      try makeUmbrellaFramework(umbrella, in: dist, version: "1.0.0", iOSDeploymentTarget: nil,
                                packageRoot: root.path)
    }
    var missingFolder = umbrella
    missingFolder.folder = "Missing"
    #expect(throws: ZipBuilderError.self) { try make(missingFolder) }
    #expect(throws: ZipBuilderError.self) { try make(umbrella) } // no header yet
    try write("", to: "Sources/Mini.h", in: root)
    #expect(throws: ZipBuilderError.self) { try make(umbrella) } // no binary yet
    try write("", to: "dummy_lib", in: root)
    try make(umbrella)
    #expect(throws: ZipBuilderError.self) { try make(umbrella) } // already there
  }

  @Test func copiesFilesIntoXCFrameworks() throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)

    try addCarthageFiles(["Base/Core.xcframework": ["NOTICES"]], in: dist)
    #expect(try String(contentsOf: dist.appendingPathComponent("Base/Core.xcframework/NOTICES"),
                       encoding: .utf8) == "notices")
    #expect(!FileManager.default.fileExists(atPath: dist.path + "/Other/Core.xcframework/NOTICES"))

    let mistakes: [[Path: [Path]]] = [
      ["Base/Core.xcframework": ["NOTICES"]], // already copied
      ["Base/Core.xcframework": ["README.md"]], // no such file
      ["Base/Missing.xcframework": ["NOTICES"]], // no such .xcframework
      ["Base": ["NOTICES"]], // not an .xcframework
    ]
    for files in mistakes {
      #expect(throws: ZipBuilderError.self, "\(files)") { try addCarthageFiles(files, in: dist) }
    }
  }

  /// The xcframeworks carthage changes are checked for signatures; a signed vendor binary it
  /// leaves alone isn't.
  @Test func onlyRejectsSignedXCFrameworksItChanges() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let distribution = try await readDistribution(at: makeDistribution(in: root).path)
    let changed = xcframeworksChangedByCarthage(distribution, rebuilt: ["Core", "NotShipped"],
                                                files: ["Base/Core.xcframework": ["NOTICES"]])
    #expect(changed == ["Base/Core.xcframework", "Other/Core.xcframework"]
      .map { distribution.root + "/" + $0 })
    try checkUnsigned(changed)

    let withVendor = xcframeworksChangedByCarthage(distribution, rebuilt: [],
                                                   files: ["Base/Vendor.xcframework": ["NOTICES"]])
    let error = #expect(throws: ZipBuilderError.self) { try checkUnsigned(withVendor) }
    #expect(error?.description.contains("Base/Vendor.xcframework") == true)
  }

  /// Every copy is replaced in the staged copy; the input stays as it was.
  @Test func replacesRebuiltFrameworksInAStagedCopy() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    let rebuilt = root.appendingPathComponent("rebuilt")
    try write("carthage core", to: "Core.xcframework/ios-arm64/Core.framework/Core", in: rebuilt)
    try write("other", to: "Extra.xcframework/Info.plist", in: rebuilt)

    let staged = try stageDistribution(dist.path, at: root.appendingPathComponent("stage/Mini"))
    let (replaced, warnings) = try await collectingWarnings {
      try replacingFrameworks(["Extra", "Core"], in: staged, from: rebuilt.path)
    }
    #expect(replaced == ["Base/Core", "Other/Core"])
    #expect(warnings == [
      "carthage.rebuild: Extra was rebuilt, but the distribution has no Extra.xcframework; "
        + "skipped.",
    ])
    for folder in ["Base", "Other"] {
      let binary = "\(folder)/Core.xcframework/ios-arm64/Core.framework/Core"
      #expect(try String(contentsOf: staged.appendingPathComponent(binary), encoding: .utf8)
        == "carthage core")
      #expect(try String(contentsOf: dist.appendingPathComponent(binary), encoding: .utf8)
        == "core")
    }
    // The staging copy itself (or anything in it) can't be the input: staging would delete it.
    for input in [staged, staged.appendingPathComponent("Base")] {
      #expect(throws: ZipBuilderError.self) { try stageDistribution(input.path, at: staged) }
    }
    #expect(FileManager.default.fileExists(atPath: staged.path + "/Base/Core.xcframework"))
  }

  /// The extra build compiles the named frameworks and what they reach, from the whole plan.
  @Test func restrictsAPlanToWhatTheNamesReach() {
    var plan = SyntheticPackage.plan
    plan.folders = [Folder(name: "All", frameworks: ["A", "B", "C", "Bin"], files: [])]
    plan.keptStatic = ["B", "C"]
    let restricted = restricting(plan, toWhatIsReachedFrom: ["A"])
    #expect(restricted.frameworks.map(\.name) == ["B", "A"])
    #expect(restricted.binaries.map(\.name) == ["Bin"])
    #expect(restricted.folders.isEmpty)
    #expect(restricted.keptStatic == ["B"])
    #expect(restricted.settings == plan.settings)
    #expect(restricting(plan, toWhatIsReachedFrom: ["C"]).keptStatic == ["C"])
    #expect(restricting(plan, toWhatIsReachedFrom: ["Bin"]).frameworks.isEmpty)
  }
}

/// The command's checks before it changes anything.
struct CarthageCommandTests {
  /// Runs `carthage` with a config made of `sections` on the distribution at `dist`.
  private func runCarthage(_ sections: String, dist: URL, in root: URL) async throws {
    let config = root.appendingPathComponent("zip_builder.json")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "c" }\#(sections) }"#.utf8)
      .write(to: config)
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "carthage", dist.path, "--package-path", root.path, "--config", config.path,
      "--work-dir", root.appendingPathComponent("work").path, "--version", "1.0.0",
    ]) as? CarthageCommand)
    try await command.run()
  }

  @Test func rejectsOptionsThatDontApply() {
    for flags in [["--product", "Mini"], ["--product", "Mini", "--without-dependencies"]] {
      #expect(throws: (any Error).self, "\(flags)") {
        try ZipBuilderCommand.parseAsRoot(["carthage"] + flags)
      }
    }
    let command = try? ZipBuilderCommand.parseAsRoot([
      "carthage", "dist.zip", "--output", "out", "--cache-dir", "cache", "--linkage", "static",
    ]) as? CarthageCommand
    #expect(command?.distribution == "dist.zip")
    #expect(command?.output == "out")
    #expect(command?.cacheDir == "cache")
  }

  @Test func needsTheCarthageGroup() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let error = await #expect(throws: ZipBuilderError.self) {
      try await runCarthage("", dist: makeDistribution(in: root), in: root)
    }
    #expect(error?.description.hasPrefix("No carthage group in") == true)
  }

  @Test func needsDefinesAndRebuildTogether() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    for extra in [#""rebuild": "Mini""#, #""defines": ["A=1"]"#,
                  #""rebuild": "Mini", "defines": []"#] {
      let error = await #expect(throws: ZipBuilderError.self, "\(extra)") {
        try await runCarthage(#", "carthage": { "url": "u", "manifests": "m", \#(extra) }"#,
                              dist: dist, in: root)
      }
      #expect(error?.description.contains("go together") == true)
    }
  }

  /// A distribution signed with `--sign`: the xcframework `files` changes is signed.
  @Test func rejectsASignedDistribution() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    try write("signature", to: "Base/Core.xcframework/_CodeSignature/CodeSignature", in: dist)
    let error = await #expect(throws: ZipBuilderError.self) {
      try await runCarthage(#", "carthage": { "url": "u", "manifests": "m", "#
        + #""files": { "Base/Core.xcframework": ["NOTICES"] } }"#, dist: dist, in: root)
    }
    #expect(error?.description.contains("they're signed") == true)
    #expect(!FileManager.default.fileExists(atPath: root.path + "/work/carthage"))
  }

  /// Without an extra build or an umbrella framework, nothing is planned: the distribution is
  /// staged, changed and archived, and the input isn't touched.
  @Test func archivesAStagedCopy() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = try makeDistribution(in: root)
    _ = try await collectingWarnings {
      try await runCarthage(#", "carthage": { "url": "https://x/{version}/{archive}", "#
        + #""manifests": "{folder}.json", "files": { "Base/Core.xcframework": ["NOTICES"] } }"#,
        dist: dist, in: root)
    }
    let output = root.appendingPathComponent("work/carthage/1.0.0").path
    let written = try FileManager.default.contentsOfDirectory(atPath: output).sorted()
    #expect(written.filter { $0.hasSuffix(".json") } == ["Base.json", "Other.json"])
    #expect(written.filter { $0.hasSuffix(".zip") }.map { $0.prefix(5) } == ["Base-", "Other"])
    #expect(FileManager.default.fileExists(
      atPath: root.path + "/work/carthage-build/dist/Mini/Base/Core.xcframework/NOTICES"
    ))
    #expect(!FileManager.default.fileExists(atPath: dist.path + "/Base/Core.xcframework/NOTICES"))
  }
}
