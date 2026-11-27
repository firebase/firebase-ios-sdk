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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  /// The constraint that a single ``GenerationGuide`` applies to a schema.
  ///
  /// Guides are stored separately from the schema they constrain and applied when the schema is
  /// resolved (see `GenerationSchema.applying(_:)`).
  indirect enum GenerationGuideKind: Sendable {
    /// Replaces a string schema with a constant (`{"const": value}`).
    case constant(String)

    /// Restricts a string schema to a set of choices (`enum`).
    case anyOf([String])

    /// Restricts a string schema to a regular expression (`pattern`).
    ///
    /// The pattern is `nil` when the regex can't be printed as a literal.
    case pattern(String?)

    /// Bounds an integer schema (`minimum` and `maximum`); `nil` leaves a bound unchanged.
    case integerBounds(minimum: Int?, maximum: Int?)

    /// Bounds a `Double`, `Float`, or `Decimal` schema; `nil` leaves a bound unchanged.
    case doubleBounds(minimum: Double?, maximum: Double?)

    /// Bounds the element count of an array schema (`minItems` and `maxItems`).
    case countBounds(minimum: Int?, maximum: Int?)

    /// Applies a guide to the elements of an array schema (`items`).
    case element(GenerationGuideKind)
  }

  extension GenerationGuideKind {
    /// Creates a pattern guide from a regex, printing it the way Apple does.
    ///
    /// The pattern is regenerated from the regex instead of using the literal's source text, so
    /// `/\d{3}-\d{4}/` becomes `\d{3}\-\d{4}`. `Regex._literalPattern` produces exactly that
    /// form, and returns `nil` for regexes (such as some `RegexBuilder` components) that have no
    /// literal representation.
    ///
    /// - Parameter regex: The regex to print.
    /// - Returns: A pattern guide.
    static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuideKind {
      .pattern(regex._literalPattern)
    }
  }

  extension Decimal {
    /// The value as a `Double`, used for schema bounds, which Apple prints as JSON numbers.
    var schemaDoubleValue: Double {
      Double(description) ?? 0
    }
  }
#endif  // compiler(>=6.4)
