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

/// SyntheticPackage on disk with license files, its plan in `plan.json` (A, B and Bin ship; A
/// and B share `LICENSE`), and a config file.
private struct NoticesFixture {
  let package: SyntheticPackage
  let plan: Plan
  let planPath: Path
  let configPath: Path

  /// `notices` is the `zip.notices` value, or nil for none.
  init(notices: String? = #"{ "atBuildTime": false }"#) throws {
    package = try SyntheticPackage()
    try package.write("LICENSE", "\nApache\n")
    try package.write("Bin/LICENSE", "Vendor\n")
    var plan = SyntheticPackage.plan
    plan.frameworks[0].licenses = ["LICENSE"] // B
    plan.frameworks[1].licenses = ["LICENSE"] // A
    plan.binaries[0].licenses = ["Bin/LICENSE"]
    plan.folders = [Folder(name: "Base", frameworks: ["A", "Bin"], files: []),
                    Folder(name: "Other", frameworks: ["B"], files: [])]
    self.plan = plan
    planPath = package.root.appendingPathComponent("plan.json").path
    try plan.json().write(to: URL(fileURLWithPath: planPath))
    configPath = package.root.appendingPathComponent("zip_builder.json").path
    let zip = notices.map { #", "zip": { "notices": \#($0) }"# } ?? ""
    try package.write("zip_builder.json",
                      #"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" }\#(zip) }"#)
  }

  func path(_ name: String) -> Path {
    package.root.appendingPathComponent(name).path
  }

  /// The `notices` command for this fixture's plan and config, plus `arguments`.
  func command(_ arguments: [String] = []) throws -> NoticesCommand {
    try #require(try ZipBuilderCommand.parseAsRoot([
      "notices", "--plan", planPath, "--package-path", package.root.path, "--config", configPath,
    ] + arguments) as? NoticesCommand)
  }
}

/// What `body` writes to standard output. Logs go to standard error, so they aren't included.
private func capturingStandardOutput(_ body: () async throws -> Void) async throws -> String {
  let file = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-stdout-\(UUID().uuidString)")
  FileManager.default.createFile(atPath: file.path, contents: nil)
  defer { try? FileManager.default.removeItem(at: file) }
  let handle = try FileHandle(forWritingTo: file)
  fflush(nil)
  let saved = dup(STDOUT_FILENO)
  dup2(handle.fileDescriptor, STDOUT_FILENO)
  do {
    try await body()
  } catch {
    fflush(nil)
    dup2(saved, STDOUT_FILENO)
    close(saved)
    throw error
  }
  fflush(nil)
  dup2(saved, STDOUT_FILENO)
  close(saved)
  try handle.close()
  return try String(contentsOf: file, encoding: .utf8)
}

struct NoticesCommandTests {
  private let expected = "A\nB\n\nApache\n\nBin\n\nVendor\n"

  @Test func parsesItsOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "notices", "--plan", "p.json", "--output", "CoreOnly/licenses/NOTICES", "--product", "A",
    ]) as? NoticesCommand)
    #expect(command.plan == "p.json")
    #expect(command.output == "CoreOnly/licenses/NOTICES")
    #expect(command.options.product == "A")
    let defaults = try #require(try ZipBuilderCommand.parseAsRoot([
      "notices",
    ]) as? NoticesCommand)
    #expect(defaults.plan == nil && defaults.output == nil)
  }

  /// `atBuildTime: false` only stops `makeZip`; the command writes the file regardless.
  @Test func writesTheFile() async throws {
    let fixture = try NoticesFixture()
    let output = fixture.path("NOTICES")
    try await fixture.command(["--output", output]).run()
    #expect(try String(contentsOfFile: output, encoding: .utf8) == expected)
  }

  @Test func printsToStandardOutputWithoutAnOutputFile() async throws {
    let fixture = try NoticesFixture()
    let command = try fixture.command()
    let printed = try await capturingStandardOutput { try await command.run() }
    // Other tests may print while this one captures, so look for the text rather than compare.
    #expect(printed.contains(expected))
    #expect(!FileManager.default.fileExists(atPath: fixture.path("NOTICES")))
  }

  @Test func needsZipNotices() async throws {
    let fixture = try NoticesFixture(notices: nil)
    let output = fixture.path("NOTICES")
    let error = await #expect(throws: ZipBuilderError.self) {
      try await fixture.command(["--output", output]).run()
    }
    #expect(error?.description == "No zip.notices in \(fixture.configPath): "
      + "add it to generate the license notices.")
    #expect(!FileManager.default.fileExists(atPath: output))
  }

  /// The checked-in file a release copies matches what `makeZip` would generate.
  @Test func matchesWhatMakeZipWrites() async throws {
    let fixture = try NoticesFixture()
    let output = fixture.path("NOTICES")
    try await fixture.command(["--output", output]).run()

    let distribution = try FakeDistribution()
    for name in ["A", "B", "Bin"] {
      try distribution.addXCFramework(name, in: "xcframeworks")
    }
    let config = try JSONDecoder().decode(Config.self, from: Data(#"""
    { "release": { "name": "Mini", "bundleIdPrefix": "com.example" }, "zip": { "notices": {} } }
    """#.utf8))
    let workDir = distribution.root + "/work"
    _ = try await makeZip(xcframeworks: distribution.root + "/xcframeworks", plan: fixture.plan,
                          config: config, packageRoot: fixture.package.root.path,
                          workDir: workDir, signingIdentity: nil, version: "1.0.0")
    let generated = distributionRoot(workDir: workDir, config: config)
      .appendingPathComponent("NOTICES")
    #expect(try Data(contentsOf: generated) == Data(contentsOf: URL(fileURLWithPath: output)))
  }

  /// Without `--plan`, it plans the package; `--product` limits the notices to that product.
  @Test func plansThePackageForAProduct() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/notices/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    // A copy, so loading the package doesn't leave `.build` in the fixture.
    let package = root.appendingPathComponent("MiniPackage")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(atPath: MiniPackage.path, toPath: package.path)
    let config = root.appendingPathComponent("zip_builder.json")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" }, "#
      .appending(#""zip": { "notices": {} } }"#).utf8).write(to: config)
    let output = root.appendingPathComponent("NOTICES").path
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "notices", "--package-path", package.path, "--config", config.path, "--version", "1.0.0",
      "--product", "MiniHeaders", "--output", output,
    ]) as? NoticesCommand)
    try await command.run()
    #expect(try String(contentsOfFile: output, encoding: .utf8)
      == "HeaderOnly\n\nMini test license, for the targets under Sources.\n")
  }
}
