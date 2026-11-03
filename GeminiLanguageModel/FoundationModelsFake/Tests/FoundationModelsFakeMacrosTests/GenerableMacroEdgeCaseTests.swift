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

import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Expansion tests for less common `@Generable` declarations.
@Suite
struct GenerableMacroEdgeCaseTests {
  /// An internal `Hashable` struct with a non-`GenerationID` `id` property: members get no
  /// access modifier, `PartiallyGenerated` repeats `Hashable`, and it doesn't synthesize
  /// `Identifiable`.
  @Test
  func internalHashableStructWithIDProperty() throws {
    let source = """
      @Generable
      struct InternalThing: Hashable {
        var id: String
        var value: Int
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/InternalHashableWithID")
  }

  /// An `id: GenerationID` property maps to the content's generation ID instead of a schema
  /// property.
  @Test
  func generationIDProperty() throws {
    let source = """
      @Generable
      struct SearchTerm {
        var id: GenerationID
        @Guide(description: "A two- or three- word search term")
        var searchTerm: String
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/GenerationID")
  }

  /// An `id: GenerationID?` property maps to the content's generation ID without a fallback.
  @Test
  func optionalGenerationIDProperty() throws {
    let source = """
      @Generable
      struct Draft {
        var id: GenerationID?
        var text: String
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/OptionalGenerationID")
  }

  /// A `package` enum with several unlabeled associated values, which are named `value`,
  /// `value1`, and so on.
  @Test
  func packageEnumWithUnlabeledAssociatedValues() throws {
    let source = """
      @Generable
      package enum Payload {
        case pair(Int, Int)
        case single(Int)
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/PackageUnlabeled")
  }

  /// Associated value labels that are keywords are escaped where they're used as identifiers.
  @Test
  func keywordAssociatedValueLabels() throws {
    let source = """
      @Generable
      enum Keyword {
        case range(default: Int, in: String)
        case plain
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/KeywordLabels")
  }

  /// Backticked names, multiple bindings, observers, and implicitly unwrapped optionals are
  /// included; constants with a value, `lazy`, static, and computed properties are skipped.
  @Test
  func storedPropertyForms() throws {
    let source = """
      @Generable
      struct Forms {
        var `default`: Int
        var a, b: Int
        var observed: Int { didSet {} }
        var implicit: String!
        let constant: Int = 3
        lazy var cached: Int = 3
        static var shared: Int = 1
        var computed: Int { a + b }
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/StoredPropertyForms")
  }

  /// `@Generable(name:)` on an enum calls the macro-only `GenerationSchema(__name:anyOf:)`.
  @Test
  func namedEnum() throws {
    let source = """
      @Generable(name: "Mood")
      public enum NamedMood {
        case happy
        case sad
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/NamedEnum")
  }

  /// An enum's description and `representNilExplicitlyInGeneratedContent` are repeated by its
  /// `Discriminated*` structs.
  @Test
  func explicitNilEnum() throws {
    let source = """
      @Generable(description: "D", representNilExplicitlyInGeneratedContent: true)
      enum ExplicitEnum {
        case a(Int?)
      }
      """

    try assertExpansion(source, matchesSnapshot: "EdgeCases/ExplicitNilEnum")
  }

  /// A property without a type annotation is excluded with a warning.
  @Test
  func propertyWithoutTypeAnnotation() throws {
    let source = """
      @Generable
      struct Untyped {
        var count = 5
        var name: String
      }
      """
    let warning = DiagnosticSpec(
      message: "Property 'count' has no type annotation, so '@Generable' excludes it from the "
        + "generation schema; add an explicit type to include it.",
      line: 3,
      column: 7,
      severity: .warning
    )

    try assertExpansion(
      source, matchesSnapshot: "EdgeCases/MissingType", diagnostics: [warning])
  }
}
