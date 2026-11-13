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

@preconcurrency import Basics
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

// The license files planning records for each framework and binary, for `NOTICES`.
// See docs/how-it-works.md#licenses.

/// The names a license file can have, matched case-insensitively. When a directory has several,
/// the first in this list wins, so the choice doesn't depend on the order the file system lists
/// them in.
let licenseFileNames = ["LICENSE", "LICENSE.txt", "LICENSE.md", "COPYING"]

/// The license file of `module`: the nearest one in its target directory or a parent, up to its
/// package's root (inclusive). Packages put a license file at their root, and a directory can
/// have its own, which applies to the targets below it (Firebase's `Firestore/LICENSE`). A
/// binary target has no source directory, so it gets its package root's.
func licenseFile(of module: ResolvedModule, _ graph: ModulesGraph) -> AbsolutePath? {
  guard let packageRoot = graph.package(for: module)?.path else { return nil }
  let start = module.type == .binary ? packageRoot : module.underlying.path
  return nearestLicenseFile(from: start, upTo: packageRoot)
}

/// The license file nearest to `directory`: in it, or in a parent up to `root` (inclusive). A
/// directory outside `root` only looks in `root`, so the walk never leaves the package.
func nearestLicenseFile(from directory: AbsolutePath, upTo root: AbsolutePath) -> AbsolutePath? {
  var current = directory.isDescendantOfOrEqual(to: root) ? directory : root
  while true {
    if let file = licenseFile(in: current) {
      return file
    }
    if current == root {
      return nil
    }
    current = current.parentDirectory
  }
}

/// The license file directly in `directory`: a file named like one of `licenseFileNames`, ignoring
/// case. The earliest name in that list wins, then the lowest file name, for file systems that
/// tell `LICENSE` from `License`.
func licenseFile(in directory: AbsolutePath) -> AbsolutePath? {
  let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory.pathString)) ?? []
  let candidates = entries.compactMap { entry -> (rank: Int, name: String)? in
    guard let rank = licenseFileNames.firstIndex(where: {
      $0.caseInsensitiveCompare(entry) == .orderedSame
    }), !isDirectory(directory.appending(component: entry).pathString) else { return nil }
    return (rank, entry)
  }
  return candidates.min { ($0.rank, $0.name) < ($1.rank, $1.name) }
    .map { directory.appending(component: $0.name) }
}
