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

/// Loose files (`NOTICES`, `METADATA.md`, a folder's scripts) are compared by contents too.
struct DiffLooseFilesTests {
  /// Device and simulator slices with this `CFBundleShortVersionString`.
  private func slices(_ version: String) -> [FakeSlice] {
    [FakeSlice.device, FakeSlice.simulator].map { slice in
      var slice = slice
      slice.version = version
      return slice
    }
  }

  @Test func reportsLooseFilesWhoseContentsChanged() async throws {
    let report = try await diffFakes({
      try $0.addFile("NOTICES", "old notices")
      try $0.addFile("README.md", "same")
      try $0.addFile("Gone.txt")
      try $0.addFile("A/run", "#!/bin/sh\n")
      try $0.addFile("A/Tool.bundle/data", "1")
      try $0.addXCFramework("Core", in: "A")
    }, {
      try $0.addFile("NOTICES", "new notices")
      try $0.addFile("README.md", "same")
      try $0.addFile("New.txt")
      try $0.addFile("A/run", "#!/bin/zsh\n")
      try $0.addFile("A/Tool.bundle/data", "2") // a directory, by its files' contents
      try $0.addXCFramework("Core", in: "A")
    })
    #expect(report.changedFiles == ["NOTICES", "A/Tool.bundle", "A/run"])
    #expect(report.files.added == ["New.txt"] && report.files.removed == ["Gone.txt"])
    #expect(report.changed.isEmpty)
  }

  @Test func aChangedFileAloneIsADifference() async throws {
    let report = try await diffFakes({ try $0.addFile("NOTICES", "a") },
                                     { try $0.addFile("NOTICES", "b") })
    #expect(report.hasLayoutOrFrameworkChanges && !report.isEmpty)
    let same = try await diffFakes({ try $0.addFile("NOTICES", "a") },
                                   { try $0.addFile("NOTICES", "a") })
    #expect(same.isEmpty)
  }

  /// `METADATA.md` lists the release version, so a bump alone doesn't list it as changed.
  @Test func aReleaseVersionBumpExplainsTextChanges() async throws {
    let metadata = { (version: String) in "Core | \(version)\nAuth | \(version)\nDep  | 5.0.0\n" }
    let bumped = try await diffFakes({
      try $0.addFile("METADATA.md", metadata("1.0.0"))
      try $0.addFile("NOTICES", "notices")
      try $0.addXCFramework("Auth", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
    }, {
      try $0.addFile("METADATA.md", metadata("2.0.0"))
      try $0.addFile("NOTICES", "notices, changed")
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
    })
    #expect(bumped.releaseVersion?.to == "2.0.0")
    #expect(bumped.changedFiles == ["NOTICES"])

    // Anything else that changed in it still counts.
    let more = try await diffFakes({
      try $0.addFile("METADATA.md", metadata("1.0.0"))
      try $0.addXCFramework("Auth", in: "A", slices: slices("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
    }, {
      try $0.addFile("METADATA.md", metadata("2.0.0") + "New  | 2.0.0\n")
      try $0.addXCFramework("Auth", in: "A", slices: slices("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
    })
    #expect(more.changedFiles == ["METADATA.md"])

    // Without a release version bump (one framework's update), the version change counts.
    let single = try await diffFakes({
      try $0.addFile("METADATA.md", metadata("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
    }, {
      try $0.addFile("METADATA.md", metadata("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
    })
    #expect(single.releaseVersion == nil)
    #expect(single.changedFiles == ["METADATA.md"])
  }

  @Test func rendersChangedFilesInEveryFormat() async throws {
    let report = try await diffFakes({
      try $0.addFile("NOTICES", "a")
      try $0.addFile("Old.txt")
    }, {
      try $0.addFile("NOTICES", "b")
    })
    let text = renderText(report)
    #expect(text.contains("Loose files: 0 added, 1 removed\n  - Old.txt\n"
        + "Changed loose files: 1\n  ~ NOTICES"))
    let comment = renderGitHubComment(report, title: "### Zip diff")
    #expect(comment.contains("| Loose files removed | 1 |\n| Loose files changed | 1 |\n"))
    #expect(comment.contains("Changed loose files: 1\n  ~ NOTICES\n```"))
    #expect(try renderJSON(report).contains("\"changedFiles\" : [\n    \"NOTICES\"\n  ]"))
  }

  @Test func markdownListsAtMostTheLayoutLimit() async throws {
    let count = markdownLayoutItemsPerSection + 2
    let report = try await diffFakes({ fake in
      for index in 0 ..< count {
        try fake.addFile("file\(index).txt", "a")
      }
    }, { fake in
      for index in 0 ..< count {
        try fake.addFile("file\(index).txt", "b")
      }
    })
    #expect(report.changedFiles.count == count)
    #expect(renderMarkdown(report).contains("  … and 2 more"))
    #expect(!renderText(report).contains("… and"))
  }
}
