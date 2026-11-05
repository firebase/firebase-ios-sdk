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

/// Diagnostics for declarations that `@Generable` and `@Guide` don't support.
///
/// The messages for `@Generable` on a class, an existing conformance, an empty enum, and `@Guide`
/// misuse match Apple's macros; the others are specific to the fake.
@Suite
struct MacroDiagnosticTests {
  /// Returns an error diagnostic expectation.
  ///
  /// - Parameters:
  ///   - message: The expected message.
  ///   - line: The expected line.
  ///   - column: The expected column.
  /// - Returns: The diagnostic expectation.
  private func error(_ message: String, line: Int, column: Int) -> DiagnosticSpec {
    DiagnosticSpec(message: message, line: line, column: column, severity: .error)
  }

  /// `@Generable` on a class.
  @Test
  func generableOnClass() {
    assertExpansion(
      """
      @Generable
      final class Klass {
        var name: String
      }
      """,
      expandedSource: """
        final class Klass {
          var name: String
        }
        """,
      diagnostics: [
        error("'@Generable' can only be used on structs and enums.", line: 1, column: 1)
      ]
    )
  }

  /// `@Generable` on a protocol.
  @Test
  func generableOnProtocol() {
    assertExpansion(
      """
      @Generable
      protocol Describable {
      }
      """,
      expandedSource: """
        protocol Describable {
        }
        """,
      diagnostics: [
        error("'@Generable' can only be used on structs and enums.", line: 1, column: 1)
      ]
    )
  }

  /// `@Generable` on a type that already declares `Generable`.
  @Test
  func generableOnTypeThatAlreadyConforms() {
    assertExpansion(
      """
      @Generable
      struct Already: Generable {
        var x: Int
      }
      """,
      expandedSource: """
        struct Already: Generable {
          var x: Int
        }
        """,
      diagnostics: [
        error(
          "Type already conforms to 'Generable'. Remove the '@Generable' macro or delete the "
            + "existing conformance.",
          line: 1,
          column: 1
        )
      ]
    )
  }

  /// `@Generable` on an enum without cases.
  @Test
  func generableOnEnumWithoutCases() {
    assertExpansion(
      """
      @Generable
      enum Empty {
      }
      """,
      expandedSource: """
        enum Empty {
        }
        """,
      diagnostics: [error("Generable enums must have at least one case.", line: 2, column: 6)]
    )
  }

  /// An associated value labeled `type`, which Apple's macro turns into a redeclaration.
  @Test
  func associatedValueLabeledType() {
    assertExpansion(
      """
      @Generable
      enum Labeled {
        case foo(type: String)
      }
      """,
      expandedSource: """
        enum Labeled {
          case foo(type: String)
        }
        """,
      diagnostics: [
        error(
          "The associated value label 'type' in case 'foo' conflicts with the 'type' "
            + "discriminator that '@Generable' generates; rename the label.",
          line: 3,
          column: 8
        )
      ]
    )
  }

  /// An unlabeled associated value and one labeled `value` map to the same property.
  @Test
  func duplicateAssociatedValueNames() {
    assertExpansion(
      """
      @Generable
      enum Clash {
        case pair(String, value: Int)
      }
      """,
      expandedSource: """
        enum Clash {
          case pair(String, value: Int)
        }
        """,
      diagnostics: [
        error(
          "Associated values of case 'pair' both map to the property 'value'; give them "
            + "distinct labels.",
          line: 3,
          column: 8
        )
      ]
    )
  }

  /// Cases that differ only in the case of their first letter map to the same helper type.
  @Test
  func duplicateDiscriminatedTypeNames() {
    assertExpansion(
      """
      @Generable
      enum Letters {
        case a(Int)
        case A(Int)
      }
      """,
      expandedSource: """
        enum Letters {
          case a(Int)
          case A(Int)
        }
        """,
      diagnostics: [
        error(
          "Cases 'a' and 'A' both map to the helper type 'DiscriminatedA'; rename one of them.",
          line: 4,
          column: 8
        )
      ]
    )
  }

  /// A property declared with a tuple pattern is skipped with an error.
  @Test
  func tuplePatternProperty() throws {
    let source = """
      @Generable
      struct Pair {
        var (a, b): (Int, Int)
        var c: Int
      }
      """
    let tupleError = error(
      "'@Generable' doesn't support properties declared with a tuple pattern; declare each "
        + "property separately.",
      line: 3,
      column: 7
    )

    try assertExpansion(
      source, matchesSnapshot: "Diagnostics/TuplePattern", diagnostics: [tupleError])
  }

  /// `@Guide` on a computed property.
  @Test
  func guideOnComputedProperty() {
    assertExpansion(
      """
      struct Holder {
        @Guide(description: "x")
        var computed: Int { 1 }
      }
      """,
      expandedSource: """
        struct Holder {
          var computed: Int { 1 }
        }
        """,
      diagnostics: [
        error("'@Guide' can only be used with a stored property.", line: 2, column: 3)
      ]
    )
  }

  /// `@Guide` on a static property.
  @Test
  func guideOnStaticProperty() {
    assertExpansion(
      """
      struct Holder {
        @Guide(description: "x")
        static var shared: Int = 1
      }
      """,
      expandedSource: """
        struct Holder {
          static var shared: Int = 1
        }
        """,
      diagnostics: [
        error("'@Guide' can only be used with a stored property.", line: 2, column: 3)
      ]
    )
  }

  /// `@Guide` on a function.
  @Test
  func guideOnFunction() {
    assertExpansion(
      """
      struct Holder {
        @Guide(description: "x")
        func describe() {}
      }
      """,
      expandedSource: """
        struct Holder {
          func describe() {}
        }
        """,
      diagnostics: [
        error("'@Guide' can only be used with a stored property.", line: 2, column: 3)
      ]
    )
  }

  /// `@Guide` on a stored property with an observer is valid and expands to nothing.
  @Test
  func guideOnStoredPropertyWithObserver() {
    assertExpansion(
      """
      struct Holder {
        @Guide(description: "x", .range(1...3))
        var stored: Int { didSet {} }
      }
      """,
      expandedSource: """
        struct Holder {
          var stored: Int { didSet {} }
        }
        """
    )
  }
}
