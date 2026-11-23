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
import Testing
@testable import ZipBuilder

/// A temporary directory tree; `path(_:)` makes absolute paths in it.
private struct Tree {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-tests/licenses/\(UUID().uuidString)")

  init(_ files: [String]) throws {
    for file in files {
      let url = root.appendingPathComponent(file)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                              withIntermediateDirectories: true)
      try Data(file.utf8).write(to: url)
    }
  }

  func path(_ relative: String = "") throws -> AbsolutePath {
    try AbsolutePath(validating: root.appendingPathComponent(relative).standardizedFileURL.path)
  }
}

struct LicensesTests {
  @Test func nearestLicenseFileWinsUpToTheRoot() throws {
    let tree = try Tree(["LICENSE", "Product/LICENSE.txt", "Product/Sources/a.m", "Other/b.m"])
    // In a parent of the target directory, the nearest one.
    #expect(try nearestLicenseFile(from: tree.path("Product/Sources"), upTo: tree.path())
      == tree.path("Product/LICENSE.txt"))
    // Else the package root's.
    #expect(try nearestLicenseFile(from: tree.path("Other"), upTo: tree.path())
      == tree.path("LICENSE"))
    // The root itself is included.
    #expect(try nearestLicenseFile(from: tree.path(), upTo: tree.path()) == tree.path("LICENSE"))
  }

  @Test func walkStopsAtTheRoot() throws {
    // A license above the package root belongs to something else.
    let tree = try Tree(["LICENSE", "Package/Sources/a.m"])
    #expect(try nearestLicenseFile(from: tree.path("Package/Sources"), upTo: tree.path("Package"))
      == nil)
    // A directory outside the root only looks in the root.
    let outside = try Tree(["Package/COPYING", "Elsewhere/LICENSE"])
    #expect(try nearestLicenseFile(from: outside.path("Elsewhere"), upTo: outside.path("Package"))
      == outside.path("Package/COPYING"))
  }

  @Test func namesMatchIgnoringCaseInListOrder() throws {
    let tree = try Tree(["One/copying", "One/License.md", "Two/COPYING", "Two/license.txt",
                         "Three/LICENSE.rtf", "Three/LICENSES/a", "Four/NOTICE"])
    // The earliest name in `licenseFileNames` wins, whatever the case.
    #expect(try licenseFile(in: tree.path("One")) == tree.path("One/License.md"))
    #expect(try licenseFile(in: tree.path("Two")) == tree.path("Two/license.txt"))
    // Other names and extensions don't count.
    #expect(try licenseFile(in: tree.path("Three")) == nil)
    #expect(try licenseFile(in: tree.path("Four")) == nil)
    #expect(try licenseFile(in: tree.path("Missing")) == nil)
  }

  @Test func directoriesNamedLikeLicensesDontCount() throws {
    let tree = try Tree(["Package/LICENSE/a.txt", "Package/COPYING"])
    #expect(try licenseFile(in: tree.path("Package")) == tree.path("Package/COPYING"))
  }

  @Test func fixturePlanRecordsNearestLicenses() async throws {
    let plan = try await MiniPackage.plan()
    // Every target is under Sources/, which has its own license; the binary target has no
    // source directory, so it gets the package root's.
    for framework in plan.frameworks {
      #expect(framework.licenses == ["Sources/LICENSE.txt"], "\(framework.name)")
    }
    #expect(plan.binaries.map(\.licenses) == [["LICENSE"]])
    // Tests/LICENSE sits next to the test target, which no product ships.
    let all = plan.frameworks.compactMap(\.licenses) + plan.binaries.compactMap(\.licenses)
    #expect(!all.joined().contains { $0.hasPrefix("Tests/") })
  }

  @Test func mergingAndAggregatingUnionLicenses() async throws {
    let plan = try await MiniPackage.customizedPlan(#""frameworks": { "aggregate": ["Mini"] }"#)
    // Every part had the same license, so the aggregate lists it once.
    #expect(try plan.framework("Mini").licenses == ["Sources/LICENSE.txt"])

    var parent = SyntheticPackage.framework("A")
    parent.licenses = ["b/LICENSE", "a/LICENSE"]
    var companion = SyntheticPackage.framework("B")
    companion.licenses = ["a/LICENSE", "c/COPYING"]
    parent.absorb(companion, onlyOn: nil)
    #expect(parent.licenses == ["a/LICENSE", "b/LICENSE", "c/COPYING"])

    var bare = SyntheticPackage.framework("C")
    bare.absorb(SyntheticPackage.framework("D"), onlyOn: nil)
    #expect(bare.licenses == nil)
  }

  @Test func licensesDontChangeFingerprints() throws {
    let package = try SyntheticPackage()
    var plan = SyntheticPackage.plan
    let before = try package.fingerprints(plan)
    for index in plan.frameworks.indices {
      plan.frameworks[index].licenses = ["LICENSE"]
    }
    plan.binaries[0].licenses = ["Bin/LICENSE"]
    #expect(try package.fingerprints(plan) == before)
  }

  @Test func planJSONOmitsMissingLicenses() throws {
    var plan = SyntheticPackage.plan
    #expect(try !String(decoding: plan.json(), as: UTF8.self).contains("licenses"))
    plan.frameworks[0].licenses = ["LICENSE"]
    let json = try String(decoding: plan.json(), as: UTF8.self)
    #expect(json.contains("\"licenses\" : [\n        \"LICENSE\"\n      ]"))
    // A plan written before licenses existed still reads.
    #expect(try JSONDecoder().decode(Plan.self, from: SyntheticPackage.plan.json())
      == SyntheticPackage.plan)
  }
}
