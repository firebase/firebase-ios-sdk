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

/// How many lines a framework's Markdown section shows, so more frameworks fit in a PR comment.
let markdownLinesPerFramework = 40

/// How many items each Markdown layout section (folders, frameworks, moves, loose files) lists.
let markdownLayoutItemsPerSection = 100

/// How many lines of a changed loose file's diff the Markdown shows. Enough for a typical
/// license change in the notices, while one file can't take the whole comment.
let markdownLinesPerFileDiff = 300

/// A difference as a heading line and its detail lines.
func describe(_ difference: Difference) -> (heading: String, lines: [String]) {
  let slices = difference.slices.isEmpty ? "" : " [\(difference.slices.joined(separator: ", "))]"
  if let before = difference.before, let after = difference.after {
    return ("\(difference.title)\(slices): \(before) → \(after)", [])
  }
  let changes = difference.changes
  var lines = changes.removed.map { "- " + $0 } + changes.added.map { "+ " + $0 }
  let hidden = difference.addedCount + difference.removedCount - lines.count
  if hidden > 0 {
    lines.append("… and \(hidden) more")
  }
  return ("\(difference.title)\(slices): +\(difference.addedCount) -\(difference.removedCount)",
          lines)
}

private func frameworkLines(_ framework: FrameworkDiff) -> [String] {
  framework.differences.flatMap { difference in
    let (heading, lines) = describe(difference)
    return [heading] + lines.map { "    " + $0 }
  }
}

/// Folder, framework and loose-file changes, as list lines. With `diffs`, each changed text
/// file's diff follows its line, indented.
private func layoutLines(_ report: DiffReport, limit: Int = .max,
                         diffs: Bool = false) -> [String] {
  var lines: [String] = []
  func list(_ items: [String]) {
    lines += items.prefix(limit)
    if items.count > limit {
      lines.append("  … and \(items.count - limit) more")
    }
  }
  func section(_ title: String, _ changes: Changes) {
    guard !changes.isEmpty else { return }
    lines.append("\(title): \(changes.added.count) added, \(changes.removed.count) removed")
    list(changes.removed.map { "  - " + $0 } + changes.added.map { "  + " + $0 })
  }
  section("Folders", report.folders)
  section("Frameworks", report.frameworks)
  if !report.moved.isEmpty {
    lines.append("Moved frameworks: \(report.moved.count)")
    lines += report.moved.prefix(limit).map {
      "  ~ \($0.framework): \($0.from.joined(separator: ", ")) → \($0.to.joined(separator: ", "))"
    }
  }
  section("Loose files", report.files)
  if !report.changedFiles.isEmpty {
    lines.append("Changed loose files: \(report.changedFiles.count)")
    if diffs {
      for file in report.changedFiles {
        lines.append("  ~ " + file.path)
        lines += diffLines(file.diff).map { "    " + $0 }
      }
    } else {
      list(report.changedFiles.map { "  ~ " + $0.path })
    }
  }
  return lines
}

/// A unified diff's lines, without the empty one after its final newline.
private func diffLines(_ diff: String?) -> [String] {
  guard let diff, !diff.isEmpty else { return [] }
  var lines = diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
  if lines.last == "" {
    lines.removeLast()
  }
  return lines
}

func renderText(_ report: DiffReport) -> String {
  var lines = ["Baseline:  \(report.baseline)", "Candidate: \(report.candidate)"]
  if !report.symbolsCompared {
    lines.append("Exported symbols: not compared (--no-symbols)")
  }
  lines.append("")
  guard !report.isEmpty else { return (lines + ["No differences."]).joined(separator: "\n") }
  if let version = report.releaseVersion {
    lines.append("Release version: \(version.from) → \(version.to) "
      + "(\(frameworkCount(version.frameworks)))")
  }
  lines += layoutLines(report, diffs: true)
  if !report.changed.isEmpty {
    lines.append("Changed frameworks: \(report.changed.count)")
    for framework in report.changed {
      lines.append("  \(framework.name) (\(framework.folder))")
      lines += frameworkLines(framework).map { "    " + $0 }
    }
  }
  return lines.joined(separator: "\n")
}

private func frameworkCount(_ count: Int) -> String {
  count == 1 ? "1 framework" : "\(count) frameworks"
}

/// The most bytes a Markdown report or comment takes, under GitHub's 65,536-character comment
/// limit with room to spare.
let markdownByteLimit = 60000

/// Markdown for a PR comment: `title`, the distributions, the summary, then the details. Sections
/// that don't fit in `limit` bytes are left out, with a note.
func renderMarkdown(_ report: DiffReport, title: String? = nil,
                    limit: Int = markdownByteLimit) -> String {
  var text = titleLines(title) + "## Distribution diff\n\n" + markdownSources(report)
  guard !report.isEmpty else { return text + "No differences.\n" }
  text += markdownSummary(report)
  return text + markdownDetails(report, limit: limit - text.utf8.count)
}

/// A PR comment: `title`, then a match line, or the summary with the details collapsed. At most
/// `limit` bytes, title included, like `renderMarkdown`.
func renderGitHubComment(_ report: DiffReport, title: String? = nil,
                         limit: Int = markdownByteLimit) -> String {
  var text = titleLines(title)
  guard !report.isEmpty else {
    let note = report.symbolsCompared ? "" : "\n" + symbolsNotComparedNote
    return text + "✅ The distributions match.\n" + note
  }
  text += markdownSummary(report) + "\n<details><summary>Details</summary>\n\n"
    + markdownSources(report)
  let end = "\n</details>\n"
  return text + markdownDetails(report, limit: limit - text.utf8.count - end.utf8.count) + end
}

private let symbolsNotComparedNote = "Exported symbols were not compared (`--no-symbols`).\n"

private func titleLines(_ title: String?) -> String {
  title.map { $0 + "\n\n" } ?? ""
}

/// The two distributions' paths, and whether symbols were compared.
private func markdownSources(_ report: DiffReport) -> String {
  "Baseline: `\(report.baseline)`  \nCandidate: `\(report.candidate)`\n\n"
    + (report.symbolsCompared ? "" : symbolsNotComparedNote + "\n")
}

/// The release version change, then a table of counts when anything else changed.
private func markdownSummary(_ report: DiffReport) -> String {
  var text = ""
  if let version = report.releaseVersion {
    text += "Release version: `\(version.from)` → `\(version.to)` "
      + "(\(frameworkCount(version.frameworks)))\n"
  }
  guard report.hasLayoutOrFrameworkChanges else { return text }
  if !text.isEmpty {
    text += "\n"
  }
  let rows = [("Folders added", report.folders.added.count),
              ("Folders removed", report.folders.removed.count),
              ("Frameworks added", report.frameworks.added.count),
              ("Frameworks removed", report.frameworks.removed.count),
              ("Frameworks moved", report.moved.count),
              ("Frameworks changed", report.changed.count),
              ("Loose files added", report.files.added.count),
              ("Loose files removed", report.files.removed.count),
              ("Loose files changed", report.changedFiles.count)]
  return text + "| Change | Count |\n|---|---:|\n" + rows.map { "| \($0.0) | \($0.1) |\n" }.joined()
}

/// The layout changes, then one collapsible section per changed text file's diff, each at most
/// `markdownLinesPerFileDiff` lines, then one per changed framework, each at most
/// `markdownLinesPerFramework` lines, while they fit in `limit` bytes.
private func markdownDetails(_ report: DiffReport, limit: Int) -> String {
  var text = ""
  let layout = layoutLines(report, limit: markdownLayoutItemsPerSection)
  if !layout.isEmpty {
    text += "\n```text\n" + layout.joined(separator: "\n") + "\n```\n"
  }

  // File diffs come first: there are few loose files, and a change to one (the license
  // notices) is easy to miss among framework details. Each heading goes with its first
  // section, so it's left out when nothing under it fits.
  var fileSections = report.changedFiles.compactMap { file in
    file.diff.map { markdownSection(path: file.path, diff: $0) }
  }
  if !fileSections.isEmpty {
    fileSections[0] = "\n### Changed loose files\n\n" + fileSections[0]
  }
  var frameworkSections = report.changed.map(markdownSection)
  if !frameworkSections.isEmpty {
    frameworkSections[0] = "\n### Changed frameworks\n\n" + frameworkSections[0]
  }

  // Adds sections until the next one wouldn't fit. The note's room is always kept, even for the
  // last section.
  let sections = fileSections + frameworkSections
  for (index, section) in sections.enumerated() {
    let note = omittedSectionsNote(files: max(fileSections.count - index, 0),
                                   frameworks: min(frameworkSections.count,
                                                   sections.count - index))
    guard text.utf8.count + section.utf8.count + note.utf8.count <= limit else {
      return text + note
    }
    text += section
  }
  return text
}

/// The note for the sections that didn't fit, naming how many of each kind are left out.
private func omittedSectionsNote(files: Int, frameworks: Int) -> String {
  let counts = [(files, "loose file diffs"), (frameworks, "changed frameworks")]
  let omitted = counts.filter { $0.0 > 0 }.map { "\($0.0) more \($0.1)" }
  return "\n_\(omitted.joined(separator: " and ")) are not shown, to stay under GitHub's "
    + "comment size limit. Run `diff --format text` for the full report._\n"
}

/// A collapsible section holding a changed file's diff, at most `markdownLinesPerFileDiff`
/// lines.
private func markdownSection(path: String, diff: String) -> String {
  var lines = diffLines(diff)
  if lines.count > markdownLinesPerFileDiff {
    let hidden = lines.count - markdownLinesPerFileDiff
    lines = Array(lines.prefix(markdownLinesPerFileDiff))
    lines.append("… \(hidden) more lines in the text report")
  }
  // A fence longer than any run of backticks in the diff, so a Markdown file's own fences
  // (context lines start with a space, which a closing fence allows) can't end the block.
  let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: lines) + 1))
  return "<details><summary>\(path)</summary>\n\n\(fence)diff\n"
    + lines.joined(separator: "\n") + "\n\(fence)\n\n</details>\n"
}

/// The length of the longest run of consecutive backticks in `lines`.
private func longestBacktickRun(in lines: [String]) -> Int {
  var longest = 0
  for line in lines {
    var run = 0
    for character in line {
      run = character == "`" ? run + 1 : 0
      longest = max(longest, run)
    }
  }
  return longest
}

/// A collapsible section: the difference titles as its summary, then at most
/// `markdownLinesPerFramework` lines.
private func markdownSection(_ framework: FrameworkDiff) -> String {
  let titles = Set(framework.differences.map(\.title)).sorted()
  var lines = frameworkLines(framework)
  if lines.count > markdownLinesPerFramework {
    let hidden = lines.count - markdownLinesPerFramework
    lines = Array(lines.prefix(markdownLinesPerFramework))
    lines.append("… \(hidden) more lines in the text report")
  }
  return "<details><summary><b>\(framework.name)</b> (\(framework.folder)): "
    + titles.joined(separator: ", ") + "</summary>\n\n```text\n"
    + lines.joined(separator: "\n") + "\n```\n\n</details>\n"
}

func renderJSON(_ report: DiffReport) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  return try String(decoding: encoder.encode(report), as: UTF8.self)
}
