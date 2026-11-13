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

// `zip.notices`: the third-party license notices file at the zip root.
// See docs/how-it-works.md#licenses.

/// The text of the notices file: the license texts of every framework and binary the zip ships
/// (`Framework.licenses`, `Binary.licenses`, plus `config.extraLicenses`), and how many entries
/// (distinct license texts) it has. `makeZip` and the `notices` command both write this text.
/// Fails when a license file can't be read, or when an `extraLicenses` path doesn't exist, even
/// one for something this plan doesn't ship, so a typo shows up in a `--product` build too.
func notices(_ plan: Plan, _ config: Config.Notices,
             packageRoot: Path) throws -> (text: String, entryCount: Int) {
  for (name, paths) in config.extraLicenses.sorted(by: { $0.key < $1.key }) {
    for path in paths where !FileManager.default.fileExists(atPath: fullPath(path, packageRoot)) {
      throw ZipBuilderError(
        "zip.notices.extraLicenses: \(path) (for \(name)) doesn't exist in \(packageRoot)."
      )
    }
  }
  var texts: [Path: String] = [:] // each file is read once, though many frameworks share it
  let licenseTexts = try shippedLicenses(plan, extraLicenses: config.extraLicenses)
    .mapValues { paths in
      try paths.map { path in
        if let text = texts[path] {
          return text
        }
        let text = try licenseText(at: path, packageRoot: packageRoot)
        texts[path] = text
        return text
      }
    }
  let entries = noticeEntries(licenseTexts)
  return (render(entries), entries.count)
}

/// Renders the notices file from each shipped item's license texts, by its name in the zip.
///
/// Items with the same license text, ignoring leading and trailing whitespace, share one entry,
/// titled by their names, sorted, one per line; entries are ordered by their titles. Each entry
/// is the titles, a blank line, the trimmed license text, and two newlines. The whole file is
/// trimmed and ends with one newline. That's the layout of the notices file earlier releases
/// shipped.
func renderNotices(_ licenseTexts: [String: [String]]) -> String {
  render(noticeEntries(licenseTexts))
}

/// One entry of the notices file: the names of the items under it, one per line, and the
/// license text they share.
private typealias NoticeEntry = (titles: String, text: String)

/// The notices file's entries, in order (see `renderNotices`).
private func noticeEntries(_ licenseTexts: [String: [String]]) -> [NoticeEntry] {
  var namesByText: [String: [String]] = [:]
  for (name, texts) in licenseTexts {
    // Copies of one license often differ only in a leading blank line or a trailing newline.
    // An item with two such files is listed once.
    for text in Set(texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
      namesByText[text, default: []].append(name)
    }
  }
  return namesByText
    .map { text, names in (titles: names.sorted().joined(separator: "\n"), text: text) }
    // Two entries can't have the same titles and text; the text only orders an item with
    // several licenses whose entries have no other titles.
    .sorted { ($0.titles, $0.text) < ($1.titles, $1.text) }
}

private func render(_ entries: [NoticeEntry]) -> String {
  let body = entries.map { "\($0.titles)\n\n\($0.text)\n\n" }.joined()
  return body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
}

/// With `zip.notices`, warns about `extraLicenses` names the zip doesn't ship, and about shipped
/// frameworks and binaries that have no license, which the notices file would leave out.
/// `customize` calls it on the final plan, so `plan` shows these warnings.
func warnAboutMissingLicenses(_ plan: Plan, _ notices: Config.Notices) {
  warnAboutUnknown(notices.extraLicenses.keys, known: shippedNames(plan),
                   key: "zip.notices.extraLicenses", kind: "a shipped framework or binary")
  let licenses = shippedLicenses(plan, extraLicenses: notices.extraLicenses)
  for (name, paths) in licenses.sorted(by: { $0.key < $1.key }) where paths.isEmpty {
    warn("zip.notices: \(name) has no license file, so the notices leave it out; "
      + "add one in zip.notices.extraLicenses.")
  }
}

/// Each shipped framework's and binary's license files, by name: those planning found, then its
/// `extraLicenses`, without duplicates. Empty for one without any.
func shippedLicenses(_ plan: Plan, extraLicenses: [String: [Path]]) -> [String: [Path]] {
  let shipped = shippedNames(plan)
  let found = plan.frameworks.map { (name: $0.name, licenses: $0.licenses ?? []) }
    + plan.binaries.map { (name: $0.name, licenses: $0.licenses ?? []) }
  var result: [String: [Path]] = [:]
  for (name, licenses) in found where shipped.contains(name) {
    var seen = Set<Path>()
    result[name] = (licenses + (extraLicenses[name] ?? [])).filter { seen.insert($0).inserted }
  }
  return result
}

/// What the zip ships: the frameworks and binaries in its folders. With
/// `products.withoutDependencies`, the dependencies are built but in no folder, so they don't
/// ship and need no notice.
private func shippedNames(_ plan: Plan) -> Set<String> {
  Set(plan.folders.flatMap(\.frameworks))
}

/// The text of the license file at the package-root-relative `path`.
private func licenseText(at path: Path, packageRoot: Path) throws -> String {
  do {
    return try String(contentsOfFile: fullPath(path, packageRoot), encoding: .utf8)
  } catch {
    throw ZipBuilderError("zip.notices: can't read the license file \(path): "
      + error.localizedDescription)
  }
}
