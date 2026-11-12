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

/// `zip.notices` with `extraLicenses`.
private func notices(_ extraLicenses: [String: [Path]] = [:]) -> Config.Notices {
  Config.Notices(extraLicenses: Default(wrappedValue: extraLicenses))
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
      // Leading and trailing whitespace doesn't make another license.
      "Alpha": ["Apache"],
      "Beta": ["MIT\n"],
      // Two license files: listed under both texts.
      "Gamma": ["MIT\n", "\n  Apache\n\n"],
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
    #expect(renderNotices(["A": ["\n\n  text  \n\n\n"]]) == "A\n\ntext\n")
    // Inner whitespace is kept: it's part of the text.
    #expect(renderNotices(["A": ["one\n\n  two"], "B": ["one\ntwo"]])
      == "A\n\none\n\n  two\n\nB\n\none\ntwo\n")
    // Two files of one item with the same trimmed text make one entry.
    #expect(renderNotices(["A": ["same", "\nsame\n"]]) == "A\n\nsame\n")
    #expect(renderNotices([:]) == "\n")
  }

  @Test func onlyShippedItemsGetLicensesWithTheirExtras() {
    let licenses = shippedLicenses(licensedPlan(), extraLicenses: [
      "A": ["LICENSE", "extra/A.txt"], // the duplicate is dropped
      "C": ["extra/C.txt"], // C isn't in a folder
    ])
    #expect(licenses == ["A": ["LICENSE", "extra/A.txt"], "B": ["LICENSE"],
                         "Bin": ["Bin/LICENSE"]])
    var plan = licensedPlan()
    plan.binaries[0].licenses = nil
    #expect(shippedLicenses(plan, extraLicenses: [:])["Bin"] == [])
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
}
