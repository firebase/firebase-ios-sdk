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

struct VerifyTests {
  private func xcframework(_ slices: [FakeSlice]) async throws -> XCFramework {
    let fake = try FakeDistribution()
    try fake.addXCFramework("Core", in: "A", slices: slices)
    return try #require(try await fake.read().xcframeworks.first)
  }

  @Test func completeSlicesPass() async throws {
    let catalyst = FakeSlice(identifier: "ios-arm64_x86_64-maccatalyst", variant: "maccatalyst")
    let macos = FakeSlice(identifier: "macos-arm64_x86_64", platform: "macos")
    let item = try await sliceCompleteness(xcframework([.device, .simulator, catalyst, macos]))
    #expect(item == CheckItem(name: "A/Core", status: .passed))
    // Catalyst and macOS have no simulator.
    #expect(try await sliceCompleteness(xcframework([catalyst, macos])).status == .passed)
  }

  @Test func aDeviceSliceWithoutASimulatorFails() async throws {
    let tvos = FakeSlice(identifier: "tvos-arm64", platform: "tvos")
    let item = try await sliceCompleteness(xcframework([.device, .simulator, tvos]))
    #expect(item.status == .failed)
    #expect(item.detail == "tvos has a device slice but no simulator")
  }

  @Test func aSimulatorSliceWithoutADeviceFails() async throws {
    let item = try await sliceCompleteness(xcframework([.simulator]))
    #expect(item.detail == "ios has a simulator slice but no device")
  }

  @Test func aSliceMissingFromDiskFails() async throws {
    var missing = FakeSlice.simulator
    missing.createsDirectory = false
    let item = try await sliceCompleteness(xcframework([.device, missing]))
    #expect(item.detail == "ios-arm64_x86_64-simulator is missing")
  }

  @Test func noSlicesFails() async throws {
    let item = try await sliceCompleteness(xcframework([]))
    #expect(item.detail == "no slices in Info.plist")
  }

  @Test func linkArgumentsUseEveryIOSDeviceSlice() async throws {
    let fake = try FakeDistribution()
    try fake.addXCFramework("Core", in: "Base")
    try fake.addXCFramework("MacOnly", in: "Base", slices: [
      FakeSlice(identifier: "macos-arm64", platform: "macos"),
    ])
    let distribution = try await fake.read()
    let arguments = linkArguments(distribution.xcframeworks, main: "/s/main.swift", sdk: "/sdk",
                                  output: "/s/out")
    let slice = distribution.root + "/Base/Core.xcframework/ios-arm64"
    #expect(arguments == [
      "swiftc", "-sdk", "/sdk", "-target", verifyTarget, "/s/main.swift", "-o", "/s/out",
      "-F", slice, "-framework", "Core", "-Xlinker", "-ObjC", "-lc++", "-lsqlite3", "-lz",
    ])
  }

  @Test func importArgumentsTypecheckOneFile() async throws {
    let fake = try FakeDistribution()
    try fake.addXCFramework("Core", in: "A")
    try fake.addXCFramework("Core", in: "B")
    try fake.addXCFramework("Other", in: "B")
    let paths = try await frameworkSearchPaths(fake.read().xcframeworks)
    #expect(paths == ["-F", fake.root + "/A/Core.xcframework/ios-arm64",
                      "-F", fake.root + "/B/Core.xcframework/ios-arm64",
                      "-F", fake.root + "/B/Other.xcframework/ios-arm64"])

    #expect(swiftImportArguments("t.swift", sdk: "/sdk", searchPaths: ["-F", "x"], cache: "/mc")
      == ["swiftc", "-typecheck", "-sdk", "/sdk", "-target", verifyTarget,
          "-module-cache-path", "/mc", "-F", "x", "t.swift"])
    #expect(objcImportArguments("t.m", sdk: "/sdk", searchPaths: ["-F", "x"], cache: "/mc")
      == ["clang", "-fsyntax-only", "-fmodules", "-fcxx-modules", "-x", "objective-c",
          "-isysroot", "/sdk", "-target", verifyTarget, "-fmodules-cache-path=/mc",
          "-F", "x", "t.m"])
  }

  /// The import check imports the module the module map declares, which isn't always the
  /// framework's name (a hyphen becomes `_`).
  @Test func moduleNamesComeFromTheModuleMap() async throws {
    let fake = try FakeDistribution()
    var slice = FakeSlice.device
    slice.moduleMap = """
    // A comment: module Wrong
    framework module Mini_Extras [system] {
      umbrella header "Mini-Extras.h"
      module * { export * }
    }
    module Mini_Extras.Swift { header "Mini_Extras-Swift.h" }
    """
    try fake.addXCFramework("Mini-Extras", in: "A", slices: [slice])
    let read = try #require(try await fake.read().xcframeworks.first?.iOSDeviceSlice)
    #expect(declaredModuleName(of: read) == "Mini_Extras")
    slice.moduleMap = "// nothing\n"
    try fake.addXCFramework("Empty", in: "B", slices: [slice])
    let empty = try #require(try await fake.read().xcframeworks.last?.iOSDeviceSlice)
    #expect(declaredModuleName(of: empty) == nil)
  }

  @Test func parsesUndefinedSymbols() {
    let output = """
    Undefined symbols for architecture arm64:
      "_OBJC_CLASS_$_GULAppEnvironmentUtil", referenced from:
           in FirebaseCore[3](FIRApp.o)
      "_deflate", referenced from:
           in FirebaseCore[3](FIRApp.o)
      "_deflate", referenced from:
           in FirebaseCore[4](FIROptions.o)
    ld: symbol(s) not found for architecture arm64
    """
    #expect(undefinedSymbols(in: output) == ["_OBJC_CLASS_$_GULAppEnvironmentUtil", "_deflate"])
  }

  /// Only the quoted text at the start of a line is a symbol; other lines are skipped.
  @Test func undefinedSymbolsSkipOtherLines() {
    let output = """
    ld: warning: "_notASymbol" is quoted mid-line

      "_unterminated, referenced from:
      ""
      "_kept" with anything after it
    """
    #expect(undefinedSymbols(in: output) == ["", "_kept"])
    #expect(undefinedSymbols(in: "") == [])
  }

  /// Every declaration shape clang writes gives its module's name, whatever the spacing.
  @Test(arguments: [
    ("module Core {", "Core"),
    ("  framework module Core [system] [extern_c] {", "Core"),
    ("explicit module Core.Private {", "Core"),
    ("explicit framework module Core", "Core"),
    ("framework\tmodule   Core{", "Core"),
    ("module Core{ header \"Core.h\" }", "Core"),
  ])
  func moduleNameDeclarationShapes(line: String, expected: String) {
    #expect(declaredModuleName(of: slice(moduleMap: line)) == expected)
  }

  /// Comments, quoted text, wildcard submodules and other keywords don't declare a module.
  @Test(arguments: [
    "// module Commented",
    "header \"module Quoted.h\"",
    "module * { export * }",
    "submodule Core {",
    "umbrella header \"Core.h\"",
    "",
  ])
  func linesThatDeclareNoModule(line: String) {
    #expect(declaredModuleName(of: slice(moduleMap: line)) == nil)
  }

  @Test func theFirstDeclarationWins() {
    let moduleMap = "// header\r\nmodule First {\r\n}\r\nmodule Second {\r\n}\r\n"
    #expect(declaredModuleName(of: slice(moduleMap: moduleMap)) == "First")
    #expect(declaredModuleName(of: slice(moduleMap: nil)) == nil)
  }

  private func slice(moduleMap: String?) -> Slice {
    Slice(identifier: "ios-arm64", platform: "ios", architectures: ["arm64"],
          libraryPath: "/x/Core.framework", binaryPath: "/x/Core.framework/Core", exists: true,
          binaryKind: "static", headers: [], privateHeaders: [], modules: [],
          moduleMap: moduleMap, hasSwiftInterface: false, infoPlist: [:], resourceBundles: [])
  }

  /// Undefined symbols explain a failed link best; at most 8 are named.
  @Test func linkFailuresNameUndefinedSymbols() {
    let symbols = (0 ..< 10).map { "_symbol\($0)" }
    let errors = "Undefined symbols for architecture arm64:\n"
      + symbols.map { "  \"\($0)\", referenced from:\n      in Core.o" }.joined(separator: "\n")
      + "\nld: symbol(s) not found for architecture arm64\n"
    let result = ToolResult(status: 1, standardOutput: "", standardError: errors)
    #expect(linkFailure(result)
      == "10 undefined symbols: " + symbols.prefix(8).joined(separator: ", "))
  }

  /// Without undefined symbols, a failure is the text after the first `error:`, standard error
  /// first; without one, the first line.
  @Test func toolFailuresShowTheFirstError() {
    let both = ToolResult(status: 1, standardOutput: "b.swift:1: error: from output\n",
                          standardError: "warning: noise\na.swift:2: error:  from errors \n")
    #expect(linkFailure(both) == "from errors")
    let outputOnly = ToolResult(status: 1, standardOutput: "x\nt.m:1:9: error: no module\n",
                                standardError: "")
    #expect(linkFailure(outputOnly) == "no module")
    let noErrorLine = ToolResult(status: 1, standardOutput: "", standardError: "it broke\nmore\n")
    #expect(linkFailure(noErrorLine) == "it broke")
    #expect(linkFailure(ToolResult(status: 1, standardOutput: "", standardError: "")) == "")
  }

  @Test func importFailuresNameTheLanguage() {
    let failed = ToolResult(status: 1, standardOutput: "",
                            standardError: "t.swift:1:8: error: no such module 'Core'\n")
    #expect(importFailure("Swift", failed) == "Swift: no such module 'Core'")
    let passed = ToolResult(status: 0, standardOutput: "", standardError: "error: ignored")
    #expect(importFailure("Objective-C", passed) == nil)
  }

  @Test func signaturesAreSkippedOrRequired() async throws {
    let fake = try FakeDistribution()
    let signed = try fake.addXCFramework("Signed", in: "A")
    try fake.addXCFramework("Unsigned", in: "A")
    try await shell("codesign", ["--force", "--sign", "-", signed])
    let distribution = try await fake.read()

    let items = try await signatureCheck(distribution, requireSignatures: false)
    #expect(items == [CheckItem(name: "A/Signed", status: .passed, detail: "ad-hoc"),
                      CheckItem(name: "A/Unsigned", status: .skipped, detail: "not signed")])
    let required = try await signatureCheck(distribution, requireSignatures: true)
    #expect(required[1].status == .failed)

    // A changed file breaks the signature.
    try fake.addFile("A/Signed.xcframework/ios-arm64/Signed.framework/Headers/Core.h", "changed")
    let broken = try await signatureCheck(distribution, requireSignatures: false)
    #expect(broken[0].status == .failed)
  }

  @Test func rendersMarksPerCheckAndItem() {
    let checks = [
      Check(title: "Links", items: [CheckItem(name: "A", status: .passed),
                                    CheckItem(name: "B", status: .skipped, detail: "why")]),
      Check(title: "Signs", items: [CheckItem(name: "C", status: .failed, detail: "bad")]),
    ]
    #expect(renderVerification(checks, of: "/dist") == """
    Verifying /dist

    ✓ 1. Links: 2 checked, 0 failed, 1 skipped
      ✓ A
      – B: why

    ✗ 2. Signs: 1 checked, 1 failed, 0 skipped
      ✗ C: bad

    ✗ Verification failed.
    """)
  }

  @Test func commandOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "dist", "--config", "c.json", "--require-signatures",
    ]) as? VerifyCommand)
    #expect(command.config == "c.json")
    #expect(command.requireSignatures)
    let defaults = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify",
      "dist",
    ]) as? VerifyCommand)
    #expect(defaults.config == nil)
    #expect(!defaults.requireSignatures)
  }

  @Test func readsTheBaseFolderAndSkippedImportsFromTheConfig() throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-verify-\(UUID().uuidString).json").path
    defer { try? FileManager.default.removeItem(atPath: path) }
    try """
    { "release": { "name": "Mini", "bundleIdPrefix": "com.example" },
      "products": { "base": { "product": "Core", "frameworks": [] } },
      "verify": { "skipImports": ["absl"] } }
    """.write(toFile: path, atomically: true, encoding: .utf8)
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "dist", "--config", path,
    ]) as? VerifyCommand)
    let config = try #require(try command.loadConfig())
    #expect(config.products.base?.product == "Core")
    #expect(config.verify.skipImports == ["absl"])

    let missing = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "dist", "--config", "/nonexistent.json",
    ]) as? VerifyCommand)
    #expect(throws: ZipBuilderError.self) { try missing.loadConfig() }
  }

  /// `verifyAndReport` passes the config's base folder on and says whether every check passed.
  /// A tvOS-only framework has no iOS device slice, so nothing is linked or compiled.
  @Test func verifyAndReportUsesTheConfigAndReturnsWhetherItPassed() async throws {
    let fake = try FakeDistribution()
    try fake.addXCFramework("TV", in: "A", slices: [
      FakeSlice(identifier: "tvos-arm64", platform: "tvos"),
      FakeSlice(identifier: "tvos-arm64_x86_64-simulator", platform: "tvos",
                variant: "simulator"),
    ])
    let distribution = try await fake.read()
    let config = try MiniPackage.config(#""products": { "base": { "product": "Missing", "#
      + #""frameworks": [] } }"#)

    let (passed, warnings) = try await collectingWarnings {
      try await verifyAndReport(distribution, at: fake.root, config: config,
                                requireSignatures: false)
    }
    #expect(passed)
    #expect(warnings == ["No base folder `Missing`; linking every folder on its own."])
    // Unsigned, so requiring signatures fails; without a config nothing is linked with a base.
    let signedOnly = try await verifyAndReport(distribution, at: fake.root, config: nil,
                                               requireSignatures: true)
    #expect(!signedOnly)
  }
}
