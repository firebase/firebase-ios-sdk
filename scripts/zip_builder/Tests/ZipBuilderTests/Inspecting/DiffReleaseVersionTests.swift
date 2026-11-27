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

import ArgumentParser
import Foundation
import Testing
@testable import ZipBuilder

/// A release version bump shared by every framework whose version changed is reported once.
struct DiffReleaseVersionTests {
  /// Device and simulator slices with this `CFBundleShortVersionString` and `MinimumOSVersion`.
  private func slices(_ version: String, minimumOS: String = "100.0") -> [FakeSlice] {
    [FakeSlice.device, FakeSlice.simulator].map { slice in
      var slice = slice
      slice.version = version
      slice.minimumOS = minimumOS
      return slice
    }
  }

  /// Diffs a baseline of `Auth` and `Core` at 1.0.0 and `Dependency` at 5.0.0, all in `A`.
  private func diffFromRelease1(_ makeCandidate: (FakeDistribution) throws -> Void) async throws
    -> DiffReport {
    try await diffFakes({
      try $0.addXCFramework("Auth", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.0.0"))
    }, makeCandidate)
  }

  /// `Auth` and `Core` bumped to 2.0.0; the dependency keeps its version.
  private func bumpOnlyReport() async throws -> DiffReport {
    try await diffFromRelease1 {
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.0.0"))
    }
  }

  private func versionChange(_ before: String, _ after: String) -> Difference {
    Difference(category: .infoPlist, key: "CFBundleShortVersionString", before: before,
               after: after)
  }

  @Test func aSharedBumpIsOneChange() async throws {
    let report = try await bumpOnlyReport()
    #expect(report.releaseVersion == ReleaseVersionChange(from: "1.0.0", to: "2.0.0",
                                                          frameworks: 2))
    #expect(report.changed.isEmpty)
    #expect(!report.hasLayoutOrFrameworkChanges)
    #expect(!report.isEmpty)
  }

  @Test func aBumpAloneFailsExitCode() async throws {
    let baseline = try FakeDistribution(), candidate = try FakeDistribution()
    for name in ["Auth", "Core"] {
      try baseline.addXCFramework(name, in: "A", slices: slices("1.0.0"))
      try candidate.addXCFramework(name, in: "A", slices: slices("2.0.0"))
    }
    let output = (baseline.root as NSString).deletingLastPathComponent + "/report.txt"
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff", baseline.root, candidate.root, "--no-symbols", "--output", output, "--exit-code",
    ]) as? DiffCommand)
    let error = await #expect(throws: ExitCode.self) { try await command.run() }
    #expect(error?.rawValue == 1)
    #expect(try String(contentsOfFile: output, encoding: .utf8)
      .contains("Release version: 1.0.0 → 2.0.0 (2 frameworks)"))
  }

  @Test func differentBumpsStayPerFramework() async throws {
    let report = try await diffFromRelease1 {
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.1.0"))
    }
    #expect(report.releaseVersion == nil)
    #expect(report.changed == [
      FrameworkDiff(name: "Auth", folder: "A", differences: [versionChange("1.0.0", "2.0.0")]),
      FrameworkDiff(name: "Core", folder: "A", differences: [versionChange("1.0.0", "2.0.0")]),
      FrameworkDiff(name: "Dependency", folder: "A",
                    differences: [versionChange("5.0.0", "5.1.0")]),
    ])
  }

  @Test func otherInfoPlistChangesStay() async throws {
    let report = try await diffFromRelease1 {
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0", minimumOS: "15.0"))
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.0.0"))
    }
    #expect(report.releaseVersion == ReleaseVersionChange(from: "1.0.0", to: "2.0.0",
                                                          frameworks: 2))
    #expect(report.changed == [FrameworkDiff(name: "Core", folder: "A", differences: [
      Difference(category: .infoPlist, key: "MinimumOSVersion", before: "100.0", after: "15.0"),
    ])])
    // The version line comes first, then the table of the other changes.
    #expect(renderMarkdown(report)
      .contains("Release version: `1.0.0` → `2.0.0` (2 frameworks)\n\n| Change | Count |"))
  }

  /// One framework's bump, such as a dependency's update, isn't a release version change.
  @Test func aSingleFrameworksBumpStaysPerFramework() async throws {
    let report = try await diffFromRelease1 {
      try $0.addXCFramework("Auth", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.1.0"))
    }
    #expect(report.releaseVersion == nil)
    #expect(report.changed == [
      FrameworkDiff(name: "Dependency", folder: "A",
                    differences: [versionChange("5.0.0", "5.1.0")]),
    ])
  }

  @Test func aBumpInOnlySomeSlicesStaysPerFramework() async throws {
    var simulator = FakeSlice.simulator
    simulator.version = "1.0.0"
    var device = FakeSlice.device
    device.version = "2.0.0"
    let report = try await diffFromRelease1 {
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: [device, simulator])
      try $0.addXCFramework("Dependency", in: "A", slices: slices("5.0.0"))
    }
    #expect(report.releaseVersion == nil)
    #expect(report.changed.map(\.name) == ["Auth", "Core"])
  }

  @Test func aBumpAloneInEveryFormat() async throws {
    let report = try await bumpOnlyReport()

    let text = renderText(report)
    #expect(text.hasSuffix("\n\nRelease version: 1.0.0 → 2.0.0 (2 frameworks)"))
    #expect(!text.contains("No differences."))

    let markdown = renderMarkdown(report)
    #expect(markdown.hasSuffix("\n\nRelease version: `1.0.0` → `2.0.0` (2 frameworks)\n"))
    #expect(!markdown.contains("| Change | Count |"))

    let json = try renderJSON(report)
    #expect(json.contains("\"releaseVersion\" : {"))
    #expect(try JSONDecoder().decode(DiffReport.self, from: Data(json.utf8)) == report)

    let comment = renderGitHubComment(report, title: "## Zip diff")
    #expect(comment.hasPrefix(
      "## Zip diff\n\nRelease version: `1.0.0` → `2.0.0` (2 frameworks)\n\n<details>"
    ))
    #expect(!comment.contains("match"))
  }
}
