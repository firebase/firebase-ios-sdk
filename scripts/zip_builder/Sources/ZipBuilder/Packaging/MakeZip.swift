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

/// Lays out the distribution in `<workDir>/dist/<release.name>/`, signs it when given an identity,
/// and zips it into `<workDir>/<release.archiveName>`.
///
/// `xcframeworks` is the build stage's output directory, holding one `<Name>.xcframework` per
/// framework and binary in the plan. Returns the zip's path.
func makeZip(xcframeworks: Path, plan: Plan, config: Config, packageRoot: Path, workDir: Path,
             signingIdentity: String?, version: String) async throws -> Path {
  let manager = FileManager.default
  let workDir = URL(fileURLWithPath: workDir).standardizedFileURL
  let root = distributionRoot(workDir: workDir.path, config: config)
  try? manager.removeItem(at: root)
  try manager.createDirectory(at: root, withIntermediateDirectories: true)

  try layOutFolders(plan.folders, xcframeworks: xcframeworks, packageRoot: packageRoot, in: root)
  try await placeExternalArtifacts(config.zip.externalArtifacts, in: root,
                                   downloads: workDir.appendingPathComponent("downloads"))
  try Data(metadata(plan, baseFolder: config.products.base?.product).utf8)
    .write(to: root.appendingPathComponent("METADATA.md"))

  if let signingIdentity {
    let (signed, kept) = try await signXCFrameworks(in: root, identity: signingIdentity)
    logger.info(
      "Signed \(signed) .xcframeworks with \(signingIdentity); \(kept) kept their own signature"
    )
  }

  let zip = workDir.appendingPathComponent(archiveName(config, version: version))
  try? manager.removeItem(at: zip)
  // Without extended attributes: they're per machine (`com.apple.provenance`), and ditto would
  // store them as `._*` or `__MACOSX` entries.
  try await shell("ditto", ["-c", "-k", "--norsrc", "--noextattr", "--noacl", "--keepParent",
                            root.path, zip.path])
  return zip.path
}

/// The distribution root: `<workDir>/dist/<release.name>`.
func distributionRoot(workDir: Path, config: Config) -> URL {
  URL(fileURLWithPath: workDir).appendingPathComponent("dist")
    .appendingPathComponent(config.release.name).standardizedFileURL
}

/// A zip folder's directory under the distribution `root`; `zipRootFolder` is `root` itself, so
/// files configured for `"."` land at the top of the zip.
func directory(ofFolder name: String, in root: URL) -> URL {
  name == zipRootFolder ? root : root.appendingPathComponent(name)
}

/// `release.archiveName` with `{name}` and `{version}` replaced, e.g. `Firebase-13.0.0.zip`.
func archiveName(_ config: Config, version: String) -> String {
  config.release.archiveName
    .replacingOccurrences(of: "{name}", with: config.release.name)
    .replacingOccurrences(of: "{version}", with: version)
}

/// Copies each folder's `.xcframework`s and its package-root-relative files. The `zipRootFolder`
/// folder is the distribution root.
func layOutFolders(_ folders: [Folder], xcframeworks: Path, packageRoot: Path,
                   in root: URL) throws {
  for folder in folders {
    let directory = directory(ofFolder: folder.name, in: root)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in folder.frameworks {
      let source = URL(fileURLWithPath: xcframeworks).appendingPathComponent("\(name).xcframework")
      try copy(source, into: directory,
               ifMissing: "\(folder.name): \(source.lastPathComponent) isn't in \(xcframeworks).")
    }
    for file in folder.files {
      try copy(URL(fileURLWithPath: fullPath(file, packageRoot)), into: directory,
               ifMissing: "\(folder.name): \(file) doesn't exist in \(packageRoot).")
    }
  }
}

/// Copies `source` into `directory` under its own name (an APFS clone, through `FileManager`);
/// throws `message` when `source` doesn't exist.
private func copy(_ source: URL, into directory: URL,
                  ifMissing message: @autoclosure () -> String) throws {
  guard FileManager.default.fileExists(atPath: source.path) else {
    throw ZipBuilderError(message())
  }
  try FileManager.default.copyItem(
    at: source,
    to: directory.appendingPathComponent(source.lastPathComponent)
  )
}

// MARK: - External artifacts

/// `zip.externalArtifacts`: downloads each zip (once per URL, into `downloads`), unpacks it, and
/// places its contents, or the item at `subpath`, into the named folder (see
/// `Config.ExternalArtifact`). With `stripSignatures`, `_CodeSignature` directories are removed.
func placeExternalArtifacts(_ artifacts: [Config.ExternalArtifact], in root: URL,
                            downloads: URL) async throws {
  let manager = FileManager.default
  for artifact in artifacts {
    let archive = try await download(artifact.url, into: downloads)
    let unpacked = downloads.appendingPathComponent("unpacked-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: unpacked) }
    try await shell("ditto", ["-x", "-k", archive.path, unpacked.path])

    let source = artifact.subpath.map { unpacked.appendingPathComponent($0) } ?? unpacked
    guard manager.fileExists(atPath: source.path) else {
      throw ZipBuilderError(
        "zip.externalArtifacts: \(artifact.subpath ?? "") isn't in \(artifact.url)."
      )
    }
    // A plain directory contributes its entries; a file or a bundle (`.xcframework`) is the item.
    let items = isDirectory(source.path) && source.pathExtension.isEmpty
      ? visibleEntries(of: source.path).map { source.appendingPathComponent($0) }
      : [source]
    let folder = directory(ofFolder: artifact.to, in: root)
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    for item in items {
      let destination = folder.appendingPathComponent(item.lastPathComponent)
      try manager.moveItem(at: item, to: destination)
      if artifact.stripSignatures {
        try removeCodeSignatures(in: destination)
      }
    }
  }
}

/// The zip at `url`, from `<directory>/<sha256 of url>.zip` when it was downloaded before.
func download(_ url: String, into directory: URL) async throws -> URL {
  guard let source = URL(string: url) else {
    throw ZipBuilderError("zip.externalArtifacts: \(url) isn't a URL.")
  }
  let cached = directory.appendingPathComponent("\(sha256Hex(Data(url.utf8))).zip")
  if FileManager.default.fileExists(atPath: cached.path) {
    return cached
  }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let (temporary, response) = try await URLSession.shared.download(from: source)
  if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
    throw ZipBuilderError("Downloading \(url) failed with HTTP status \(http.statusCode).")
  }
  try FileManager.default.moveItem(at: temporary, to: cached)
  logger.info("Downloaded \(url)")
  return cached
}

/// Removes every `_CodeSignature` directory under `path`.
func removeCodeSignatures(in path: URL) throws {
  let manager = FileManager.default
  let signatures = (manager.enumerator(atPath: path.path)?.allObjects as? [String] ?? [])
    .filter { fileName($0) == "_CodeSignature" }
  for signature in signatures {
    try manager.removeItem(at: path.appendingPathComponent(signature))
  }
}

// MARK: - Signing

/// Signs every unsigned `.xcframework` under `root` with `identity` (`-` for ad-hoc).
/// Already signed ones (vendors' binaries) keep their signature. Returns both counts.
func signXCFrameworks(in root: URL, identity: String) async throws -> (signed: Int, kept: Int) {
  // Whether each one was newly signed here.
  let newlySigned = try await concurrentMap(xcframeworkPaths(in: root)) { path in
    // `codesign -d` fails on unsigned code.
    if try await runTool("codesign", ["-d", path]).status == 0 {
      return false
    }
    try await shell("codesign", ["--timestamp", "--sign", identity, path])
    return true
  }
  let signed = newlySigned.count(where: { $0 })
  return (signed, newlySigned.count - signed)
}

/// Every `.xcframework` under `root`, outermost only, sorted.
func xcframeworkPaths(in root: URL) -> [Path] {
  guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { return [] }
  var paths: [Path] = []
  while let relative = enumerator.nextObject() as? String {
    if relative.hasSuffix(".xcframework") {
      paths.append(root.appendingPathComponent(relative).path)
      enumerator.skipDescendants()
    }
  }
  return paths.sorted()
}
