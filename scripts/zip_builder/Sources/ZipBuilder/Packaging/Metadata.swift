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

/// `METADATA.md`: each folder's `.xcframework`s, the base folder first and the others marked
/// `(~> <base>)`, then a table of every framework's and binary's version. The text matches
/// earlier releases' `METADATA.md`.
func metadata(_ plan: Plan, baseFolder: String?) -> String {
  let folders = plan.folders.filter { $0.name != zipRootFolder }
  let base = folders.contains { $0.name == baseFolder } ? baseFolder : nil
  let ordered = folders.filter { $0.name == base } + folders.filter { $0.name != base }
  let sections = ordered.map { folder in
    let title = if let base, folder.name != base {
      "\(folder.name) (~> \(base))"
    } else {
      folder.name
    }
    return (["## \(title)"] + folder.frameworks.sorted().map { "- \($0).xcframework" })
      .joined(separator: "\n")
  }

  let versions = (plan.frameworks.map { (name: $0.name, version: $0.version) }
    + plan.binaries.map { (name: $0.name, version: $0.version) }).sorted { $0.name < $1.name }
  // The name column is one wider than the longest name, as in earlier releases.
  let width = max("Framework".count, versions.map(\.name.count).max() ?? 0) + 1
  let table = [
    centered("Framework", width: width) + "| Version",
    String(repeating: "-", count: width) + "|---------",
  ] + versions.map { name, version in
    name.padding(toLength: width, withPad: " ", startingAt: 0) + "| \(version)"
  }

  return """
  ## Dependency Graph

  "(~> X)" below means that the SDK requires all of the xcframeworks from X. You
  should make sure to include all of the xcframeworks from X when including the
  SDK.

  \(sections.joined(separator: "\n\n"))

  ## Versions

  The xcframeworks in this directory map to these versions of the Firebase SDKs in
  CocoaPods.

  \(table.joined(separator: "\n"))

  """
}

/// `text` centered in `width` columns; an odd extra space goes on the right.
private func centered(_ text: String, width: Int) -> String {
  let left = (width - text.count) / 2
  let right = width - text.count - left
  return String(repeating: " ", count: left) + text + String(repeating: " ", count: right)
}
