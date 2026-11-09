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

// The Carthage archives and their binary specs ("manifests"): one zip per distribution folder,
// and one JSON file per folder mapping each release version to its archive's URL.
// See docs/how-it-works.md#carthage.

/// Zips each folder of the distribution at `root` into `<output>/<folder>-<hash>.zip`, with the
/// folder as its top-level directory, and writes each folder's updated binary spec next to it.
/// Loose files at the root aren't archived. Returns the archives' paths.
func makeCarthageArchives(of root: URL, _ carthage: Config.Carthage, version: String,
                          packageRoot: Path, output: URL) async throws -> [Path] {
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
  let folders = visibleEntries(of: root.path).filter { isDirectory(root.path + "/" + $0) }
  var archives: [Path] = []
  for folder in folders {
    let name = try carthageArchiveName(of: root.appendingPathComponent(folder))
    let archive = output.appendingPathComponent(name)
    // `zip`, as the CocoaPods-era builder did: `--symlinks` stores the links of macOS-style
    // versioned frameworks as links, and running it in `root` makes `<folder>/` the top level.
    try await shell("zip", ["--symlinks", "-q", "-r", archive.path, folder], in: root.path)
    let url = carthage.url.replacingOccurrences(of: "{version}", with: version)
      .replacingOccurrences(of: "{archive}", with: name)
    try writeManifest(for: folder, version: version, url: url, carthage, packageRoot: packageRoot,
                      output: output)
    logger.info("Archived \(folder): \(name) (\(formattedSize(ofFile: archive.path)))")
    archives.append(archive.path)
  }
  return archives
}

/// `<folder>-<hash>.zip`: the first 16 hex digits of `folderContentsHash`, so an archive's name
/// changes exactly when its contents do.
func carthageArchiveName(of folder: URL) throws -> String {
  try "\(folder.lastPathComponent)-\(folderContentsHash(folder).prefix(16)).zip"
}

/// The SHA-256 of a directory's relative paths and contents, as lowercase hex: one line per file
/// (`<path> <sha256 of its contents>`) and per symbolic link (`<path> -> <its target>`), sorted
/// by path. Absolute paths never count, so the same contents hash the same anywhere, and links
/// aren't followed, as the archive keeps them as links. Directories only count through what
/// they hold.
func folderContentsHash(_ folder: URL) throws -> String {
  let manager = FileManager.default
  guard let enumerator = manager.enumerator(atPath: folder.path) else {
    throw ZipBuilderError("Can't read \(folder.path).")
  }
  var lines: [String] = []
  while let relative = enumerator.nextObject() as? String {
    let path = folder.appendingPathComponent(relative).path
    // `attributesOfItem` doesn't follow a symbolic link, so a link is seen as one.
    let type = try manager.attributesOfItem(atPath: path)[.type] as? FileAttributeType
    if type == .typeSymbolicLink {
      try lines.append("\(relative) -> \(manager.destinationOfSymbolicLink(atPath: path))")
    } else if type == .typeRegular {
      let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
      lines.append("\(relative) \(sha256Hex(data))")
    }
  }
  return sha256Hex(Data(lines.sorted().joined(separator: "\n").utf8))
}

/// Reads the folder's binary spec at `carthage.manifests` (a new one when it's missing), sets
/// `version` to `url`, and writes it to `output` under the same file name. The repo's copy isn't
/// changed: the release process commits the written one.
private func writeManifest(for folder: String, version: String, url: String,
                           _ carthage: Config.Carthage, packageRoot: Path, output: URL) throws {
  let path = carthage.manifests.replacingOccurrences(of: "{folder}", with: folder)
  let source = URL(fileURLWithPath: fullPath(path, packageRoot))
  var manifest: [String: String] = [:]
  if FileManager.default.fileExists(atPath: source.path) {
    manifest = try parseManifest(Data(contentsOf: source), path: path)
  } else {
    warn("carthage.manifests: \(path) doesn't exist; it's created with only \(version).")
  }
  if let listed = manifest[version], listed != url {
    warn("carthage.manifests: \(path) already lists \(version) as \(listed); replaced with \(url).")
  }
  manifest[version] = url
  try Data(renderManifest(manifest).utf8)
    .write(to: output.appendingPathComponent(source.lastPathComponent))
}

/// A binary spec's versions and URLs.
func parseManifest(_ data: Data, path: Path) throws -> [String: String] {
  do {
    return try JSONDecoder().decode([String: String].self, from: data)
  } catch {
    throw ZipBuilderError("carthage.manifests: \(path) isn't a JSON object of version to URL: "
      + "\(error)")
  }
}

/// A binary spec in the layout of the repo's existing ones, so rewriting one without changes
/// gives the same bytes: versions sorted as strings, one `  "version": "url"` line each (slashes
/// unescaped), and a final newline.
func renderManifest(_ manifest: [String: String]) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .withoutEscapingSlashes
  func quoted(_ text: String) throws -> String {
    try String(decoding: encoder.encode(text), as: UTF8.self)
  }
  let lines = try manifest.sorted { $0.key < $1.key }
    .map { try "  \(quoted($0.key)): \(quoted($0.value))" }
  return "{\n" + lines.joined(separator: ",\n") + "\n}\n"
}
