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
    #expect(report.changedFiles.map(\.path) == ["NOTICES", "A/Tool.bundle", "A/run"])
    #expect(report.files.added == ["New.txt"] && report.files.removed == ["Gone.txt"])
    #expect(report.changed.isEmpty)
    // Text files come with their diff; a directory is listed by name only.
    #expect(report.changedFiles[0].diff?.contains("-old notices") == true)
    #expect(report.changedFiles[1].diff == nil)
    #expect(report.changedFiles[2].diff == """
    --- a/A/run
    +++ b/A/run
    @@ -1 +1 @@
    -#!/bin/sh
    +#!/bin/zsh

    """)
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
    #expect(bumped.changedFiles.map(\.path) == ["NOTICES"])

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
    #expect(more.changedFiles.map(\.path) == ["METADATA.md"])
    #expect(more.changedFiles[0].diff?.contains("+New  | 2.0.0") == true)

    // Without a release version bump (one framework's update), the version change counts.
    let single = try await diffFakes({
      try $0.addFile("METADATA.md", metadata("1.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("1.0.0"))
    }, {
      try $0.addFile("METADATA.md", metadata("2.0.0"))
      try $0.addXCFramework("Core", in: "A", slices: slices("2.0.0"))
    })
    #expect(single.releaseVersion == nil)
    #expect(single.changedFiles.map(\.path) == ["METADATA.md"])
  }

  /// Notices with one license replaced: Old's entry became New's.
  private func changedNotices() async throws -> DiffReport {
    try await diffFakes({
      try $0.addFile("NOTICES", "Core\n\nApache\n\nOld\n\nMIT\n")
      try $0.addFile("Old.txt")
    }, {
      try $0.addFile("NOTICES", "Core\n\nApache\n\nNew\n\nMIT\n")
    })
  }

  private let noticesDiff = """
  --- a/NOTICES
  +++ b/NOTICES
  @@ -2,6 +2,6 @@
   \("")
   Apache
   \("")
  -Old
  +New
   \("")
   MIT
  """

  @Test func rendersChangedFilesWithTheirDiffInText() async throws {
    let text = try await renderText(changedNotices())
    let indented = noticesDiff.split(separator: "\n", omittingEmptySubsequences: false)
      .map { "    " + $0 }.joined(separator: "\n")
    #expect(text.hasSuffix("""
    Loose files: 0 added, 1 removed
      - Old.txt
    Changed loose files: 1
      ~ NOTICES
    \(indented)
    """))
  }

  @Test func rendersChangedFilesWithTheirDiffInMarkdown() async throws {
    let report = try await changedNotices()
    let section = """

    ### Changed loose files

    <details><summary>NOTICES</summary>

    ```diff
    \(noticesDiff)
    ```

    </details>

    """
    let comment = renderGitHubComment(report, title: "### Zip diff")
    #expect(comment.contains("| Loose files removed | 1 |\n| Loose files changed | 1 |\n"))
    // The layout lists the file; its diff follows, collapsed.
    #expect(comment.contains("Changed loose files: 1\n  ~ NOTICES\n```\n" + section))
    #expect(comment.hasSuffix("</details>\n\n</details>\n"))
    #expect(renderMarkdown(report).hasSuffix("```\n" + section))
  }

  @Test func rendersChangedFilesWithTheirDiffInJSON() async throws {
    let report = try await changedNotices()
    let json = try renderJSON(report)
    #expect(json.contains(#""path" : "NOTICES""#))
    #expect(json.contains(#"-Old\n+New"#))
    #expect(try JSONDecoder().decode(DiffReport.self, from: Data(json.utf8)) == report)
  }

  /// Binaries and directories have no diff, so every format lists them by name only.
  @Test func nonTextFilesAreListedByNameOnly() async throws {
    let report = try await diffFakes({
      try $0.addFile("A/Tool.bundle/data", "1")
      try $0.addXCFramework("Core", in: "A")
      try $0.addFile("nul.bin", "a\u{0}b")
      try Data([0xFF, 0xFE, 0x41]).write(to: URL(fileURLWithPath: $0.root + "/latin1.txt"))
      try $0.addFile("half.txt", "text")
    }, {
      try $0.addFile("A/Tool.bundle/data", "2")
      try $0.addXCFramework("Core", in: "A")
      try $0.addFile("nul.bin", "a\u{0}c")
      try Data([0xFF, 0xFE, 0x42]).write(to: URL(fileURLWithPath: $0.root + "/latin1.txt"))
      try $0.addFile("half.txt", "binary\u{0}") // text on one side only
    })
    #expect(report.changedFiles.map(\.path).sorted()
      == ["A/Tool.bundle", "half.txt", "latin1.txt", "nul.bin"])
    #expect(report.changedFiles.allSatisfy { $0.diff == nil })
    #expect(renderText(report).hasSuffix("""
    Changed loose files: 4
      ~ half.txt
      ~ latin1.txt
      ~ nul.bin
      ~ A/Tool.bundle
    """))
    #expect(!renderGitHubComment(report).contains("<summary>half.txt"))
    #expect(!renderGitHubComment(report).contains("### Changed loose files"))
    #expect(try !renderJSON(report).contains(#""diff""#))
  }

  /// A long diff shows its first lines in Markdown, and all of them in text.
  @Test func markdownCapsEachFileDiff() async throws {
    let lines = markdownLinesPerFileDiff + 50
    let report = try await diffFakes({
      try $0.addFile("NOTICES", (0 ..< lines).map { "old \($0)\n" }.joined())
    }, {
      try $0.addFile("NOTICES", (0 ..< lines).map { "new \($0)\n" }.joined())
    })
    // The headers, the hunk header, and every line removed and added.
    let diffLines = 3 + 2 * lines
    let markdown = renderMarkdown(report)
    #expect(markdown.contains("\n… \(diffLines - markdownLinesPerFileDiff) more lines in the "
        + "text report\n```\n"))
    #expect(!markdown.contains("+new \(lines - 1)\n"))
    #expect(renderText(report).hasSuffix("+new \(lines - 1)"))
  }

  /// File diffs share the comment's size limit with the framework sections, and come first.
  @Test func fileDiffsStayUnderTheCommentLimit() async throws {
    let line = String(repeating: "x", count: 100)
    let report = try await diffFakes({ fake in
      for index in 0 ..< 5 {
        try fake.addFile("file\(index).txt", (0 ..< 200).map { "\(line) old \($0)\n" }.joined())
      }
    }, { fake in
      for index in 0 ..< 5 {
        try fake.addFile("file\(index).txt", (0 ..< 200).map { "\(line) new \($0)\n" }.joined())
      }
    })
    let comment = renderGitHubComment(report, limit: 60000)
    #expect(comment.utf8.count <= 60000)
    #expect(comment.contains("<summary>file0.txt</summary>"))
    #expect(!comment.contains("<summary>file4.txt</summary>"))
    #expect(comment.contains(" more loose file diffs are not shown, to stay under GitHub's "
        + "comment size limit."))
    #expect(comment.hasSuffix("\n</details>\n"))
  }

  /// A Markdown file's own fences can't close the block its diff is in.
  @Test func markdownFencesOutlastTheFilesOwn() async throws {
    let report = try await diffFakes({ try $0.addFile("README.md", "Run:\n```\nold\n```\n") },
                                     { try $0.addFile("README.md", "Run:\n```\nnew\n```\n") })
    let markdown = renderMarkdown(report)
    #expect(markdown.contains("<summary>README.md</summary>\n\n````diff\n"))
    #expect(markdown.contains("\n ```\n````\n"))
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
