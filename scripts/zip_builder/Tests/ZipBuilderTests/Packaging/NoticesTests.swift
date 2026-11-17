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

/// `zip.notices` with these keys.
private func notices(_ extraLicenses: [String: [Path]] = [:], licenses: [String: [Path]] = [:],
                     titles: [String: [String]] = [:],
                     layout: NoticesLayout = .trimmed) -> Config.Notices {
  Config.Notices(extraLicenses: Default(wrappedValue: extraLicenses),
                 licenses: Default(wrappedValue: licenses),
                 titles: Default(wrappedValue: titles), layout: Default(wrappedValue: layout))
}

/// SyntheticPackage's plan with licenses: A and B share `LICENSE`, `Bin` has its own, C has
/// none. A, B and Bin ship in folders; C ships nowhere.
private func licensedPlan() -> Plan {
  var plan = SyntheticPackage.plan
  plan.frameworks[0].licenses = ["LICENSE"] // B
  plan.frameworks[1].licenses = ["LICENSE"] // A
  plan.binaries[0].licenses = ["Bin/LICENSE"]
  plan.folders = [
    Folder(name: ".", frameworks: [], files: ["README.md"]),
    Folder(name: "Base", frameworks: ["A", "Bin"], files: []),
    Folder(name: "Other", frameworks: ["B"], files: []),
  ]
  return plan
}

struct NoticesTests {
  @Test func rendersOneEntryPerLicenseTextInTheLegacyLayout() {
    let text = renderNotices([
      "Zeta": ["\nApache\n"],
      // Leading blank lines and trailing whitespace don't make another license.
      "Alpha": ["Apache"],
      "Beta": ["MIT\n"],
      // Two license files: listed under both texts.
      "Gamma": ["MIT\n", "\n \nApache\n\n"],
    ])
    #expect(text == """
    Alpha
    Gamma
    Zeta

    Apache

    Beta
    Gamma

    MIT

    """)
  }

  @Test func ordersEntriesByTheirTitles() {
    // Upper case sorts before lower case, as in the legacy file (`GoogleUtilities`, `abseil`).
    let text = renderNotices(["abseil": ["A"], "GoogleUtilities": ["G"], "Core": ["C"],
                              "CoreExtras": ["X"]])
    #expect(text
      == "Core\n\nC\n\nCoreExtras\n\nX\n\nGoogleUtilities\n\nG\n\nabseil\n\nA\n")
    // Entries with the same first title follow the next titles.
    #expect(renderNotices(["A": ["one", "two"], "B": ["two"]]) == "A\n\none\n\nA\nB\n\ntwo\n")
  }

  @Test func trimsTheFileAndEndsWithOneNewline() {
    // Blank lines around the text go; the first line's indentation stays.
    #expect(renderNotices(["A": ["\n\n  text  \n\n\n"]]) == "A\n\n  text\n")
    // Inner whitespace is kept: it's part of the text.
    #expect(renderNotices(["A": ["one\n\n  two"], "B": ["one\ntwo"]])
      == "A\n\none\n\n  two\n\nB\n\none\ntwo\n")
    // Two files of one item with the same trimmed text make one entry.
    #expect(renderNotices(["A": ["same", "\nsame\n"]]) == "A\n\nsame\n")
    #expect(renderNotices([:]) == "\n")
  }

  @Test func onlyShippedItemsGetLicensesWithTheirExtras() {
    let licenses = shippedLicenses(licensedPlan(), notices([
      "A": ["LICENSE", "extra/A.txt"], // the duplicate is dropped
      "C": ["extra/C.txt"], // C isn't in a folder
    ]))
    #expect(licenses == ["A": ["LICENSE", "extra/A.txt"], "B": ["LICENSE"],
                         "Bin": ["Bin/LICENSE"]])
    var plan = licensedPlan()
    plan.binaries[0].licenses = nil
    #expect(shippedLicenses(plan, notices())["Bin"] == [])
  }

  @Test func readsEachLicenseFile() throws {
    let package = try SyntheticPackage()
    try package.write("LICENSE", "\nApache\n")
    try package.write("Bin/LICENSE", "Vendor\n")
    try package.write("extra/A.txt", "Extra\n")
    let notices = try ZipBuilder.notices(licensedPlan(), notices(["A": ["extra/A.txt"]]),
                                         packageRoot: package.root.path)
    #expect(notices.text == "A\n\nExtra\n\nA\nB\n\nApache\n\nBin\n\nVendor\n")
    #expect(notices.entryCount == 3)
  }

  @Test func aMissingLicenseFileFails() throws {
    let package = try SyntheticPackage()
    try package.write("LICENSE", "Apache\n")
    try package.write("Bin/LICENSE", "Vendor\n")
    // An extra license that doesn't exist fails, even for something this plan doesn't ship.
    let error = #expect(throws: ZipBuilderError.self) {
      try ZipBuilder.notices(licensedPlan(), notices(["C": ["missing.txt"]]),
                             packageRoot: package.root.path)
    }
    #expect(error?.description.contains("zip.notices.extraLicenses: missing.txt (for C)") == true)
    // So does a planned one that's gone (an edited plan).
    try FileManager.default.removeItem(at: package.root.appendingPathComponent("Bin/LICENSE"))
    #expect(throws: ZipBuilderError.self) {
      try ZipBuilder.notices(licensedPlan(), notices(), packageRoot: package.root.path)
    }
  }

  @Test func warnsAboutUnshippedExtrasAndMissingLicenses() async {
    var plan = licensedPlan()
    plan.frameworks[0].licenses = nil // B
    let (_, warnings) = await collectingWarnings {
      warnAboutMissingLicenses(plan, notices(["C": ["c.txt"], "Nope": ["n.txt"]]))
    }
    #expect(warnings == [
      "zip.notices.extraLicenses: C isn't a shipped framework or binary; skipped.",
      "zip.notices.extraLicenses: Nope isn't a shipped framework or binary; skipped.",
      "zip.notices: B has no license file, so the notices leave it out; "
        + "add one in zip.notices.extraLicenses.",
    ])
    // An extra license covers it.
    let covered = await collectingWarnings {
      warnAboutMissingLicenses(plan, notices(["B": ["b.txt"]]))
    }
    #expect(covered.warnings.isEmpty)
  }

  @Test func customizeWarnsOnlyWithNotices() async throws {
    let without = try await collectingWarnings { try await MiniPackage.customizedPlan("") }
    #expect(without.warnings.isEmpty)
    let with = try await collectingWarnings {
      try await MiniPackage.customizedPlan(#""zip": { "notices": { "extraLicenses": "#
        + #"{ "SwiftLibTests": ["LICENSE"], "CoreC": ["LICENSE"] } } }"#)
    }
    // Every fixture framework has a license; the test target never ships.
    #expect(with.warnings == [
      "zip.notices.extraLicenses: SwiftLibTests isn't a shipped framework or binary; skipped.",
    ])
    // Generating the file separately (`notices`) still checks the licenses while planning.
    let separate = try await collectingWarnings {
      try await MiniPackage.customizedPlan(#""zip": { "notices": { "atBuildTime": false, "#
        + #""extraLicenses": { "Nope": ["LICENSE"] } } }"#)
    }
    #expect(separate.warnings == [
      "zip.notices.extraLicenses: Nope isn't a shipped framework or binary; skipped.",
    ])
  }

  @Test func theDefaultLayoutIsTrimmed() {
    let texts = ["A": ["\nApache\n"], "B": ["Apache"]]
    #expect(renderNotices(texts) == renderNotices(texts, layout: .trimmed))
    #expect(renderNotices(texts) == "A\nB\n\nApache\n")
  }

  /// License files often center their first line; trimming drops only the blank lines around a
  /// text, so that indentation survives (and copies still group).
  @Test func theTrimmedLayoutKeepsTheFirstLinesIndentation() {
    let texts = ["A": ["\n  \n      Apache License\n  Version 2.0\n\n"],
                 "B": ["      Apache License\n  Version 2.0"]]
    #expect(renderNotices(texts) == "A\nB\n\n      Apache License\n  Version 2.0\n")
  }

  @Test func trimmingBlankLinesKeepsIndentationAndInnerBlankLines() {
    #expect(trimmingBlankLines("\n\n   Title\n\n Body  \n \n") == "   Title\n\n Body")
    #expect(trimmingBlankLines("No blank lines") == "No blank lines")
    #expect(trimmingBlankLines(" \n\t\n") == "")
    #expect(trimmingBlankLines("") == "")
  }

  @Test func theVerbatimLayoutGroupsByExactTextAndKeepsIt() {
    let text = renderNotices([
      // A leading blank line or an extra trailing newline makes another text.
      "Zeta": ["\nApache\n"],
      "Alpha": ["\nApache\n"],
      "Beta": ["Apache\n\n"],
      // Two copies of one text: listed once.
      "Gamma": ["MIT\n", "MIT\n"],
    ], layout: .verbatim)
    // Titles, a newline, the text as is, two newlines; the file is trimmed, plus one newline.
    #expect(text == "Alpha\nZeta\n\nApache\n\n\nBeta\nApache\n\n\n\nGamma\nMIT\n")
    #expect(renderNotices(["A": ["  one\n"]], layout: .verbatim) == "A\n  one\n")
    #expect(renderNotices([:], layout: .verbatim) == "\n")
  }

  @Test func theVerbatimLayoutMatchesTheLegacyGenerator() {
    // The legacy generator: `title + "\n" + license + "\n\n"` per entry, then `strip` and
    // one trailing newline. Entries follow their first title.
    let legacy = "B\n\nApache\n\n\nC\nD\nMIT\n"
    #expect(renderNotices(["D": ["MIT"], "B": ["\nApache\n"], "C": ["MIT"]], layout: .verbatim)
      == legacy)
  }

  @Test func titlesRenameSplitAndMergeItems() {
    let listed = listingUnderTitles(
      ["Core": ["Apache"], "Promises": ["Apache"], "Measurement": ["Vendor"],
       "MeasurementSupport": ["Vendor", "Extra"], "Other": ["MIT"]],
      ["Core": ["Umbrella", "Core"], "Promises": ["PromisesObjC"],
       "MeasurementSupport": ["Measurement"]]
    )
    #expect(listed.mapValues { $0.sorted() } == [
      "Umbrella": ["Apache"], "Core": ["Apache"], "PromisesObjC": ["Apache"],
      "Measurement": ["Extra", "Vendor", "Vendor"], "Other": ["MIT"],
    ])
    // Merged items are listed once under their shared title.
    #expect(renderNotices(listed) == """
    Core
    PromisesObjC
    Umbrella

    Apache

    Measurement

    Extra

    Measurement

    Vendor

    Other

    MIT

    """)
  }

  @Test func licensesReplaceTheFoundOnesAndExtrasStillAdd() {
    let licenses = shippedLicenses(licensedPlan(), notices(
      ["A": ["extra/A.txt"], "B": ["extra/B.txt"]],
      licenses: ["A": ["own/A.txt"], "Bin": ["own/Bin.txt", "own/Bin.txt"], "C": ["own/C.txt"]]
    ))
    #expect(licenses == ["A": ["own/A.txt", "extra/A.txt"], "B": ["LICENSE", "extra/B.txt"],
                         "Bin": ["own/Bin.txt"]])
    // It covers an item planning found no license for.
    var plan = licensedPlan()
    plan.binaries[0].licenses = nil
    #expect(shippedLicenses(plan, notices(licenses: ["Bin": ["own/Bin.txt"]]))["Bin"]
      == ["own/Bin.txt"])
  }

  @Test func appliesLicensesTitlesAndLayoutFromTheConfig() throws {
    let package = try SyntheticPackage()
    try package.write("LICENSE", "\nApache\n")
    try package.write("Bin/LICENSE", "Vendor\n")
    try package.write("own/Bin.txt", "\nApache\n")
    let config = notices(licenses: ["Bin": ["own/Bin.txt"]],
                         titles: ["A": ["Umbrella", "A"], "Bin": ["Binary"]],
                         layout: .verbatim)
    let result = try ZipBuilder.notices(licensedPlan(), config, packageRoot: package.root.path)
    #expect(result.text == "A\nB\nBinary\nUmbrella\n\nApache\n")
    #expect(result.entryCount == 1)
    // A missing `licenses` path fails, even for something this plan doesn't ship.
    let error = #expect(throws: ZipBuilderError.self) {
      try ZipBuilder.notices(licensedPlan(), notices(licenses: ["C": ["no.txt"]]),
                             packageRoot: package.root.path)
    }
    #expect(error?.description.contains("zip.notices.licenses: no.txt (for C)") == true)
  }

  @Test func warnsAboutUnshippedLicensesAndTitlesAndItemsWithoutTitles() async {
    var plan = licensedPlan()
    plan.frameworks[0].licenses = nil // B
    let (_, warnings) = await collectingWarnings {
      warnAboutMissingLicenses(plan, notices(licenses: ["B": ["b.txt"], "C": ["c.txt"]],
                                             titles: ["A": [], "Nope": ["N"]]))
    }
    // B's `licenses` entry gives it a license; A is listed under no title.
    #expect(warnings == [
      "zip.notices.licenses: C isn't a shipped framework or binary; skipped.",
      "zip.notices.titles: Nope isn't a shipped framework or binary; skipped.",
      "zip.notices.titles: A has no titles, so the notices leave it out.",
    ])
  }
}
