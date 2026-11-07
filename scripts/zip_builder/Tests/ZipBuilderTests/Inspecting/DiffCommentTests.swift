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

/// `diff --format github-comment` and `--title`.
struct DiffCommentTests {
  /// 500 changed frameworks of 50 added headers each: far more than a comment holds.
  private func largeReport() -> DiffReport {
    let difference = Difference(category: .headers,
                                changes: Changes([], (0 ..< 50).map { "Headers/H\($0).h" }),
                                addedCount: 50)
    var report = DiffReport(baseline: "a", candidate: "b", symbolsCompared: true)
    report.changed = (0 ..< 500).map {
      FrameworkDiff(name: "Framework\($0)", folder: "F", differences: [difference])
    }
    return report
  }

  @Test func noDifferencesIsTheTitleAndAMatchLine() async throws {
    let empty = DiffReport(baseline: "a", candidate: "b", symbolsCompared: true)
    #expect(renderGitHubComment(empty, title: "### Zip diff")
      == "### Zip diff\n\n✅ The distributions match.\n")
    #expect(renderGitHubComment(empty) == "✅ The distributions match.\n")

    // Without symbols, a match says so.
    let report = try await diffFakes({ try $0.addXCFramework("Core", in: "A") },
                                     { try $0.addXCFramework("Core", in: "A") })
    #expect(renderGitHubComment(report) == """
    ✅ The distributions match.

    Exported symbols were not compared (`--no-symbols`).

    """)
  }

  @Test func differencesAreTheSummaryThenCollapsedDetails() async throws {
    let comment = try await renderGitHubComment(sampleDiffReport(), title: "### Zip diff")
    #expect(comment.hasPrefix("### Zip diff\n\n| Change | Count |\n|---|---:|\n"))
    #expect(comment.contains("""
    | Loose files removed | 0 |

    <details><summary>Details</summary>

    Baseline: `
    """))
    #expect(comment.contains("Exported symbols were not compared (`--no-symbols`)."))
    #expect(comment.contains("Frameworks: 0 added, 1 removed\n  - A/Gone"))
    #expect(comment.contains("<details><summary><b>Core</b> (A): Headers"))
    #expect(comment.hasSuffix("</details>\n\n</details>\n"))
    #expect(!comment.contains("## Distribution diff"))
  }

  @Test func withoutATitleTheSummaryComesFirst() async throws {
    let comment = try await renderGitHubComment(sampleDiffReport())
    #expect(comment.hasPrefix("| Change | Count |"))
  }

  @Test func theCommentStaysUnderTheLimitWithItsTitle() {
    let report = largeReport()
    let title = "## " + String(repeating: "t", count: 500)
    let comment = renderGitHubComment(report, title: title)
    #expect(comment.utf8.count <= markdownByteLimit)
    #expect(comment.count < 65536) // GitHub's comment limit, in characters
    #expect(comment.hasPrefix(title + "\n\n| Change | Count |"))
    #expect(comment.contains("more changed frameworks are not shown"))
    #expect(comment.hasSuffix("\n</details>\n"))

    // The title counts toward the limit.
    let long = String(repeating: "t", count: 5000)
    #expect(renderGitHubComment(report, title: long, limit: 20000).utf8.count <= 20000)
    #expect(renderMarkdown(report, title: long, limit: 20000).utf8.count <= 20000)
  }

  @Test func markdownStartsWithTheTitle() async throws {
    let markdown = try await renderMarkdown(sampleDiffReport(), title: "**Zip diff**")
    #expect(markdown.hasPrefix("**Zip diff**\n\n## Distribution diff\n\nBaseline: `"))
    let untitled = try await renderMarkdown(sampleDiffReport())
    #expect(untitled.hasPrefix("## Distribution diff\n\n"))
  }

  @Test func titleIsOnlyForMarkdownFormats() throws {
    for format in ["markdown", "github-comment"] {
      let command = try #require(try ZipBuilderCommand.parseAsRoot([
        "diff", "a", "b", "--format", format, "--title", "Zip diff",
      ]) as? DiffCommand)
      #expect(command.title == "Zip diff")
    }
    for format in ["text", "json"] {
      #expect(throws: (any Error).self) {
        try ZipBuilderCommand.parseAsRoot([
          "diff", "a", "b", "--format", format, "--title", "Zip diff",
        ])
      }
    }
    #expect(throws: (any Error).self) {
      try ZipBuilderCommand.parseAsRoot(["diff", "a", "b", "--title", "Zip diff"])
    }
  }

  @Test func theCommandWritesTheCommentThenExits1() async throws {
    let baseline = try FakeDistribution(), candidate = try FakeDistribution()
    try baseline.addXCFramework("Core", in: "A")
    try candidate.addXCFramework("Core", in: "A")
    try candidate.addXCFramework("New", in: "B")
    let output = (baseline.root as NSString).deletingLastPathComponent + "/comment.md"
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff", baseline.root, candidate.root, "--no-symbols", "--format", "github-comment",
      "--title", "### Zip diff", "--output", output, "--exit-code",
    ]) as? DiffCommand)
    let error = await #expect(throws: ExitCode.self) { try await command.run() }
    #expect(error?.rawValue == 1)
    let comment = try String(contentsOfFile: output, encoding: .utf8)
    #expect(comment.hasPrefix("### Zip diff\n\n| Change | Count |"))
    #expect(comment.contains("B/New"))
  }
}
