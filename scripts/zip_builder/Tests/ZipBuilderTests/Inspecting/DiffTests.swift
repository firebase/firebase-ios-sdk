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

/// Diffs two fake distributions without symbols.
func diffFakes(_ makeBaseline: (FakeDistribution) throws -> Void,
               _ makeCandidate: (FakeDistribution) throws -> Void) async throws -> DiffReport {
  let baseline = try FakeDistribution(), candidate = try FakeDistribution()
  try makeBaseline(baseline)
  try makeCandidate(candidate)
  return try await diffDistributions(baseline.read(), candidate.read(), symbols: false)
}

/// A report with a layout change and a changed framework: `Core`'s headers and version.
func sampleDiffReport() async throws -> DiffReport {
  var device = FakeSlice.device
  device.version = "2.0.0"
  device.headers = ["Core.h", "New.h"]
  return try await diffFakes({
    try $0.addXCFramework("Core", in: "A", slices: [.device])
    try $0.addXCFramework("Gone", in: "A")
  }, {
    try $0.addXCFramework("Core", in: "A", slices: [device])
    try $0.addFile("NOTICES")
  })
}

struct DiffTests {
  /// The differences of the only framework both distributions have, `A/Core`.
  private func coreDifferences(_ baseline: [FakeSlice],
                               _ candidate: [FakeSlice]) async throws -> [Difference] {
    let report = try await diffFakes({ try $0.addXCFramework("Core", in: "A", slices: baseline) },
                                     { try $0.addXCFramework("Core", in: "A", slices: candidate) })
    return report.changed.first?.differences ?? []
  }

  @Test func identicalDistributionsHaveNoDifferences() async throws {
    let report = try await diffFakes({ try $0.addXCFramework("Core", in: "A") },
                                     { try $0.addXCFramework("Core", in: "A") })
    #expect(report.isEmpty)
    #expect(renderText(report).hasSuffix("No differences."))
    #expect(renderMarkdown(report).hasSuffix("No differences.\n"))
  }

  @Test func foldersFrameworksMovesAndFiles() async throws {
    let report = try await diffFakes({
      try $0.addFile("NOTICES")
      try $0.addXCFramework("Core", in: "A")
      try $0.addXCFramework("Gone", in: "A")
      try $0.addXCFramework("Mover", in: "A")
      try $0.addXCFramework("Old", in: "Removed")
    }, {
      try $0.addFile("README.md")
      try $0.addFile("A/run")
      try $0.addXCFramework("Core", in: "A")
      try $0.addXCFramework("Mover", in: "B")
      try $0.addXCFramework("New", in: "Added")
    })
    #expect(report.folders == Changes(["A", "Removed"], ["A", "Added", "B"]))
    #expect(report.folders.added == ["Added", "B"] && report.folders.removed == ["Removed"])
    #expect(report.frameworks.added == ["Added/New"])
    #expect(report.frameworks.removed == ["A/Gone", "Removed/Old"])
    #expect(report.moved == [Move(framework: "Mover", from: ["A"], to: ["B"])])
    #expect(report.files.added == ["README.md", "A/run"])
    #expect(report.files.removed == ["NOTICES"])
    #expect(report.changed.isEmpty)
  }

  /// A framework in several folders is compared once: the candidate's copy in the baseline's first
  /// folder (else the candidate's first copy), against the baseline's copy in that folder (else
  /// its first). Baseline [A, B, C] and candidate [C, B] compare the two C copies.
  @Test func aFrameworkInSeveralFoldersIsComparedOnce() async throws {
    let baseline = try FakeDistribution(), candidate = try FakeDistribution()
    for folder in ["A", "B", "C"] {
      var slice = FakeSlice.device
      slice.version = "old \(folder)"
      try baseline.addXCFramework("Core", in: folder, slices: [slice])
    }
    for folder in ["C", "B"] {
      var slice = FakeSlice.device
      slice.version = "new \(folder)"
      try candidate.addXCFramework("Core", in: folder, slices: [slice])
    }
    var read = try await candidate.read()
    read.folders.reverse() // folders are read sorted; this puts C first
    let report = try await diffDistributions(baseline.read(), read, symbols: false)

    #expect(report.frameworks.isEmpty)
    #expect(report.moved == [Move(framework: "Core", from: ["A", "B", "C"], to: ["C", "B"])])
    #expect(report.changed == [FrameworkDiff(name: "Core", folder: "C", differences: [
      Difference(category: .infoPlist, key: "CFBundleShortVersionString", before: "old C",
                 after: "new C"),
    ])])
  }

  @Test func slicesAndArchitectures() async throws {
    var simulator = FakeSlice.simulator
    simulator.architectures = ["arm64"]
    let tvos = FakeSlice(identifier: "tvos-arm64", platform: "tvos")
    let differences = try await coreDifferences([.device, .simulator, tvos], [.device, simulator])
    #expect(differences == [
      Difference(category: .slices, changes: Changes(["tvos-arm64"], [])),
      Difference(category: .architectures, slices: ["ios-arm64_x86_64-simulator"],
                 before: "arm64, x86_64", after: "arm64"),
    ])
  }

  @Test func binaryKind() async throws {
    let differences = try await coreDifferences(
      [.device], [FakeSlice(identifier: "ios-arm64", hasBinary: false)]
    )
    #expect(differences == [Difference(category: .binaryKind, before: "static", after: "missing")])
  }

  @Test func headersAreGroupedAcrossSlices() async throws {
    var device = FakeSlice.device, simulator = FakeSlice.simulator
    device.headers = ["Core.h", "New.h"]
    simulator.headers = ["Core.h", "New.h"]
    // The same change in every slice is one difference, with no slice list.
    #expect(try await coreDifferences([.device, .simulator], [device, simulator]) == [
      Difference(category: .headers, changes: Changes([], ["Headers/New.h"]), addedCount: 1),
    ])

    var privateDevice = FakeSlice.device
    privateDevice.privateHeaders = ["Private.h"]
    #expect(try await coreDifferences([.device, .simulator], [privateDevice, .simulator]) == [
      Difference(category: .headers, slices: ["ios-arm64"],
                 changes: Changes([], ["PrivateHeaders/Private.h"]), addedCount: 1),
    ])
  }

  @Test func moduleMapLines() async throws {
    var device = FakeSlice.device
    device.moduleMap = "framework module Core {\n  umbrella header \"Core.h\"\n  export *\n}"
    let differences = try await coreDifferences([.device], [device])
    #expect(differences == [Difference(category: .moduleMap,
                                       changes: Changes([], ["export *"]), addedCount: 1)])

    // Only indentation changed.
    device.moduleMap = "framework module Core {\numbrella header \"Core.h\"\n}"
    #expect(try await coreDifferences([.device], [device]) == [
      Difference(category: .moduleMap, before: "same lines", after: "reordered or reformatted"),
    ])
  }

  @Test func infoPlistValuesAndResourceBundles() async throws {
    var device = FakeSlice.device
    device.version = "2.0.0"
    device.bundles = ["Core_Privacy"]
    let differences = try await coreDifferences([.device], [device])
    #expect(differences == [
      Difference(category: .infoPlist, key: "CFBundleShortVersionString", before: "1.0.0",
                 after: "2.0.0"),
      Difference(category: .resourceBundles, changes: Changes([], ["Core_Privacy.bundle"]),
                 addedCount: 1),
    ])
  }

  @Test func symbolsAreCountedAndTruncated() async throws {
    let baseline = try FakeDistribution(), candidate = try FakeDistribution()
    try baseline.addXCFramework("Core", in: "A", slices: [.device])
    try candidate.addXCFramework("Core", in: "A", slices: [.device])
    let old = try #require(try await baseline.read().xcframeworks.first)
    let new = try #require(try await candidate.read().xcframeworks.first)
    let added = (0 ..< 30).map { "_new\($0)" }
    let symbols: [Path: Set<String>] = [
      old.slices[0].binaryPath: ["_kept", "_gone"],
      new.slices[0].binaryPath: Set(["_kept"] + added),
    ]
    let difference = try #require(frameworkDifferences(old, new, symbols: symbols).first)
    #expect(difference.category == .symbols)
    #expect(difference.addedCount == 30 && difference.removedCount == 1)
    #expect(difference.changes.added == Array(added.sorted().prefix(symbolNamesShown)))
    #expect(difference.changes.removed == ["_gone"])
    #expect(describe(difference).0 == "Exported symbols: +30 -1")
  }

  @Test func rendersText() async throws {
    let text = try await renderText(sampleDiffReport())
    #expect(text.contains("Exported symbols: not compared (--no-symbols)"))
    #expect(text.contains("""
    Frameworks: 0 added, 1 removed
      - A/Gone
    """))
    #expect(text.contains("""
    Changed frameworks: 1
      Core (A)
        Headers: +1 -0
            + Headers/New.h
        Info.plist CFBundleShortVersionString: 1.0.0 → 2.0.0
    """))
    #expect(text.contains("Loose files: 1 added, 0 removed\n  + NOTICES"))
  }

  @Test func rendersMarkdown() async throws {
    let markdown = try await renderMarkdown(sampleDiffReport())
    #expect(markdown.contains("| Change | Count |\n|---|---:|\n| Folders added | 0 |"))
    #expect(markdown.contains("| Frameworks removed | 1 |"))
    #expect(markdown.contains("| Frameworks changed | 1 |"))
    #expect(markdown.contains(
      "<details><summary><b>Core</b> (A): Headers, Info.plist CFBundleShortVersionString</summary>"
    ))
    #expect(markdown.contains("```text\nHeaders: +1 -0\n    + Headers/New.h\n"))
    #expect(markdown.hasSuffix("</details>\n"))
  }

  @Test func rendersJSONThatRoundTrips() async throws {
    let report = try await sampleDiffReport()
    let json = try renderJSON(report)
    #expect(json.contains("\"category\" : \"infoPlist\""))
    #expect(try JSONDecoder().decode(DiffReport.self, from: Data(json.utf8)) == report)
  }

  @Test func markdownStaysUnderTheLimit() {
    let difference = Difference(category: .headers,
                                changes: Changes([], (0 ..< 50).map { "Headers/H\($0).h" }),
                                addedCount: 50)
    var report = DiffReport(baseline: "a", candidate: "b", symbolsCompared: true)
    report.changed = (0 ..< 500).map {
      FrameworkDiff(name: "Framework\($0)", folder: "F", differences: [difference])
    }
    let markdown = renderMarkdown(report, limit: 20000)
    #expect(markdown.utf8.count <= 20000)
    #expect(markdown.contains("more changed frameworks are not shown"))
    #expect(markdown.contains("… 11 more lines in the text report"))
    #expect(markdown.contains("<b>Framework0</b>"))
    #expect(!markdown.contains("<b>Framework499</b>"))
    #expect(renderMarkdown(report).utf8.count <= 60000)
  }

  @Test func commandOptions() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff", "a", "b", "--no-symbols", "--format", "json",
    ]) as? DiffCommand)
    #expect(command.noSymbols)
    #expect(command.format == .json)
    let defaults = try #require(try ZipBuilderCommand.parseAsRoot([
      "diff",
      "a",
      "b",
    ]) as? DiffCommand)
    #expect(!defaults.noSymbols)
    #expect(!defaults.exitCode)
  }

  @Test func exitCodeFailsOnlyWhenThereAreDifferences() async throws {
    let baseline = try FakeDistribution(), candidate = try FakeDistribution()
    try baseline.addXCFramework("Core", in: "A")
    try candidate.addXCFramework("Core", in: "A")
    let report = (baseline.root as NSString).deletingLastPathComponent + "/report.md"
    func diff(_ extra: [String]) async throws {
      let command = try #require(try ZipBuilderCommand.parseAsRoot([
        "diff", baseline.root, candidate.root, "--no-symbols", "--format", "markdown",
        "--output", report,
      ] + extra) as? DiffCommand)
      try await command.run()
    }

    try await diff(["--exit-code"])
    try candidate.addXCFramework("New", in: "B")
    try await diff([])
    let error = await #expect(throws: ExitCode.self) { try await diff(["--exit-code"]) }
    #expect(error?.rawValue == 1)
    // The report is written before exiting.
    #expect(try String(contentsOfFile: report, encoding: .utf8).contains("B/New"))
  }
}
