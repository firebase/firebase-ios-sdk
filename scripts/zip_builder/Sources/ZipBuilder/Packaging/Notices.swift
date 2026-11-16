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
/// (see `shippedLicenses`), listed under their `config.titles`, and how many entries (distinct
/// license texts) it has. `makeZip` and the `notices` command both write this text. Fails when a
/// license file can't be read, or when a `licenses` or `extraLicenses` path doesn't exist, even
/// one for something this plan doesn't ship, so a typo shows up in a `--product` build too.
func notices(_ plan: Plan, _ config: Config.Notices,
             packageRoot: Path) throws -> (text: String, entryCount: Int) {
  try checkExistence(of: config.licenses, key: "zip.notices.licenses", packageRoot: packageRoot)
  try checkExistence(of: config.extraLicenses, key: "zip.notices.extraLicenses",
                     packageRoot: packageRoot)
  var texts: [Path: String] = [:] // each file is read once, though many frameworks share it
  let licenseTexts = try shippedLicenses(plan, config).mapValues { paths in
    try paths.map { path in
      if let text = texts[path] {
        return text
      }
      let text = try licenseText(at: path, packageRoot: packageRoot)
      texts[path] = text
      return text
    }
  }
  let entries = noticeEntries(listingUnderTitles(licenseTexts, config.titles), config.layout)
  return (render(entries, config.layout), entries.count)
}

/// Each item's license texts under the titles it's listed under (`zip.notices.titles`), else
/// under its own name. Items that share a title are listed once under it, with all their texts.
func listingUnderTitles(_ licenseTexts: [String: [String]],
                        _ titles: [String: [String]]) -> [String: [String]] {
  var textsByTitle: [String: [String]] = [:]
  for (name, texts) in licenseTexts {
    for title in titles[name] ?? [name] {
      textsByTitle[title, default: []] += texts
    }
  }
  return textsByTitle
}

/// Renders the notices file from license texts by title.
///
/// Titles with the same license text share one entry, titled by them, sorted, one per line;
/// entries are ordered by their titles. The whole file is trimmed and ends with one newline.
/// `layout` decides what counts as the same text and how an entry looks:
/// - `trimmed`: texts are compared and rendered with leading and trailing whitespace trimmed;
///   each entry is the titles, a blank line, the text, and two newlines.
/// - `verbatim`: only identical texts share an entry; each is the titles, a newline, the text as
///   is (a leading blank line included), and two newlines. That's how the CocoaPods-era
///   generator wrote CocoaPods' acknowledgements.
func renderNotices(_ licenseTexts: [String: [String]],
                   layout: NoticesLayout = .trimmed) -> String {
  render(noticeEntries(licenseTexts, layout), layout)
}

/// One entry of the notices file: its titles, one per line, and the license text they share.
private typealias NoticeEntry = (titles: String, text: String)

/// The notices file's entries, in order (see `renderNotices`).
private func noticeEntries(_ licenseTexts: [String: [String]],
                           _ layout: NoticesLayout) -> [NoticeEntry] {
  var titlesByText: [String: [String]] = [:]
  for (title, texts) in licenseTexts {
    // Copies of one license often differ only in a leading blank line or a trailing newline,
    // which `trimmed` ignores. A title with two copies of one text is listed once.
    let keys = switch layout {
    case .trimmed: texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    case .verbatim: texts
    }
    for text in Set(keys) {
      titlesByText[text, default: []].append(title)
    }
  }
  return titlesByText
    .map { text, titles in (titles: titles.sorted().joined(separator: "\n"), text: text) }
    // Two entries can't have the same titles and text; the text only orders a title with
    // several licenses whose entries have no other titles.
    .sorted { ($0.titles, $0.text) < ($1.titles, $1.text) }
}

private func render(_ entries: [NoticeEntry], _ layout: NoticesLayout) -> String {
  // A verbatim text keeps its own leading blank line, if it has one.
  let separator = layout == .trimmed ? "\n\n" : "\n"
  let body = entries.map { "\($0.titles)\(separator)\($0.text)\n\n" }.joined()
  return body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
}

/// Fails when a path of the config key `key` (name to package-root-relative paths) doesn't
/// exist.
private func checkExistence(of licenses: [String: [Path]], key: String,
                            packageRoot: Path) throws {
  for (name, paths) in licenses.sorted(by: { $0.key < $1.key }) {
    for path in paths where !FileManager.default.fileExists(atPath: fullPath(path, packageRoot)) {
      throw ZipBuilderError("\(key): \(path) (for \(name)) doesn't exist in \(packageRoot).")
    }
  }
}

/// With `zip.notices`, warns about `licenses`, `extraLicenses` and `titles` names the zip doesn't
/// ship, about shipped frameworks and binaries that have no license, and about ones listed under
/// no title, which the notices file would leave out. `customize` calls it on the final plan, so
/// `plan` shows these warnings.
func warnAboutMissingLicenses(_ plan: Plan, _ notices: Config.Notices) {
  let shipped = shippedNames(plan)
  let kind = "a shipped framework or binary"
  warnAboutUnknown(notices.licenses.keys, known: shipped, key: "zip.notices.licenses", kind: kind)
  warnAboutUnknown(notices.extraLicenses.keys, known: shipped, key: "zip.notices.extraLicenses",
                   kind: kind)
  warnAboutUnknown(notices.titles.keys, known: shipped, key: "zip.notices.titles", kind: kind)
  let licenses = shippedLicenses(plan, notices)
  for (name, paths) in licenses.sorted(by: { $0.key < $1.key }) where paths.isEmpty {
    warn("zip.notices: \(name) has no license file, so the notices leave it out; "
      + "add one in zip.notices.extraLicenses.")
  }
  for (name, titles) in notices.titles.sorted(by: { $0.key < $1.key })
    where titles.isEmpty && shipped.contains(name) {
    warn("zip.notices.titles: \(name) has no titles, so the notices leave it out.")
  }
}

/// Each shipped framework's and binary's license files, by name: its `licenses` entry, else
/// those planning found, then its `extraLicenses`, without duplicates. Empty for one without any.
func shippedLicenses(_ plan: Plan, _ config: Config.Notices) -> [String: [Path]] {
  let shipped = shippedNames(plan)
  let found = plan.frameworks.map { (name: $0.name, licenses: $0.licenses ?? []) }
    + plan.binaries.map { (name: $0.name, licenses: $0.licenses ?? []) }
  var result: [String: [Path]] = [:]
  for (name, licenses) in found where shipped.contains(name) {
    let chosen = config.licenses[name] ?? licenses
    var seen = Set<Path>()
    result[name] = (chosen + (config.extraLicenses[name] ?? [])).filter { seen.insert($0).inserted }
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
