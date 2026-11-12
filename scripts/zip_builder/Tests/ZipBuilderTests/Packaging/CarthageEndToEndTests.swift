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

/// The fixture's config for `carthage`: an extra build of MiniCore (CoreC) with a define, the
/// notices copied into MiniCore's CoreC, and an umbrella framework in Mini.
private let carthageConfig = """
{
  "release": { "name": "Mini", "bundleIdPrefix": "com.example" },
  "build": { "platforms": ["ios"] },
  "zip": { "notices": {} },
  "carthage": {
    "url": "https://example.com/{version}/{archive}",
    "manifests": "Carthage/{folder}Binary.json",
    "defines": ["MINI_CARTHAGE=1"],
    "rebuild": "MiniCore",
    "files": { "MiniCore/CoreC.xcframework": ["NOTICES"] },
    "umbrellaFramework": {
      "folder": "Mini", "name": "MiniUmbrella", "header": "Sources/CoreC/include/CoreC.h",
      "binary": "dummy_lib", "bundleIdentifier": "com.example.MiniUmbrella"
    }
  }
}
"""

extension BuildEndToEndTests {
  /// `package`, then `carthage` twice: the extra build compiles CoreC with the define (its own
  /// cache entry) and replaces both copies, the archives and binary specs are written, and the
  /// input distribution isn't changed. The second run takes CoreC from the cache and gives the
  /// same archives.
  @Test func packagesForCarthage() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/e2e-carthage/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    try write("placeholder", to: "dummy_lib", in: package)
    try write("{\n  \"1.0.0\": \"https://example.com/1.0.0/Mini-old.zip\"\n}\n",
              to: "Carthage/MiniBinary.json", in: package)
    let configPath = root.appendingPathComponent("zip_builder.json").path
    try carthageConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
    let workDir = root.appendingPathComponent("work")
    let cache = root.appendingPathComponent("cache").path
    let shared = ["--package-path", package.path, "--config", configPath,
                  "--work-dir", workDir.path, "--cache-dir", cache, "--version", "1.2.3"]
    let packageCommand = try #require(
      try ZipBuilderCommand.parseAsRoot(["package"] + shared) as? PackageCommand
    )
    try await packageCommand.run()
    let carthage = try #require(
      try ZipBuilderCommand.parseAsRoot(["carthage"] + shared) as? CarthageCommand
    )

    let warnings = try await collectingWarnings { try await carthage.run() }.warnings
    #expect(warnings.filter { $0.hasPrefix("carthage") } == ["MiniCore", "MiniHeaders",
                                                             "MiniPrebuilt"].map {
        "carthage.manifests: Carthage/\($0)Binary.json doesn't exist; it's created with only 1.2.3."
      })

    // The extra build: only CoreC, with the define, cached apart from the zip's CoreC.
    let buildDir = workDir.appendingPathComponent("carthage-build")
    let plan = try Plan.read(from: buildDir.appendingPathComponent("plan.json").path)
    #expect(plan.frameworks.map(\.name) == ["CoreC"])
    #expect(plan.settings["GCC_PREPROCESSOR_DEFINITIONS"]?.list.contains("MINI_CARTHAGE=1")
      == true)
    let entries = try FileManager.default.contentsOfDirectory(atPath: cache)
      .filter { FileManager.default.fileExists(atPath: "\(cache)/\($0)/CoreC.xcframework") }
    #expect(entries.count == 2)

    // The staged distribution: both CoreC copies replaced, the notices and umbrella added.
    let staged = buildDir.appendingPathComponent("dist/Mini")
    let rebuiltBinary = try contentHash(buildDir.path
      + "/xcframeworks/CoreC.xcframework/ios-arm64/CoreC.framework/CoreC")
    for folder in ["Mini", "MiniCore"] {
      #expect(try contentHash(staged.path
          + "/\(folder)/CoreC.xcframework/ios-arm64/CoreC.framework/CoreC") == rebuiltBinary)
    }
    #expect(FileManager.default.fileExists(atPath: staged.path
        + "/MiniCore/CoreC.xcframework/NOTICES"))
    let umbrellaPlist = try #require(NSDictionary(contentsOfFile: staged.path
        + "/Mini/MiniUmbrella.framework/Info.plist"))
    #expect(umbrellaPlist["MinimumOSVersion"] as? String == "15.0")
    #expect(umbrellaPlist["CFBundleShortVersionString"] as? String == "1.2.3")
    // The input is unchanged.
    let input = workDir.appendingPathComponent("dist/Mini").path
    #expect(!FileManager.default.fileExists(atPath: input + "/MiniCore/CoreC.xcframework/NOTICES"))
    #expect(!FileManager.default.fileExists(atPath: input + "/Mini/MiniUmbrella.framework"))

    // The archives and binary specs.
    let output = workDir.appendingPathComponent("carthage/1.2.3")
    let folders = ["Mini", "MiniCore", "MiniHeaders", "MiniPrebuilt"]
    let archives = try folders
      .map { try carthageArchiveName(of: staged.appendingPathComponent($0)) }
    #expect(try FileManager.default.contentsOfDirectory(atPath: output.path).sorted()
      == (archives + folders.map { "\($0)Binary.json" }).sorted())
    #expect(try String(contentsOf: output.appendingPathComponent("MiniBinary.json"),
                       encoding: .utf8) == """
      {
        "1.0.0": "https://example.com/1.0.0/Mini-old.zip",
        "1.2.3": "https://example.com/1.2.3/\(archives[0])"
      }

      """)
    let mini = try await shell("zipinfo", ["-1", output.appendingPathComponent(archives[0]).path])
    #expect(mini.contains("Mini/MiniUmbrella.framework/Modules/module.modulemap"))
    #expect(mini.contains("Mini/CoreC.xcframework/Info.plist"))
    let miniCore = try await shell("zipinfo",
                                   ["-1", output.appendingPathComponent(archives[1]).path])
    #expect(miniCore.split(separator: "\n").contains("MiniCore/CoreC.xcframework/NOTICES"))

    // Again: CoreC comes from the cache, and the archives are the same.
    _ = try await collectingWarnings { try await carthage.run() }
    #expect(!FileManager.default.fileExists(atPath: buildDir.path + "/archives"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: output.path).sorted()
      == (archives + folders.map { "\($0)Binary.json" }).sorted())
  }
}
