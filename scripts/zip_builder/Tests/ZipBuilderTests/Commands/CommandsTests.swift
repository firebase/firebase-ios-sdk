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

struct CommandsTests {
  @Test func commandName() {
    #expect(ZipBuilderCommand.configuration.commandName == "zip-builder")
  }

  @Test func hasOneSubcommandPerStage() {
    let names = ZipBuilderCommand.configuration.subcommands.map { $0._commandName }
    #expect(names == ["plan", "project", "build", "package", "release", "verify", "diff"])
  }

  @Test func sharedOptionDefaults() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot(["plan"]) as? PlanCommand)
    #expect(command.options.packagePath == ".")
    #expect(command.options.workDir == "build")
    #expect(command.options.product == nil)
    #expect(command.options.version == nil)
    #expect(command.options.configPath.hasSuffix("/zip_builder.jsonc"))
  }

  @Test func sharedOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "plan", "--package-path", "/repo", "--work-dir", "out", "--product", "FirebaseAuth",
      "--version", "13.0.0",
    ]) as? PlanCommand)
    #expect(command.options.configPath == "/repo/zip_builder.jsonc")
    #expect(command.options.workDir == "out")
    #expect(command.options.product == "FirebaseAuth")
    #expect(command.options.version == "13.0.0")

    let explicit = try #require(try ZipBuilderCommand.parseAsRoot([
      "plan", "--package-path", "/repo", "--config", "other.json",
    ]) as? PlanCommand)
    #expect(explicit.options.configPath == "other.json")
  }

  @Test func projectOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "project", "--plan", "build/plan.json",
    ]) as? ProjectCommand)
    #expect(command.plan == "build/plan.json")
  }

  @Test func buildOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "build", "--plan", "p.json", "--project", "F.xcodeproj", "--cache-dir", "/cache",
      "--product", "FirebaseAuth",
    ]) as? BuildCommand)
    #expect(command.plan == "p.json")
    #expect(command.project == "F.xcodeproj")
    #expect(command.cacheDir == "/cache")
    #expect(command.options.product == "FirebaseAuth")

    let defaults = try #require(try ZipBuilderCommand.parseAsRoot(["build"]) as? BuildCommand)
    #expect(defaults.plan == nil && defaults.project == nil)
    #expect(defaults.cacheDir.hasSuffix("/Library/Caches/zip-builder/frameworks"))
  }

  @Test func packageOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "package", "--plan", "p.json", "--xcframeworks", "build/xcframeworks", "--sign", "Dev ID",
      "--cache-dir", "/cache",
    ]) as? PackageCommand)
    #expect(command.plan == "p.json")
    #expect(command.xcframeworks == "build/xcframeworks")
    #expect(command.sign == "Dev ID")
    #expect(command.cacheDir == "/cache")

    let defaults = try #require(try ZipBuilderCommand.parseAsRoot(["package"]) as? PackageCommand)
    #expect(defaults.plan == nil && defaults.xcframeworks == nil && defaults.sign == nil)
    #expect(defaults.cacheDir == FrameworkCache.defaultDirectory)
  }

  @Test func releaseOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "release", "--sign", "-", "--cache-dir", "/cache", "--version", "1.2.3",
      "--package-path", "/repo", "--work-dir", "out",
    ]) as? ReleaseCommand)
    #expect(command.sign == "-")
    #expect(command.cacheDir == "/cache")
    #expect(command.options.version == "1.2.3")
    #expect(command.options.packagePath == "/repo")
    #expect(command.options.workDir == "out")

    let defaults = try #require(try ZipBuilderCommand.parseAsRoot(["release"]) as? ReleaseCommand)
    #expect(defaults.sign == nil)
    #expect(defaults.cacheDir == FrameworkCache.defaultDirectory)
    #expect(throws: (any Error).self) {
      try ZipBuilderCommand.parseAsRoot(["release", "--plan", "p"])
    }
  }

  @Test func packageNeedsAVersionForTheArchiveName() async throws {
    let config = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-config-\(UUID().uuidString).json")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" } }"#.utf8)
      .write(to: config)
    defer { try? FileManager.default.removeItem(at: config) }
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "package", "--config", config.path, "--plan", "p.json", "--xcframeworks", "x",
    ]) as? PackageCommand)
    let error = await #expect(throws: ZipBuilderError.self) { try await command.run() }
    #expect(error?.description.contains("No release version") == true)
  }

  /// `release` checks the version before planning, so it fails before loading the package.
  @Test func releaseNeedsAVersionBeforePlanning() async throws {
    let config = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-config-\(UUID().uuidString).json")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "com.example" } }"#.utf8)
      .write(to: config)
    defer { try? FileManager.default.removeItem(at: config) }
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "release", "--config", config.path, "--package-path", "/nonexistent/package",
    ]) as? ReleaseCommand)
    let error = await #expect(throws: ZipBuilderError.self) { try await command.run() }
    #expect(error?.description.contains("No release version") == true)
  }

  @Test func verifyArguments() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "Firebase.zip",
    ]) as? VerifyCommand)
    #expect(command.distribution == "Firebase.zip")
    #expect(throws: (any Error).self) { try ZipBuilderCommand.parseAsRoot(["verify"]) }
  }

  @Test func diffArguments() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff", "old.zip", "new", "--format", "markdown", "--output", "report.md",
    ]) as? DiffCommand)
    #expect(command.baseline == "old.zip")
    #expect(command.candidate == "new")
    #expect(command.format == .markdown)
    #expect(command.output == "report.md")

    let defaults = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff",
      "a",
      "b",
    ]) as? DiffCommand)
    #expect(defaults.format == .text)
    #expect(throws: (any Error).self) {
      try ZipBuilderCommand.parseAsRoot(["diff", "a", "b", "--format", "html"])
    }
  }

  @Test func versionFlagTakesPrecedence() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data("""
    { "release": { "name": "Mini", "bundleIdPrefix": "com.example", "version": "1.0.0" } }
    """.utf8))
    let withFlag = try #require(try ZipBuilderCommand.parseAsRoot([
      "plan", "--version", "2.0.0",
    ]) as? PlanCommand)
    #expect(try withFlag.options.releaseVersion(config) == "2.0.0")

    let withoutFlag = try #require(try ZipBuilderCommand.parseAsRoot(["plan"]) as? PlanCommand)
    #expect(try withoutFlag.options.releaseVersion(config) == "1.0.0")
  }

  @Test func linkageFlagTakesPrecedence() throws {
    let config = try MiniPackage.config(#""build": { "linkage": "dynamic" }"#)
    let command = { (arguments: [String]) throws -> SharedOptions in
      try #require(try ZipBuilderCommand.parseAsRoot(["plan"] + arguments) as? PlanCommand)
        .options
    }
    #expect(try command([]).linkage == nil)
    #expect(try command([]).releaseLinkage(config) == .dynamic)
    #expect(try command([]).releaseLinkage(MiniPackage.config()) == .static)
    #expect(try command(["--linkage", "static"]).releaseLinkage(config) == .static)
    #expect(try command(["--linkage", "dynamic"]).releaseLinkage(MiniPackage.config())
      == .dynamic)
    #expect(throws: (any Error).self) { try command(["--linkage", "shared"]) }
  }

  @Test func missingVersionIsAnError() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data("""
    { "release": { "name": "Mini", "bundleIdPrefix": "com.example" } }
    """.utf8))
    let command = try #require(try ZipBuilderCommand.parseAsRoot(["plan"]) as? PlanCommand)
    let error = #expect(throws: ZipBuilderError.self) {
      try command.options.releaseVersion(config)
    }
    #expect(error?.description.contains("--version") == true)
  }

  @Test func verifyRejectsAMissingDistribution() async throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "/nonexistent/Firebase",
    ]) as? VerifyCommand)
    let error = await #expect(throws: ZipBuilderError.self) { try await command.run() }
    #expect(error?.description.contains("Not a distribution") == true)
  }

  /// `project`, `build` and `package` all load `--plan` through `loadOrMakePlan`.
  @Test func productAndLinkageAreIgnoredWithAPlan() async throws {
    let planFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-plan-\(UUID().uuidString).json")
    try SyntheticPackage.plan.json().write(to: planFile)
    defer { try? FileManager.default.removeItem(at: planFile) }
    let config = try MiniPackage.config()
    let ignored = [
      "--product": "--product is ignored with --plan: the plan already holds its frameworks.",
      "--linkage": "--linkage is ignored with --plan: the plan already holds each framework's "
        + "linkage.",
    ]
    for arguments in [["--product", "A"], ["--linkage", "dynamic"], []] {
      let command = try #require(try ZipBuilderCommand.parseAsRoot([
        "project", "--plan", planFile.path,
      ] + arguments) as? ProjectCommand)
      let (plan, warnings) = try await collectingWarnings {
        try await command.options.loadOrMakePlan(command.plan, config)
      }
      #expect(plan == SyntheticPackage.plan)
      #expect(warnings == arguments.prefix(1).compactMap { ignored[$0] })
    }
  }

  @Test func withoutDependenciesNeedsAProduct() throws {
    let error = #expect(throws: (any Error).self) {
      try ZipBuilderCommand.parseAsRoot(["release", "--without-dependencies"])
    }
    #expect(try ZipBuilderCommand.message(for: #require(error)) == """
    --without-dependencies needs --product; to ship every product without its dependencies, \
    set products.withoutDependencies in the config.
    """)
  }

  /// Like `--linkage`, the flag goes into the config planning and `customize` get.
  @Test func withoutDependenciesSetsTheConfig() throws {
    let options = { (arguments: [String]) throws -> SharedOptions in
      try #require(try ZipBuilderCommand.parseAsRoot(["plan"] + arguments) as? PlanCommand)
        .options
    }
    let flagged = try options(["--product", "Mini", "--without-dependencies"])
    #expect(flagged.withoutDependencies)
    #expect(try flagged.applyingFlags(to: MiniPackage.config()).products.withoutDependencies)
    let unflagged = try options(["--product", "Mini"])
    #expect(try !unflagged.applyingFlags(to: MiniPackage.config()).products.withoutDependencies)
    // Without the flag, the config's value stands.
    let configured = try MiniPackage.config(#""products": { "withoutDependencies": true }"#)
    #expect(try options([]).applyingFlags(to: configured).products.withoutDependencies)
  }

  @Test func withoutDependenciesIsIgnoredWithAPlan() async throws {
    let planFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-plan-\(UUID().uuidString).json")
    try SyntheticPackage.plan.json().write(to: planFile)
    defer { try? FileManager.default.removeItem(at: planFile) }
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "build", "--plan", planFile.path, "--product", "A", "--without-dependencies",
    ]) as? BuildCommand)
    let (plan, warnings) = try await collectingWarnings {
      try await command.options.loadOrMakePlan(command.plan, MiniPackage.config())
    }
    #expect(plan == SyntheticPackage.plan)
    #expect(warnings == [
      "--product is ignored with --plan: the plan already holds its frameworks.",
      "--without-dependencies is ignored with --plan: the plan already holds its folders.",
    ])
  }
}
