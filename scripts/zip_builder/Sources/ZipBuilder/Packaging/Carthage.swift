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

// The `carthage` command's changes to a staged copy of a finished distribution: the extra
// build's frameworks and `carthage.files`. The archives are in CarthageArchives.swift, the
// umbrella framework in UmbrellaFramework.swift. See docs/how-it-works.md#carthage.

/// `plan` restricted to the frameworks and binaries in `names` and everything they reach, with
/// no folders: what the extra build compiles.
///
/// The names come from a plan of the `carthage.rebuild` product alone, but the frameworks from
/// the whole release's plan: an aggregate (`frameworks.aggregate`) planned for one product only
/// holds the parts that product reaches, under the whole aggregate's name, so it couldn't
/// replace the distribution's.
func restricting(_ plan: Plan, toWhatIsReachedFrom names: Set<String>) -> Plan {
  let frameworks = Dictionary(plan.frameworks.map { ($0.name, $0) }) { first, _ in first }
  var reached = Set<String>()
  var pending = names.sorted()
  while let name = pending.popLast() {
    guard reached.insert(name).inserted else { continue }
    pending += frameworks[name]?.dependencies.map(\.name) ?? []
  }
  var restricted = plan
  restricted.frameworks = plan.frameworks.filter { reached.contains($0.name) }
  restricted.binaries = plan.binaries.filter { reached.contains($0.name) }
  restricted.folders = []
  let keptStatic = (plan.keptStatic ?? []).filter(reached.contains)
  restricted.keptStatic = keptStatic.isEmpty ? nil : keptStatic
  return restricted
}

/// The `.xcframework`s of `distribution` that `carthage` changes: the extra build's frameworks
/// (`rebuilt`, in every folder holding them) and the targets of `carthage.files`. Absolute paths,
/// sorted.
func xcframeworksChangedByCarthage(_ distribution: Distribution, rebuilt: [String],
                                   files: [Path: [Path]]) -> [Path] {
  let replaced = distribution.xcframeworks.filter { rebuilt.contains($0.name) }.map(\.path)
  let targets = files.keys.map { distribution.root + "/" + $0 }
    .filter { isDirectory($0) }
  return Set(replaced + targets).sorted()
}

/// Fails when one of `xcframeworks` is signed (it has a `_CodeSignature` directory): changing it
/// would break its signature. Signing comes later in the release process. Signed vendor binaries
/// elsewhere in the distribution are fine, since they're archived as they are.
func checkUnsigned(_ xcframeworks: [Path]) throws {
  let signed = xcframeworks.filter {
    FileManager.default.fileExists(atPath: $0 + "/_CodeSignature")
  }
  guard signed.isEmpty else {
    throw ZipBuilderError("""
    carthage changes these .xcframeworks, but they're signed: \
    \(signed.joined(separator: ", ")). Run it on the unsigned distribution (package or release \
    without --sign), and sign afterwards.
    """)
  }
}

/// Copies the distribution at `root` to `staging` (replacing it), so the input is never changed.
/// Returns the copy's root.
func stageDistribution(_ root: Path, at staging: URL) throws -> URL {
  let manager = FileManager.default
  let input = URL(fileURLWithPath: root).standardizedFileURL.resolvingSymlinksInPath().path
  let copy = staging.standardizedFileURL.resolvingSymlinksInPath().path
  // Replacing the staging directory would delete an input inside it.
  guard !isInside(input, copy) else {
    throw ZipBuilderError("\(root) is carthage's own staging copy; pass the distribution "
      + "package or release made.")
  }
  try? manager.removeItem(at: staging)
  try manager.createDirectory(at: staging.deletingLastPathComponent(),
                              withIntermediateDirectories: true)
  // An APFS clone, with symbolic links copied as links.
  try manager.copyItem(at: URL(fileURLWithPath: root), to: staging)
  return staging
}

/// Replaces every copy, in any folder of the distribution at `root`, of each framework in
/// `names` with the one in `xcframeworks`. Warns about frameworks the distribution doesn't have.
/// Returns the qualified names (`<folder>/<name>`) of the replaced ones, sorted.
func replacingFrameworks(_ names: [String], in root: URL, from xcframeworks: Path) throws
  -> [String] {
  let manager = FileManager.default
  let folders = visibleEntries(of: root.path).filter { isDirectory(root.path + "/" + $0) }
  var replaced: [String] = []
  for name in names.sorted() {
    let file = "\(name).xcframework"
    let copies = folders.filter { manager.fileExists(atPath: "\(root.path)/\($0)/\(file)") }
    guard !copies.isEmpty else {
      warn("carthage.rebuild: \(name) was rebuilt, but the distribution has no \(file); skipped.")
      continue
    }
    for folder in copies {
      let destination = root.appendingPathComponent(folder).appendingPathComponent(file)
      try manager.removeItem(at: destination)
      try manager.copyItem(at: URL(fileURLWithPath: xcframeworks).appendingPathComponent(file),
                           to: destination)
      replaced.append("\(folder)/\(name)")
    }
  }
  return replaced.sorted()
}

/// `carthage.files`: copies each listed file from the root of the distribution at `root` into
/// the `.xcframework` it's listed under. Carthage installs only frameworks, so a file at the
/// root (such as the license notices) would otherwise be lost.
func addCarthageFiles(_ files: [Path: [Path]], in root: URL) throws {
  let manager = FileManager.default
  for (target, names) in files.sorted(by: { $0.key < $1.key }) {
    let xcframework = root.appendingPathComponent(target)
    guard target.hasSuffix(".xcframework"), isDirectory(xcframework.path) else {
      throw ZipBuilderError("carthage.files: \(target) isn't an .xcframework in the distribution.")
    }
    for name in names {
      let source = root.appendingPathComponent(name)
      let destination = xcframework.appendingPathComponent(source.lastPathComponent)
      guard manager.fileExists(atPath: source.path) else {
        throw ZipBuilderError("carthage.files: \(name) isn't in the distribution.")
      }
      guard !manager.fileExists(atPath: destination.path) else {
        throw ZipBuilderError("carthage.files: \(target) already has \(source.lastPathComponent).")
      }
      try manager.copyItem(at: source, to: destination)
      logger.info("Copied \(name) into \(target)")
    }
  }
}
