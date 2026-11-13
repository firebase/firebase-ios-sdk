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

/// A loose file both distributions have, with different contents.
struct ChangedFile: Codable, Equatable, Sendable {
  var path: String // under the distribution root: `NOTICES`, `FirebaseCrashlytics/run`
  /// The unified diff from the baseline to the candidate, when both sides are text; nil for
  /// other files and for directories (bundles), which are listed by name only.
  var diff: String?
}

/// The loose files both sides have whose contents differ (a directory's by its files'
/// contents), in the baseline's order, with a diff when both sides are text.
///
/// A text file whose only change is the release version bump, i.e. the candidate's text is the
/// baseline's with every occurrence of the old version replaced by the new one, is part of
/// `releaseVersion` and isn't listed, like the frameworks' versions: `METADATA.md` lists the
/// release version.
func changedLooseFiles(_ baseline: Distribution, _ candidate: Distribution,
                       releaseVersion: ReleaseVersionChange?) async throws -> [ChangedFile] {
  let candidateFiles = Set(looseFiles(candidate))
  var changed: [ChangedFile] = []
  for file in looseFiles(baseline) where candidateFiles.contains(file) {
    let old = baseline.root + "/" + file, new = candidate.root + "/" + file
    guard try contentHash(old) != contentHash(new) else { continue }
    let oldText = textContents(at: old), newText = textContents(at: new)
    if let version = releaseVersion, let oldText, let newText,
       oldText.replacingOccurrences(of: version.from, with: version.to) == newText {
      continue
    }
    let diff = oldText != nil && newText != nil
      ? try await unifiedDiff(from: old, to: new, labeled: file)
      : nil
    changed.append(ChangedFile(path: file, diff: diff))
  }
  return changed
}

/// The contents of the file at `path` when it's text: valid UTF-8 without NUL bytes. Nil for a
/// directory, a binary or an unreadable file.
func textContents(at path: Path) -> String? {
  guard !isDirectory(path), let data = FileManager.default.contents(atPath: path),
        !data.contains(0) else { return nil }
  return String(data: data, encoding: .utf8)
}

/// `diff -u` from the file at `old` to the one at `new`, with three lines of context, labeled
/// `a/<label>` and `b/<label>` as in git; empty when they're equal.
func unifiedDiff(from old: Path, to new: Path, labeled label: String) async throws -> String {
  let arguments = ["-u", "--label", "a/" + label, "--label", "b/" + label, old, new]
  let result = try await runTool("diff", arguments)
  // diff exits with 0 when the files are equal, 1 when they differ, and 2 on trouble.
  guard result.status <= 1 else {
    throw ShellError(commandLine: commandLine("diff", arguments), exitCode: result.status,
                     standardError: result.standardError)
  }
  return result.standardOutput
}
