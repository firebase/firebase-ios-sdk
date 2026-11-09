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

struct DiffCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "diff",
    abstract: "Compare two distributions."
  )

  enum Format: String, ExpressibleByArgument, CaseIterable {
    case text, markdown, json
    case githubComment = "github-comment"
  }

  @OptionGroup var logging: LoggingOptions

  @Argument(help: "The baseline distribution folder or zip.")
  var baseline: String

  @Argument(help: "The candidate distribution folder or zip.")
  var candidate: String

  @Option(help: "The report format.")
  var format = Format.text

  @Option(help: "A Markdown line to start the report with (markdown and github-comment only).")
  var title: String?

  @Option(help: "Write the report to this file instead of standard output.")
  var output: String?

  @Flag(help: "Don't compare exported symbols (the slow part).")
  var noSymbols = false

  @Flag(help: "Exit with status 1 when there are differences, after writing the report.")
  var exitCode = false

  func validate() throws {
    // An error rather than a warning, so a caller expecting a title never silently loses it.
    if title != nil, format == .text || format == .json {
      throw ValidationError("--title only applies to --format markdown and github-comment.")
    }
  }

  func run() async throws {
    logging.apply()
    // One after the other, so a failure never leaves the other side's unpacked zip behind.
    let old = try await readDistribution(at: baseline)
    defer { old.removeExtracted() }
    let new = try await readDistribution(at: candidate)
    defer { new.removeExtracted() }
    let report = try await diffDistributions(old, new, symbols: !noSymbols)
    let text = switch format {
    case .text: renderText(report)
    case .markdown: renderMarkdown(report, title: title)
    case .json: try renderJSON(report)
    case .githubComment: renderGitHubComment(report, title: title)
    }
    if let output {
      try (text + "\n").write(toFile: output, atomically: true, encoding: .utf8)
    } else {
      print(text)
    }
    if exitCode, !report.isEmpty {
      throw ExitCode.failure
    }
  }
}
