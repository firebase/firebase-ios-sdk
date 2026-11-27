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
import RegexBuilder

/// One `verify` check and the outcome for each item it looked at.
struct Check: Sendable {
  var title: String
  var items: [CheckItem]
  var failed: Bool {
    items.contains { $0.status == .failed }
  }
}

struct CheckItem: Sendable, Equatable {
  enum Status: Sendable { case passed, failed, skipped }
  var name: String
  var status: Status
  var detail = ""
}

/// The target the link and import checks compile for: iOS devices only, since that's the one
/// platform every Firebase folder ships, and the SDK every Xcode has.
let verifyTarget = "arm64-apple-ios15.0"

/// The four behavioral checks of `verify`. `baseFolder` is linked with every folder
/// (`products.base.product`; nil links each folder alone), `skippedImports` aren't
/// import-checked (`verify.skipImports`), and `requireSignatures` fails unsigned `.xcframework`s
/// instead of skipping them. `dependencies` are `.xcframework`s the distribution needs but doesn't
/// ship (`products.withoutDependencies`): they're linked with every folder and searched for
/// imports, but not checked themselves; ones the distribution ships are ignored.
/// See docs/how-it-works.md#verify.
func verify(_ distribution: Distribution, baseFolder: String?, skippedImports: Set<String>,
            requireSignatures: Bool, dependencies: [XCFramework] = []) async throws -> [Check] {
  let shipped = Set(distribution.xcframeworks.map(\.name))
  let dependencies = dependencies.filter { !shipped.contains($0.name) }
  let sdk = try await shell("xcrun", ["--sdk", "iphoneos", "--show-sdk-path"])
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let scratch = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-verify-\(UUID().uuidString)").path
  try FileManager.default.createDirectory(atPath: scratch, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(atPath: scratch) }

  return try await [
    Check(title: linkCheckTitle(baseFolder: baseFolder, dependencyCount: dependencies.count),
          items: linkCheck(distribution, baseFolder: baseFolder, dependencies: dependencies,
                           sdk: sdk, scratch: scratch)),
    Check(title: "Every module imports from Swift and from Objective-C",
          items: importCheck(distribution, dependencies: dependencies, skipping: skippedImports,
                             sdk: sdk, scratch: scratch)),
    Check(title: "Every .xcframework has a slice for each of its platforms",
          items: distribution.xcframeworks.map(sliceCompleteness)),
    Check(title: "Every signature verifies",
          items: signatureCheck(distribution, requireSignatures: requireSignatures)),
  ]
}

/// Check 1's title, naming what every folder is linked with: e.g. "… (with Core)", or
/// "… (with Core and 3 dependencies)".
func linkCheckTitle(baseFolder: String?, dependencyCount: Int) -> String {
  var linkedWith: [String] = []
  if let baseFolder {
    linkedWith.append(baseFolder)
  }
  if dependencyCount > 0 {
    linkedWith.append(dependencyCount == 1 ? "1 dependency" : "\(dependencyCount) dependencies")
  }
  let title = "Every folder links into an app with -ObjC"
  return linkedWith.isEmpty ? title : title + " (with \(linkedWith.joined(separator: " and ")))"
}

/// Check 1: links each folder's iOS device slices, plus the base folder's and the dependencies',
/// into an executable.
private func linkCheck(_ distribution: Distribution, baseFolder: String?,
                       dependencies: [XCFramework], sdk: Path,
                       scratch: Path) async throws -> [CheckItem] {
  let base = distribution.folders.first { $0.name == baseFolder }
  if let baseFolder, base == nil {
    warn("No base folder `\(baseFolder)`; linking every folder on its own.")
  }
  let main = scratch + "/main.swift"
  try "print(\"ok\")\n".write(toFile: main, atomically: true, encoding: .utf8)

  let folders = distribution.folders.filter { !$0.xcframeworks.isEmpty }
  return try await concurrentMap(folders) { folder in
    guard folder.xcframeworks.contains(where: { $0.iOSDeviceSlice != nil }) else {
      return CheckItem(name: folder.name, status: .skipped, detail: "no iOS device slices")
    }
    // The base folder links on its own; every other folder links with the base folder.
    let frameworks = folder.name == baseFolder ? folder.xcframeworks
      : (base?.xcframeworks ?? []) + folder.xcframeworks
    let output = scratch + "/" + folder.name + ".out"
    let result = try await runTool("xcrun", linkArguments(frameworks + dependencies, main: main,
                                                          sdk: sdk, output: output))
    return result.status == 0 ? CheckItem(name: folder.name, status: .passed)
      : CheckItem(name: folder.name, status: .failed, detail: linkFailure(result))
  }
}

/// Why a link failed: its undefined symbols (the first 8, so the line stays readable) when that's
/// why, else its first error.
func linkFailure(_ result: ToolResult) -> String {
  let undefined = undefinedSymbols(in: result.standardError)
  guard !undefined.isEmpty else { return result.firstError }
  return "\(undefined.count) undefined symbols: " + undefined.prefix(8).joined(separator: ", ")
}

/// `swiftc` arguments that link `main` against the iOS device slice of every framework.
func linkArguments(_ frameworks: [XCFramework], main: Path, sdk: Path,
                   output: Path) -> [String] {
  var arguments = ["swiftc", "-sdk", sdk, "-target", verifyTarget, main, "-o", output]
  for slice in frameworks.compactMap(\.iOSDeviceSlice) {
    arguments += slice.isFramework
      ? ["-F", slice.libraryDirectory, "-framework", slice.libraryName]
      : [slice.libraryPath]
  }
  return arguments + ["-Xlinker", "-ObjC", "-lc++", "-lsqlite3", "-lz"]
}

/// Check 2: typechecks `import M` (Swift) and `@import M;` (Objective-C) for every module. The
/// dependencies are only searched, so the modules can import theirs.
private func importCheck(_ distribution: Distribution, dependencies: [XCFramework],
                         skipping skipped: Set<String>, sdk: Path,
                         scratch: Path) async throws -> [CheckItem] {
  let xcframeworks = distribution.xcframeworks.uniqued(by: \.name)
  let searchPaths = frameworkSearchPaths(distribution.xcframeworks + dependencies)
  let cache = scratch + "/ModuleCache"

  return try await concurrentMap(xcframeworks) { xcframework in
    guard !skipped.contains(xcframework.name) else {
      return CheckItem(
        name: xcframework.name,
        status: .skipped,
        detail: "listed in verify.skipImports"
      )
    }
    guard let slice = xcframework.iOSDeviceSlice else {
      return CheckItem(name: xcframework.name, status: .skipped, detail: "no iOS device slice")
    }
    // Without a module map, neither language can import it. That's a packaging bug, so it
    // fails; a vendor binary that really has no module belongs in `verify.skipImports`.
    guard slice.moduleMap != nil else {
      return CheckItem(name: xcframework.name, status: .failed, detail: "ships no module map")
    }
    guard let module = declaredModuleName(of: slice) else {
      return CheckItem(name: xcframework.name, status: .failed,
                       detail: "its module map declares no module")
    }
    let probeDirectory = scratch + "/imports/" + module
    try FileManager.default.createDirectory(atPath: probeDirectory,
                                            withIntermediateDirectories: true)
    let swiftFile = probeDirectory + "/t.swift", objcFile = probeDirectory + "/t.m"
    try "import \(module)\n".write(toFile: swiftFile, atomically: true, encoding: .utf8)
    try "@import \(module);\n".write(toFile: objcFile, atomically: true, encoding: .utf8)

    // One after the other: Swift, then Objective-C.
    let failures = try await [
      importFailure("Swift", runTool("xcrun", swiftImportArguments(
        swiftFile, sdk: sdk, searchPaths: searchPaths, cache: cache
      ))),
      importFailure("Objective-C", runTool("xcrun", objcImportArguments(
        objcFile, sdk: sdk, searchPaths: searchPaths, cache: cache
      ))),
    ].compactMap { $0 }
    return CheckItem(name: xcframework.name, status: failures.isEmpty ? .passed : .failed,
                     detail: failures.joined(separator: "; "))
  }
}

/// `<language>: <first error>` when the compiler failed to import the module, else nil.
func importFailure(_ language: String, _ result: ToolResult) -> String? {
  result.status == 0 ? nil : "\(language): " + result.firstError
}

func swiftImportArguments(_ file: Path, sdk: Path, searchPaths: [String],
                          cache: Path) -> [String] {
  ["swiftc", "-typecheck", "-sdk", sdk, "-target", verifyTarget, "-module-cache-path", cache]
    + searchPaths + [file]
}

func objcImportArguments(_ file: Path, sdk: Path, searchPaths: [String],
                         cache: Path) -> [String] {
  ["clang", "-fsyntax-only", "-fmodules", "-fcxx-modules", "-x", "objective-c",
   "-isysroot", sdk, "-target", verifyTarget, "-fmodules-cache-path=\(cache)"]
    + searchPaths + [file]
}

/// `-F <dir>` for the iOS device slice of every framework, in every folder.
func frameworkSearchPaths(_ xcframeworks: [XCFramework]) -> [String] {
  xcframeworks.compactMap(\.iOSDeviceSlice).map(\.libraryDirectory).uniqued()
    .flatMap { ["-F", $0] }
}

/// Check 3: each platform with a simulator has both a device and a simulator slice. Mac Catalyst
/// (a variant of `ios`) and macOS have no simulator.
func sliceCompleteness(_ xcframework: XCFramework) -> CheckItem {
  let name = xcframework.qualifiedName
  guard !xcframework.slices.isEmpty else {
    return CheckItem(name: name, status: .failed, detail: "no slices in Info.plist")
  }
  var problems = xcframework.slices.filter { !$0.exists }.map { "\($0.identifier) is missing" }
  for platform in Set(xcframework.slices.map(\.platform)).sorted() where platform != "macos" {
    let variants = Set(xcframework.slices.filter { $0.platform == platform }.map(\.variant))
    let device = variants.contains(nil), simulator = variants.contains("simulator")
    if device, !simulator {
      problems.append("\(platform) has a device slice but no simulator")
    }
    if simulator, !device {
      problems.append("\(platform) has a simulator slice but no device")
    }
  }
  return CheckItem(name: name, status: problems.isEmpty ? .passed : .failed,
                   detail: problems.joined(separator: "; "))
}

/// Check 4: `codesign --verify --strict` on every signed `.xcframework`.
func signatureCheck(_ distribution: Distribution,
                    requireSignatures: Bool) async throws -> [CheckItem] {
  try await concurrentMap(distribution.xcframeworks) { xcframework in
    let name = xcframework.qualifiedName
    guard xcframework.signature.isSigned else {
      return CheckItem(name: name, status: requireSignatures ? .failed : .skipped,
                       detail: "not signed")
    }
    let result = try await runTool("codesign", ["--verify", "--strict", xcframework.path])
    return result.status == 0
      ? CheckItem(name: name, status: .passed, detail: xcframework.signature.authority ?? "")
      : CheckItem(name: name, status: .failed, detail: firstLine(of: result.standardError))
  }
}

/// The quoted names that start lines in ld's output, sorted: the symbols of its "Undefined
/// symbols" list.
func undefinedSymbols(in output: String) -> [String] {
  Set(output.split(separator: "\n").compactMap { line -> String? in
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    // A line without a closing quote isn't a symbol.
    guard trimmed.hasPrefix("\""), trimmed.dropFirst().contains("\"") else { return nil }
    return String(trimmed.dropFirst().prefix { $0 != "\"" })
  }).sorted()
}

private extension ToolResult {
  /// The first compiler or linker error, from both streams.
  var firstError: String {
    firstErrorMessage(in: standardError + standardOutput)
  }
}

/// The text after `error:` on the first line that has one, else the first line.
private func firstErrorMessage(in output: String) -> String {
  for line in output.split(separator: "\n") {
    if let range = line.range(of: "error:") {
      return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
    }
  }
  return firstLine(of: output)
}

private func firstLine(of output: String) -> String {
  output.split(separator: "\n").first.map(String.init) ?? ""
}

/// The top-level module the slice's `Modules/module.modulemap` declares, which can differ from the
/// framework's name (`Mini-Extras` declares `Mini_Extras`); `nil` without one.
func declaredModuleName(of slice: Slice) -> String? {
  // `module Foo`, `framework module Foo [system] {`, `explicit module Foo`, …, matched after
  // `normalizedModuleMapLine` has removed comments and collapsed whitespace.
  let declaration = Regex {
    Optionally { "explicit " }
    Optionally { "framework " }
    "module "
    Capture { OneOrMore(.word) }
  }
  for line in slice.moduleMap?.components(separatedBy: .newlines) ?? [] {
    if let match = normalizedModuleMapLine(line).prefixMatch(of: declaration) {
      return String(match.1)
    }
  }
  return nil
}

private extension CheckItem.Status {
  var mark: String {
    switch self {
    case .passed: "✓"
    case .failed: "✗"
    case .skipped: "–"
    }
  }
}

/// The report: ✓ / ✗ / – per check and per item.
func renderVerification(_ checks: [Check], of root: Path) -> String {
  var lines = ["Verifying \(root)"]
  for (number, check) in zip(1..., checks) {
    let failed = check.items.count { $0.status == .failed }
    let skipped = check.items.count { $0.status == .skipped }
    lines += [
      "",
      "\((check.failed ? CheckItem.Status.failed : .passed).mark) \(number). \(check.title): "
        + "\(check.items.count) checked, \(failed) failed, \(skipped) skipped",
    ]
    for item in check.items {
      lines.append("  \(item.status.mark) \(item.name)"
        + (item.detail.isEmpty ? "" : ": \(item.detail)"))
    }
  }
  lines += [
    "",
    checks.contains(where: \.failed) ? "✗ Verification failed." : "✓ All checks passed.",
  ]
  return lines.joined(separator: "\n")
}
