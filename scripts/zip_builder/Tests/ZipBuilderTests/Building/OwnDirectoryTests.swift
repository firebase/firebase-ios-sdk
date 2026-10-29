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

/// A framework's own directory decides which header search paths count toward its fingerprint.
struct OwnDirectoryTests {
  @Test(arguments: [
    ([], ""),
    (["a.m"], ""),
    (["A/a.m"], "A"),
    (["A/a.m", "A/include/A.h"], "A"),
    (["A/B/c.m", "A/B/C/d.h"], "A/B"),
    (["A/a.m", "B/b.m"], ""),
    (["Ab/x.m", "A/y.m"], ""), // whole components, not string prefixes
  ])
  func deepestCommonDirectory(files: [String], expected: String) {
    #expect(ZipBuilder.deepestCommonDirectory(files) == expected)
  }

  @Test(arguments: [
    ("A", "A", true),
    ("A/include", "A", true),
    ("AB", "A", false),
    ("B", "A", false),
    ("", "A", false),
    ("B/include", "", false), // the package root (`""`) is the caller's special case
    ("", "", true),
  ])
  func isInside(path: String, directory: String, expected: Bool) {
    #expect(ZipBuilder.isInside(path, directory) == expected)
  }

  /// With sources in two top-level directories, the own directory is the package root, so even a
  /// search path under one of them counts.
  @Test func everySearchPathCountsWhenTheOwnDirectoryIsThePackageRoot() throws {
    let package = try SyntheticPackage()
    try package.write("A/include/extra.h", "#define EXTRA 1\n")
    var plan = SyntheticPackage.plan
    plan.frameworks[1].settings["HEADER_SEARCH_PATHS"] = ["A/include"] // A's own directory: `A`
    plan.frameworks[2].settings["HEADER_SEARCH_PATHS"] = ["A/include"]
    plan.frameworks[2].sources.append(Source(path: "A/a.m")) // C's own directory: the root
    let before = try package.fingerprints(plan)

    try package.append("A/include/extra.h", "// changed\n")
    let after = try package.fingerprints(plan)
    #expect(after["C"] != before["C"])
    #expect(after["A"] == before["A"]) // `A/include` is inside A's own directory
  }
}
