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

/// What changed from a baseline distribution to a candidate.
struct DiffReport: Codable, Equatable, Sendable {
  var baseline: Path
  var candidate: Path
  var symbolsCompared: Bool
  var releaseVersion: ReleaseVersionChange? // a version bump shared by the changed frameworks
  var folders = Changes()
  var files = Changes() // loose files: `NOTICES` at the root, `FirebaseCrashlytics/run` in a folder
  var frameworks = Changes() // `Folder/Framework`, for frameworks only one side has
  var moved: [Move] = []
  var changed: [FrameworkDiff] = []

  var isEmpty: Bool {
    releaseVersion == nil && !hasLayoutOrFrameworkChanges
  }

  /// Whether anything other than the release version changed.
  var hasLayoutOrFrameworkChanges: Bool {
    !(folders.isEmpty && files.isEmpty && frameworks.isEmpty && moved.isEmpty && changed.isEmpty)
  }
}

/// A release version bump, reported once instead of in each framework whose version it changed.
struct ReleaseVersionChange: Codable, Equatable, Sendable {
  var from: String
  var to: String
  var frameworks: Int // how many frameworks' versions it changed
}

struct Changes: Codable, Hashable, Sendable {
  var added: [String] = []
  var removed: [String] = []
  var isEmpty: Bool {
    added.isEmpty && removed.isEmpty
  }

  /// Items only in `new` (in its order) and only in `old`.
  init(_ old: [String] = [], _ new: [String] = []) {
    let oldSet = Set(old), newSet = Set(new)
    added = new.filter { !oldSet.contains($0) }
    removed = old.filter { !newSet.contains($0) }
  }
}

struct Move: Codable, Equatable, Sendable {
  var framework: String
  var from: [String]
  var to: [String]
}

struct FrameworkDiff: Codable, Equatable, Sendable {
  var name: String
  var folder: String // the candidate's folder
  var differences: [Difference]
}

/// One difference in a framework, and the slices it applies to (empty: every slice both have).
struct Difference: Codable, Hashable, Sendable {
  enum Category: String, Codable, Sendable {
    case slices, architectures, binaryKind, headers, modules, moduleMap, infoPlist,
         resourceBundles, symbols
  }

  var category: Category
  var key: String? // the Info.plist key
  var slices: [String] = []
  var before: String?
  var after: String?
  var changes = Changes()
  var addedCount = 0 // more than `changes.added.count` when names were truncated (symbols)
  var removedCount = 0

  var title: String {
    switch category {
    case .slices: "Slices"
    case .architectures: "Architectures"
    case .binaryKind: "Binary kind"
    case .headers: "Headers"
    case .modules: "Modules files"
    case .moduleMap: "module.modulemap"
    case .infoPlist: "Info.plist \(key ?? "")"
    case .resourceBundles: "Resource bundles"
    case .symbols: "Exported symbols"
    }
  }
}

/// The `Info.plist` values `diff` compares.
let comparedInfoPlistKeys = ["CFBundleShortVersionString", "MinimumOSVersion", "CFBundleIdentifier"]

/// The compared `Info.plist` key that holds the release version. (`CFBundleVersion` is `1` in
/// every framework the tool builds, so it isn't compared and can't carry a bump.)
let releaseVersionKey = "CFBundleShortVersionString"

/// How many symbol names a difference keeps; the counts are always exact.
let symbolNamesShown = 20

/// Compares two distributions. With `symbols`, also runs `nm` on every binary both sides have.
func diffDistributions(_ baseline: Distribution, _ candidate: Distribution,
                       symbols: Bool) async throws -> DiffReport {
  var report = DiffReport(baseline: baseline.root, candidate: candidate.root,
                          symbolsCompared: symbols)
  report.folders = Changes(baseline.folders.map(\.name), candidate.folders.map(\.name))
  report.files = Changes(looseFiles(baseline), looseFiles(candidate))
  // Each framework's copies, one per folder holding it, in folder order.
  let oldCopies = Dictionary(grouping: baseline.xcframeworks, by: \.name)
  let newCopies = Dictionary(grouping: candidate.xcframeworks, by: \.name)
  report.frameworks = Changes(
    baseline.xcframeworks.filter { newCopies[$0.name] == nil }.map(\.qualifiedName),
    candidate.xcframeworks.filter { oldCopies[$0.name] == nil }.map(\.qualifiedName)
  )

  // The frameworks both sides have, by name.
  let shared = oldCopies.sorted { $0.key < $1.key }.compactMap { name, old in
    newCopies[name].map { new in (name: name, old: old, new: new) }
  }
  // A framework moved when the set of folders holding it changed.
  report.moved = shared.compactMap { name, old, new in
    let from = old.map(\.folder), to = new.map(\.folder)
    return Set(from) == Set(to) ? nil : Move(framework: name, from: from, to: to)
  }
  let pairs = shared.map { copiesToCompare($0.old, $0.new) }

  let table = symbols ? try await symbolTable(for: pairs) : [:]
  report.changed = pairs.compactMap { old, new in
    let differences = frameworkDifferences(old, new, symbols: table)
    return differences.isEmpty ? nil
      : FrameworkDiff(name: new.name, folder: new.folder, differences: differences)
  }
  collapseReleaseVersion(in: &report)
  return report
}

/// Reports a release version bump once. A pull request that bumps the release version changes
/// every framework built from the root package, so when at least two frameworks' versions
/// changed, all from the same old version to the same new one in every slice, the bump becomes
/// `releaseVersion` and leaves those frameworks' differences. Frameworks from dependency packages
/// keep their own versions, so they usually don't change and aren't counted. Otherwise, such as
/// a single dependency's update, the version changes stay per framework.
private func collapseReleaseVersion(in report: inout DiffReport) {
  func isVersionChange(_ difference: Difference) -> Bool {
    difference.category == .infoPlist && difference.key == releaseVersionKey
  }
  let changes = report.changed.flatMap(\.differences).filter(isVersionChange)
  guard changes.count >= 2, let first = changes.first,
        let from = first.before, let to = first.after,
        changes.allSatisfy({ $0.before == from && $0.after == to && $0.slices.isEmpty })
  else { return }
  // A change in every slice is one difference per framework, so this counts frameworks.
  report.releaseVersion = ReleaseVersionChange(from: from, to: to, frameworks: changes.count)
  report.changed = report.changed.compactMap { framework in
    var framework = framework
    framework.differences.removeAll(where: isVersionChange)
    return framework.differences.isEmpty ? nil : framework
  }
}

/// One copy from each side of a framework that's in several folders, from the same folder when
/// possible: the candidate's copy in the baseline's first folder (else the candidate's first
/// copy), then the baseline's copy in that copy's folder (else the baseline's first).
private func copiesToCompare(_ old: [XCFramework],
                             _ new: [XCFramework]) -> (old: XCFramework, new: XCFramework) {
  // Don't simplify this to "the first baseline copy whose folder the candidate has": for
  // baseline [A, B, C] and candidate [C, B], that compares the B copies instead of the C ones.
  let newCopy = new.first { $0.folder == old[0].folder } ?? new[0]
  let oldCopy = old.first { $0.folder == newCopy.folder } ?? old[0]
  return (oldCopy, newCopy)
}

private func looseFiles(_ distribution: Distribution) -> [String] {
  distribution.files + distribution.folders.flatMap { folder in
    folder.files.map { folder.name + "/" + $0 }
  }
}

/// Exported symbols of both binaries of every slice the two sides share, keyed by binary path.
private func symbolTable(for pairs: [(old: XCFramework, new: XCFramework)]) async throws
  -> [Path: Set<String>] {
  let binaries = pairs.flatMap { old, new in
    commonSlices(old, new).flatMap { [$0.old.binaryPath, $0.new.binaryPath] }
  }
  let symbols = try await concurrentMap(binaries) { await exportedSymbols(of: $0) }
  return Dictionary(zip(binaries, symbols), uniquingKeysWith: { first, _ in first })
}

private func commonSlices(_ old: XCFramework,
                          _ new: XCFramework) -> [(old: Slice, new: Slice)] {
  old.slices.compactMap { slice in
    new.slices.first { $0.identifier == slice.identifier }.map { (slice, $0) }
  }
}

/// A framework's differences. Identical per-slice differences are merged into one entry.
func frameworkDifferences(_ old: XCFramework, _ new: XCFramework,
                          symbols: [Path: Set<String>]) -> [Difference] {
  var differences: [Difference] = []
  let slices = Changes(old.slices.map(\.identifier), new.slices.map(\.identifier))
  if !slices.isEmpty {
    differences.append(Difference(category: .slices, changes: slices))
  }

  let common = commonSlices(old, new)
  var groups: [Difference: [String]] = [:], order: [Difference] = []
  for (oldSlice, newSlice) in common {
    for difference in sliceDifferences(oldSlice, newSlice, symbols: symbols) {
      if groups[difference] == nil {
        order.append(difference)
      }
      groups[difference, default: []].append(newSlice.identifier)
    }
  }
  return differences + order.map { difference in
    var difference = difference
    let slices = groups[difference]!
    // The same difference in every shared slice is listed without slices.
    difference.slices = slices.count == common.count ? [] : slices
    return difference
  }
}

private func sliceDifferences(_ old: Slice, _ new: Slice,
                              symbols: [Path: Set<String>]) -> [Difference] {
  var differences: [Difference] = []
  // Adds a `before → after` difference when the values differ, with nil shown as `none`.
  func addIfDifferent(_ category: Difference.Category, key: String? = nil, _ before: String?,
                      _ after: String?) {
    if before != after {
      differences.append(Difference(category: category, key: key, before: before ?? "none",
                                    after: after ?? "none"))
    }
  }
  // Adds the added and removed items, if any. `counts` replaces their counts when the items
  // were truncated.
  func addChanges(_ category: Difference.Category, _ before: [String], _ after: [String],
                  counts: (added: Int, removed: Int)? = nil) {
    let changes = Changes(before, after)
    if !changes.isEmpty {
      let counts = counts ?? (added: changes.added.count, removed: changes.removed.count)
      differences.append(Difference(category: category, changes: changes,
                                    addedCount: counts.added, removedCount: counts.removed))
    }
  }

  addIfDifferent(.architectures, old.architectures.sorted().joined(separator: ", "),
                 new.architectures.sorted().joined(separator: ", "))
  addIfDifferent(.binaryKind, old.binaryKind, new.binaryKind)
  addChanges(.headers, headerPaths(old), headerPaths(new))
  addChanges(.modules, old.modules, new.modules)
  if old.moduleMap != new.moduleMap {
    let before = trimmedLines(old.moduleMap), after = trimmedLines(new.moduleMap)
    if Changes(before, after).isEmpty {
      addIfDifferent(.moduleMap, "same lines", "reordered or reformatted")
    } else {
      addChanges(.moduleMap, before, after)
    }
  }
  for key in comparedInfoPlistKeys {
    addIfDifferent(.infoPlist, key: key, old.infoPlist[key], new.infoPlist[key])
  }
  addChanges(.resourceBundles, old.resourceBundles, new.resourceBundles)
  if let before = symbols[old.binaryPath], let after = symbols[new.binaryPath] {
    let added = after.subtracting(before).sorted(), removed = before.subtracting(after).sorted()
    // The two lists are disjoint, so `Changes` keeps exactly the shown names.
    addChanges(.symbols, Array(removed.prefix(symbolNamesShown)),
               Array(added.prefix(symbolNamesShown)),
               counts: (added: added.count, removed: removed.count))
  }
  return differences
}

/// A module map's lines, trimmed, so indentation changes don't count as changed lines.
private func trimmedLines(_ text: String?) -> [String] {
  text?.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
}

private func headerPaths(_ slice: Slice) -> [String] {
  slice.headers.map { "Headers/" + $0 } + slice.privateHeaders.map { "PrivateHeaders/" + $0 }
}
