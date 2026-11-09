// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import FoundationModelsFakeMacros

/// The macros under test, with the conformance that the `@Generable` declaration requests.
let generableMacroSpecs: [String: MacroSpec] = [
  "Generable": MacroSpec(
    type: GenerableMacro.self,
    conformances: [TypeSyntax(IdentifierTypeSyntax(name: .identifier("Generable")))]
  ),
  "Guide": MacroSpec(type: GuideMacro.self),
]

/// Locations of the files that the macro tests read.
enum MacroTestPaths {
  /// The `Tests/FoundationModelsFakeMacrosTests` directory.
  static let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

  /// The directory of recorded expansion snapshots.
  static let snapshots = testDirectory.appendingPathComponent("Snapshots")
}

/// Whether to rewrite snapshots from the current expansions instead of comparing against them.
///
/// Set `RECORD_MACRO_SNAPSHOTS=1` in the environment to re-record after an intentional change,
/// then review the diff of `Snapshots/`.
private let isRecordingSnapshots =
  ProcessInfo.processInfo.environment["RECORD_MACRO_SNAPSHOTS"] == "1"

/// Expands the macros in `source` the way `assertMacroExpansion` does.
///
/// - Parameter source: The source to expand.
/// - Returns: The expanded source without leading or trailing newlines.
func expandMacros(in source: String) -> String {
  let file = Parser.parse(source: source)
  let context = BasicMacroExpansionContext(
    sourceFiles: [file: .init(moduleName: "TestModule", fullFilePath: "test.swift")])
  let expanded = file.expand(
    macroSpecs: generableMacroSpecs,
    contextGenerator: { _ in context },
    indentationWidth: .spaces(4)
  )
  return expanded.description.trimmingCharacters(in: .newlines)
}

/// Asserts that expanding `source` produces `expandedSource` and `diagnostics`.
///
/// - Parameters:
///   - source: The source containing macro attributes.
///   - expandedSource: The expected expansion.
///   - diagnostics: The expected diagnostics.
///   - sourceLocation: The location to report failures at.
func assertExpansion(
  _ source: String,
  expandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
  assertMacroExpansion(
    source,
    expandedSource: expandedSource,
    diagnostics: diagnostics,
    macroSpecs: generableMacroSpecs,
    failureHandler: { failure in
      Issue.record(Comment(rawValue: failure.message), sourceLocation: sourceLocation)
    }
  )
}

/// Asserts that expanding `source` produces the recorded snapshot and `diagnostics`.
///
/// - Parameters:
///   - source: The source containing macro attributes.
///   - snapshot: The snapshot path relative to `Snapshots/`, without the `.txt` extension.
///   - diagnostics: The expected diagnostics.
///   - sourceLocation: The location to report failures at.
/// - Throws: An error if the snapshot can't be read or recorded.
func assertExpansion(
  _ source: String,
  matchesSnapshot snapshot: String,
  diagnostics: [DiagnosticSpec] = [],
  sourceLocation: Testing.SourceLocation = #_sourceLocation
) throws {
  let url = MacroTestPaths.snapshots.appendingPathComponent("\(snapshot).txt")
  if isRecordingSnapshots {
    try (expandMacros(in: source) + "\n").write(to: url, atomically: true, encoding: .utf8)
  }
  let expected = try String(contentsOf: url, encoding: .utf8)
  assertExpansion(
    source,
    expandedSource: expected,
    diagnostics: diagnostics,
    sourceLocation: sourceLocation
  )
}
