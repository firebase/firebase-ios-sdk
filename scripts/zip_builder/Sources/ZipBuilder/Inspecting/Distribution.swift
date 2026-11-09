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

/// A finished distribution: loose root files plus folders of `.xcframework`s. Shared by `verify`
/// and `diff`.
struct Distribution: Sendable {
  var root: Path
  var files: [String] // loose files at the root, e.g. `Firebase.h`, `NOTICES`
  var folders: [DistributionFolder]
  var extractedDirectory: Path? // the temporary directory a zip was unpacked into

  var xcframeworks: [XCFramework] {
    folders.flatMap(\.xcframeworks)
  }

  /// Deletes the unpacked zip, if any.
  func removeExtracted() {
    if let extractedDirectory {
      try? FileManager.default.removeItem(atPath: extractedDirectory)
    }
  }
}

struct DistributionFolder: Sendable {
  var name: String
  var xcframeworks: [XCFramework]
  var files: [String] // anything that isn't an .xcframework, e.g. Crashlytics' `run`
}

struct XCFramework: Sendable {
  var name: String // without `.xcframework`
  var folder: String
  var path: Path
  var slices: [Slice]
  var signature: Signature

  /// `<folder>/<name>`, e.g. `FirebaseAnalytics/FirebaseCore`: which copy, when several folders
  /// hold one.
  var qualifiedName: String {
    folder + "/" + name
  }

  /// The iOS device slice, the one `verify` links and imports.
  var iOSDeviceSlice: Slice? {
    slices.first { $0.platform == "ios" && $0.variant == nil }
  }
}

/// `codesign -dvv` of an `.xcframework`. `authority` is the leaf certificate, or `ad-hoc`.
struct Signature: Sendable, Equatable {
  var isSigned: Bool
  var authority: String?
}

/// One entry of an `.xcframework`'s `AvailableLibraries`, plus what's inside it.
struct Slice: Sendable {
  var identifier: String // e.g. `ios-arm64_x86_64-simulator`
  var platform: String // `ios`, `macos`, `tvos`, `watchos`, `xros`
  var variant: String? // `simulator`, `maccatalyst`, or nil for a device
  var architectures: [String]
  var libraryPath: Path // absolute path of the `.framework` (or library)
  var binaryPath: Path
  var exists: Bool // the library is on disk
  var binaryKind: String // `static`, `dynamic`, `missing` or `unknown`
  var headers: [String]
  var privateHeaders: [String]
  var modules: [String]
  var moduleMap: String?
  var hasSwiftInterface: Bool
  var infoPlist: [String: String] // string and number values of the framework's Info.plist
  var resourceBundles: [String]

  /// Whether the library is a `.framework`, rather than a static or dynamic library.
  var isFramework: Bool {
    libraryPath.hasSuffix(".framework")
  }

  /// The library's name without its extension: `FirebaseCore` for `…/FirebaseCore.framework`,
  /// which `-framework` takes.
  var libraryName: String {
    URL(fileURLWithPath: libraryPath).deletingPathExtension().lastPathComponent
  }

  /// The directory holding the library: the `-F` search path for a framework.
  var libraryDirectory: Path {
    URL(fileURLWithPath: libraryPath).deletingLastPathComponent().path
  }
}

/// Reads a distribution directory, or unpacks a `.zip` into a temporary directory first. A
/// directory holding nothing but one directory without `.xcframework`s (the zip's top-level
/// `Firebase/`) is unwrapped.
func readDistribution(at path: Path) async throws -> Distribution {
  guard path.hasSuffix(".zip") else {
    return try await readDistributionDirectory(path, extractedDirectory: nil)
  }
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-\(UUID().uuidString)").path
  do {
    try await shell("ditto", ["-x", "-k", path, directory])
    return try await readDistributionDirectory(directory, extractedDirectory: directory)
  } catch {
    // A zip that isn't a readable distribution leaves nothing behind.
    try? FileManager.default.removeItem(atPath: directory)
    throw error
  }
}

/// Reads an unpacked distribution. `extractedDirectory` is the temporary directory a zip was
/// unpacked into, for `Distribution.removeExtracted()`.
private func readDistributionDirectory(_ directory: Path,
                                       extractedDirectory: Path?) async throws -> Distribution {
  guard isDirectory(directory) else { throw ZipBuilderError("Not a distribution: \(directory)") }
  // The zip's top-level `Firebase/`: a lone directory without `.xcframework`s is unwrapped.
  var root = directory
  while let only = onlySubdirectory(of: root), xcframeworkNames(in: only).isEmpty {
    root = only
  }

  let entries = visibleEntries(of: root)
  let folderNames = entries.filter { isDirectory(root + "/" + $0) }
  let locations = folderNames.flatMap { folder in
    xcframeworkNames(in: root + "/" + folder)
      .map { (folder: folder, path: root + "/" + folder + "/" + $0) }
  }
  // One `concurrentMap` across every folder, so small folders don't wait for each other.
  let xcframeworks = try await concurrentMap(locations) {
    try await readXCFramework(at: $0.path, in: $0.folder)
  }
  let folders = folderNames.map { name in
    DistributionFolder(name: name, xcframeworks: xcframeworks.filter { $0.folder == name },
                       files: visibleEntries(of: root + "/" + name)
                         .filter { !$0.hasSuffix(".xcframework") })
  }
  return Distribution(root: root, files: entries.filter { !folderNames.contains($0) },
                      folders: folders, extractedDirectory: extractedDirectory)
}

/// The `.xcframework`s directly inside `directory`, e.g. `<work-dir>/xcframeworks`, read like a
/// distribution's, with the directory's name as their folder. For `verify`'s dependencies.
func readXCFrameworks(in directory: Path) async throws -> [XCFramework] {
  guard isDirectory(directory) else {
    throw ZipBuilderError("Not a directory of .xcframeworks: \(directory)")
  }
  let folder = URL(fileURLWithPath: directory).lastPathComponent
  return try await concurrentMap(xcframeworkNames(in: directory)) {
    try await readXCFramework(at: directory + "/" + $0, in: folder)
  }
}

/// The only entry of `directory`, when there's exactly one and it's a directory.
private func onlySubdirectory(of directory: Path) -> Path? {
  let entries = visibleEntries(of: directory)
  guard entries.count == 1 else { return nil }
  let only = directory + "/" + entries[0]
  return isDirectory(only) ? only : nil
}

/// The names of the `.xcframework`s directly inside `directory`.
private func xcframeworkNames(in directory: Path) -> [String] {
  visibleEntries(of: directory).filter { $0.hasSuffix(".xcframework") }
}

private func readXCFramework(at path: Path, in folder: String) async throws -> XCFramework {
  var slices: [Slice] = []
  for library in availableLibraries(of: path) {
    try slices.append(await readSlice(library, in: path))
  }
  let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
  return XCFramework(name: name, folder: folder, path: path,
                     slices: slices.sorted { $0.identifier < $1.identifier },
                     signature: await signature(of: path))
}

/// The `AvailableLibraries` entries of an `.xcframework`'s `Info.plist`, one per slice.
func availableLibraries(of xcframework: Path) -> [[String: Any]] {
  readPlist(xcframework + "/Info.plist")["AvailableLibraries"] as? [[String: Any]] ?? []
}

/// The path of a slice's library: its `.framework`, or a static or dynamic library.
private func libraryPath(of library: [String: Any], in xcframework: Path) -> Path {
  let identifier = library["LibraryIdentifier"] as? String ?? ""
  return xcframework + "/" + identifier + "/" + (library["LibraryPath"] as? String ?? "")
}

/// The path of a slice's binary: `BinaryPath` when the plist has it; else a framework's binary is
/// named after it, and a library is its own binary.
func binaryPath(of library: [String: Any], in xcframework: Path) -> Path {
  let identifier = library["LibraryIdentifier"] as? String ?? ""
  if let binaryPath = library["BinaryPath"] as? String {
    return xcframework + "/" + identifier + "/" + binaryPath
  }
  let libraryPath = libraryPath(of: library, in: xcframework)
  guard libraryPath.hasSuffix(".framework") else { return libraryPath }
  return libraryPath + "/" + URL(fileURLWithPath: libraryPath).deletingPathExtension()
    .lastPathComponent
}

private func readSlice(_ library: [String: Any], in xcframework: Path) async throws -> Slice {
  let identifier = library["LibraryIdentifier"] as? String ?? ""
  let sliceDirectory = xcframework + "/" + identifier
  let libraryPath = libraryPath(of: library, in: xcframework)
  let isFramework = libraryPath.hasSuffix(".framework")
  let binaryPath = binaryPath(of: library, in: xcframework)
  // A framework keeps Headers/, PrivateHeaders/ and Modules/ inside the `.framework`; a library
  // slice keeps them beside the library, its headers in `HeadersPath`.
  let metadataDirectory = isFramework ? libraryPath : sliceDirectory
  let headersPath = isFramework ? "Headers" : (library["HeadersPath"] as? String ?? "Headers")
  let modules = files(in: metadataDirectory + "/Modules")
  // macOS frameworks are versioned: their Info.plist is in Resources/.
  let infoPlist = [libraryPath + "/Info.plist", libraryPath + "/Resources/Info.plist"]
    .first { FileManager.default.fileExists(atPath: $0) }.map(readPlist) ?? [:]

  return try Slice(
    identifier: identifier,
    platform: library["SupportedPlatform"] as? String ?? "",
    variant: library["SupportedPlatformVariant"] as? String,
    architectures: library["SupportedArchitectures"] as? [String] ?? [],
    libraryPath: libraryPath,
    binaryPath: binaryPath,
    exists: FileManager.default.fileExists(atPath: libraryPath),
    binaryKind: await binaryKind(of: binaryPath),
    headers: files(in: metadataDirectory + "/" + headersPath),
    privateHeaders: files(in: metadataDirectory + "/PrivateHeaders"),
    modules: modules,
    moduleMap: try? String(contentsOfFile: metadataDirectory + "/Modules/module.modulemap",
                           encoding: .utf8),
    hasSwiftInterface: modules.contains { $0.hasSuffix(".swiftinterface") },
    infoPlist: infoPlist.compactMapValues { value in
      (value as? String) ?? (value as? NSNumber).map(\.stringValue)
    },
    resourceBundles: isFramework ? resourceBundles(in: libraryPath) : []
  )
}

/// `static` for an archive or object file, `dynamic` for a dylib, per `file`; `missing` when
/// there's no binary, and `unknown` for anything else. Also used by the build's linkage check.
func binaryKind(of binary: Path) async throws -> String {
  guard FileManager.default.fileExists(atPath: binary) else { return "missing" }
  let description = try await shell("file", ["-b", binary])
  if description.contains("shared library") {
    return "dynamic"
  }
  if description.contains("ar archive") || description.contains("object") {
    return "static"
  }
  return "unknown"
}

private func signature(of xcframework: Path) async -> Signature {
  // `codesign -dv` prints to standard error, and fails on unsigned code.
  guard let result = try? await runTool("codesign", ["-dvv", xcframework]),
        result.status == 0 else { return Signature(isSigned: false) }
  let lines = result.standardError.split(separator: "\n")
  if lines.contains("Signature=adhoc") {
    return Signature(isSigned: true, authority: "ad-hoc")
  }
  let authority = lines.first { $0.hasPrefix("Authority=") }?.dropFirst("Authority=".count)
  return Signature(isSigned: true, authority: authority.map(String.init))
}

/// The defined external symbols of a binary (`nm -gUj`), for `diff`. Slow on big binaries.
func exportedSymbols(of binary: Path) async -> Set<String> {
  guard let output = try? await shell("nm", ["-gUj", binary]) else { return [] }
  // Skip blank lines and the `lib.a(file.o):` / `(for architecture arm64):` headers.
  return Set(output.split(separator: "\n").filter { !$0.hasSuffix(":") }.map(String.init))
}

/// The names of `.bundle` directories anywhere inside a framework, outside other bundles.
private func resourceBundles(in framework: Path) -> [String] {
  let paths = (try? FileManager.default.subpathsOfDirectory(atPath: framework)) ?? []
  let bundles = paths.compactMap { path -> String? in
    let components = path.split(separator: "/")
    guard let last = components.last, last.hasSuffix(".bundle") else { return nil }
    // A bundle inside another bundle is part of that one.
    return components.dropLast().contains { $0.hasSuffix(".bundle") } ? nil : String(last)
  }
  return Set(bundles).sorted()
}

/// Every file under `directory` (following a symlinked directory), relative to it and sorted.
func files(in directory: Path) -> [String] {
  let resolved = URL(fileURLWithPath: directory).resolvingSymlinksInPath().path
  let paths = (try? FileManager.default.subpathsOfDirectory(atPath: resolved)) ?? []
  return paths.filter { !isDirectory(resolved + "/" + $0) && !$0.hasSuffix(".DS_Store") }.sorted()
}

private func readPlist(_ path: Path) -> [String: Any] {
  guard let data = FileManager.default.contents(atPath: path) else { return [:] }
  return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    ?? [:]
}
