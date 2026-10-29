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

import CryptoKit
import Foundation

/// Bump to invalidate every cache entry on purpose, e.g. when `makeProject` changes what it
/// generates.
let fingerprintFormat = "zip-builder-2"

/// Every framework's fingerprint, by name. Binaries and search-path directories are hashed once
/// per call. Files under `excluded` directories (the work dir and the cache) never count.
/// See docs/how-it-works.md#fingerprints.
func fingerprints(of plan: Plan, packageRoot: Path, xcodeVersion: String,
                  excluding excluded: [Path] = []) throws -> [String: String] {
  var fingerprints = Fingerprints(plan: plan, packageRoot: packageRoot, xcodeVersion: xcodeVersion,
                                  excluded: excluded)
  for framework in plan.frameworks {
    _ = try fingerprints.of(framework)
  }
  return fingerprints.byName
}

/// The installed Xcode, e.g. `Xcode 26.2\nBuild version 17C52`, for fingerprints.
func xcodeVersion() async throws -> String {
  try await shell("xcodebuild", ["-version"]).trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Computes fingerprints with memoization: each framework, binary and search-path directory is
/// hashed once.
private struct Fingerprints {
  let plan: Plan
  let packageRoot: Path
  let xcodeVersion: String
  let excluded: Set<Path>
  var byName: [String: String] = [:]
  var binaryHashes: [String: String] = [:]
  var directoryHashes: [String: String] = [:]

  init(plan: Plan, packageRoot: Path, xcodeVersion: String, excluded: [Path]) {
    self.plan = plan
    self.packageRoot = URL(fileURLWithPath: packageRoot).standardizedFileURL.path
    self.xcodeVersion = xcodeVersion
    self.excluded = Set(excluded.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })
  }

  /// Covers the project settings, the framework's model fields (except `layout`, applied after
  /// caching), its files' contents, the headers under its outside search paths, its
  /// destinations, the Xcode version, its binaries' contents, and its framework dependencies'
  /// fingerprints.
  mutating func of(_ framework: Framework) throws -> String {
    if let known = byName[framework.name] {
      return known
    }
    byName[framework.name] = "" // a cycle hashes the empty string instead of recursing forever
    var withoutLayout = framework
    withoutLayout.layout = Layout()
    var lines = try ["format \(fingerprintFormat)", "xcode \(xcodeVersion)",
                     "settings \(stableJSON(plan.settings))",
                     "framework \(stableJSON(withoutLayout))",
                     "destinations " + framework.destinations.map(\.name).joined(separator: " ")]
    let files = framework.sources.map(\.path) + framework.headers.map(\.path)
      + framework.resources.map(\.path) + [framework.moduleMap].compactMap { $0 }
    for path in files {
      try lines.append("file \(relative(path)) \(contentHash(fullPath(path, packageRoot)))")
    }
    for path in outsideSearchPaths(of: framework) {
      try lines.append("search path \(path) \(headersHash(path))")
    }
    for dependency in framework.dependencies {
      if let binary = plan.binaries.first(where: { $0.name == dependency.name }) {
        try lines.append("binary \(binary.name) \(stableJSON(binary)) \(binaryHash(of: binary))")
      } else if let other = plan.frameworks.first(where: { $0.name == dependency.name }) {
        try lines.append("dependency \(other.name) \(of(other))")
      }
    }
    let result = sha256Hex(Data(lines.joined(separator: "\n").utf8))
    byName[framework.name] = result
    return result
  }

  private mutating func binaryHash(of binary: Binary) throws -> String {
    let path = fullPath(binary.path, packageRoot)
    if let known = binaryHashes[path] {
      return known
    }
    let result = try contentHash(path)
    binaryHashes[path] = result
    return result
  }

  /// The framework's header search paths (its own and the project's) outside its own source
  /// directory, the deepest directory holding all its sources and headers. Headers included
  /// through them, e.g. Firebase's repo-root paths, are in no header list, so they're hashed here
  /// to keep a changed header from leaving a stale framework in the cache.
  /// When that directory is the package root, every search path counts.
  private func outsideSearchPaths(of framework: Framework) -> [Path] {
    // Absolute paths are generated files, outside the package, so they don't place the
    // framework's own directory.
    let files = (framework.sources.map(\.path) + framework.headers.map(\.path))
      .filter { !$0.hasPrefix("/") }
    let ownDirectory = deepestCommonDirectory(files)
    var paths: Set<Path> = []
    for settings in [framework.settings, plan.settings] {
      for key in settings.keys where isHeaderSearchPathSetting(key) {
        for path in settings[key]?.list ?? [] where !path.contains("$(") {
          let path = path == "." ? "" : path // "" is the package root, as in `ownDirectory`
          // When the own directory is the package root, every search path counts: the
          // framework's headers could come from anywhere in the package.
          if ownDirectory.isEmpty || !isInside(path, ownDirectory) {
            paths.insert(path)
          }
        }
      }
    }
    return paths.sorted()
  }

  /// The paths and contents of the header-like files under a directory. A missing directory
  /// hashes as empty. Build outputs are skipped (`isSkippedDirectory`).
  private mutating func headersHash(_ path: Path) throws -> String {
    let directory = URL(fileURLWithPath: fullPath(path.isEmpty ? "." : path, packageRoot))
      .resolvingSymlinksInPath().path
    if let known = directoryHashes[directory] {
      return known
    }
    var lines: [String] = []
    if let enumerator = FileManager.default.enumerator(atPath: directory) {
      while let file = enumerator.nextObject() as? String {
        let filePath = directory + "/" + file
        if enumerator.fileAttributes?[.type] as? FileAttributeType == .typeDirectory {
          if isSkippedDirectory(filePath) {
            enumerator.skipDescendants()
          }
        } else if isHeaderFile(file),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
          lines.append("\(file) \(sha256Hex(data))")
        }
      }
    }
    let result = sha256Hex(Data(lines.sorted().joined(separator: "\n").utf8))
    directoryHashes[directory] = result
    return result
  }

  /// Whether a directory under a search path can't hold headers the package's sources include:
  /// hidden ones, excluded ones (the work dir, the cache), bundles (`.xcframework`, `.framework`,
  /// `.xcodeproj`, …), `DerivedData`, and other zip-builder work dirs (those with a `plan.json`)
  /// only hold copies; another Swift package (one with its own `Package.swift`) holds its own
  /// targets, unless the plan's frameworks have files in it.
  private func isSkippedDirectory(_ path: Path) -> Bool {
    let name = fileName(path)
    let bundleExtensions: Set = ["xcframework", "framework", "xcodeproj", "xcarchive", "bundle",
                                 "xcworkspace"]
    let manager = FileManager.default
    return name.hasPrefix(".") || name == "DerivedData" || excluded.contains(path)
      || bundleExtensions.contains((name as NSString).pathExtension)
      || manager.fileExists(atPath: path + "/plan.json")
      || (manager.fileExists(atPath: path + "/Package.swift") && !holdsPlannedFiles(path))
  }

  /// Whether any framework in the plan has a source, header, resource or module map under the
  /// directory at the absolute `path`. A package's manifest can point targets into a directory
  /// that has its own `Package.swift` (Firebase's `GeminiLanguageModel`).
  private func holdsPlannedFiles(_ path: Path) -> Bool {
    let prefix = relative(path) + "/"
    return plan.frameworks.contains { framework in
      let files = framework.sources.map(\.path) + framework.headers.map(\.path)
        + framework.resources.map(\.path) + [framework.moduleMap].compactMap { $0 }
      return files.contains { relative(fullPath($0, packageRoot)).hasPrefix(prefix) }
    }
  }

  /// `path` relative to the package root, so fingerprints match across checkouts.
  private func relative(_ path: Path) -> Path {
    path.hasPrefix(packageRoot + "/") ? String(path.dropFirst(packageRoot.count + 1)) : path
  }
}

/// The deepest directory holding every one of `files` (relative paths): `""` for the package
/// root, or when `files` is empty.
func deepestCommonDirectory(_ files: [Path]) -> Path {
  let directories = files.map { ($0 as NSString).deletingLastPathComponent.split(separator: "/") }
  var common = directories.first ?? []
  for directory in directories.dropFirst() {
    // Keep the leading components both share.
    common = Array(zip(common, directory).prefix { $0 == $1 }.map(\.0))
  }
  return common.joined(separator: "/")
}

/// Whether `path` is `directory` or under it (relative paths, compared by whole components).
func isInside(_ path: Path, _ directory: Path) -> Bool {
  path == directory || path.hasPrefix(directory + "/")
}

/// The hash of a file's contents, or of a directory's relative file paths and contents.
/// Symbolic links are followed.
func contentHash(_ path: Path) throws -> String {
  let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
  guard FileManager.default.fileExists(atPath: url.path) else {
    throw ZipBuilderError("Can't fingerprint \(path): no such file.")
  }
  guard isDirectory(url.path) else {
    return try sha256Hex(Data(contentsOf: url, options: .mappedIfSafe))
  }
  let files = try FileManager.default.subpathsOfDirectory(atPath: url.path).sorted()
  var lines: [String] = []
  for file in files {
    let child = url.appendingPathComponent(file).resolvingSymlinksInPath()
    // `fileExists` skips broken symbolic links.
    if FileManager.default.fileExists(atPath: child.path), !isDirectory(child.path) {
      try lines.append("\(file) \(sha256Hex(Data(contentsOf: child, options: .mappedIfSafe)))")
    }
  }
  return sha256Hex(Data(lines.joined(separator: "\n").utf8))
}

/// The SHA-256 of `data`, as lowercase hex.
func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// JSON with sorted keys, so equal values hash equally.
private func stableJSON(_ value: some Encodable) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  return try String(decoding: encoder.encode(value), as: UTF8.self)
}

/// A directory of finished `.xcframework`s, before layout, one per fingerprint:
/// `<directory>/<fingerprint>/<Name>.xcframework`. See docs/how-it-works.md#the-framework-cache.
struct FrameworkCache {
  let directory: Path

  /// `~/Library/Caches/zip-builder/frameworks`.
  static let defaultDirectory = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("zip-builder/frameworks").path

  func path(for fingerprint: String, name: String) -> Path {
    URL(fileURLWithPath: directory).appendingPathComponent(fingerprint)
      .appendingPathComponent("\(name).xcframework").path
  }

  func has(_ fingerprint: String, name: String) -> Bool {
    FileManager.default.fileExists(atPath: path(for: fingerprint, name: name))
  }

  /// Copies `xcframework` into the cache. It's copied into a temporary directory inside the cache
  /// first, then renamed into place, so a half-written entry never counts as cached. The first
  /// writer wins: an entry that already exists, or appears meanwhile (another build stored the
  /// same fingerprint), is kept, and this copy is discarded.
  func store(_ xcframework: Path, for fingerprint: String) throws {
    let manager = FileManager.default
    let root = URL(fileURLWithPath: directory)
    let temporary = root.appendingPathComponent(".tmp-\(UUID().uuidString)")
    try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: temporary) }
    let source = URL(fileURLWithPath: xcframework)
    try manager.copyItem(at: source, to: temporary.appendingPathComponent(source.lastPathComponent))
    let entry = root.appendingPathComponent(fingerprint)
    do {
      try manager.moveItem(at: temporary, to: entry)
    } catch where manager.fileExists(atPath: entry.path) {
      // Already stored; equal fingerprints mean equivalent entries.
    }
  }
}
