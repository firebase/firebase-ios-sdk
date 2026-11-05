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
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  /// A constraint applied to a generable value during model generation.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`GenerationGuide`](https://developer.apple.com/documentation/foundationmodels/generationguide).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GenerationGuide<Value> {
    /// The constraint this guide applies.
    let kind: GenerationGuideKind
  }

  extension GenerationGuide where Value == String {
    /// Constrains a string to an exact constant value.
    ///
    /// - Parameter value: The constant string value.
    /// - Returns: A generation guide enforcing the constant string.
    public static func constant(_ value: String) -> GenerationGuide<String> {
      GenerationGuide(kind: .constant(value))
    }

    /// Constrains a string to one of the specified choices.
    ///
    /// - Parameter values: The allowed string values.
    /// - Returns: A generation guide restricting the string choices.
    public static func anyOf(_ values: [String]) -> GenerationGuide<String> {
      GenerationGuide(kind: .anyOf(values))
    }

    /// Constrains a string to match a regular expression pattern.
    ///
    /// - Parameter regex: The regular expression pattern.
    /// - Returns: A generation guide enforcing the pattern match.
    public static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuide<String> {
      GenerationGuide(kind: .pattern(regex))
    }
  }

  extension GenerationGuide where Value == Int {
    /// Constrains an integer to a minimum inclusive value.
    ///
    /// - Parameter value: The minimum allowed integer value.
    /// - Returns: A generation guide enforcing the minimum bound.
    public static func minimum(_ value: Int) -> GenerationGuide<Int> {
      GenerationGuide(kind: .integerBounds(minimum: value, maximum: nil))
    }

    /// Constrains an integer to a maximum inclusive value.
    ///
    /// - Parameter value: The maximum allowed integer value.
    /// - Returns: A generation guide enforcing the maximum bound.
    public static func maximum(_ value: Int) -> GenerationGuide<Int> {
      GenerationGuide(kind: .integerBounds(minimum: nil, maximum: value))
    }

    /// Constrains an integer to a closed range of values.
    ///
    /// - Parameter range: The range of allowed integer values.
    /// - Returns: A generation guide enforcing the range bounds.
    public static func range(_ range: ClosedRange<Int>) -> GenerationGuide<Int> {
      GenerationGuide(kind: .integerBounds(minimum: range.lowerBound, maximum: range.upperBound))
    }
  }

  extension GenerationGuide where Value == Float {
    /// Constrains a floating-point value to a minimum inclusive value.
    ///
    /// - Parameter value: The minimum allowed floating-point value.
    /// - Returns: A generation guide enforcing the minimum bound.
    public static func minimum(_ value: Float) -> GenerationGuide<Float> {
      GenerationGuide(kind: .doubleBounds(minimum: Double(value), maximum: nil))
    }

    /// Constrains a floating-point value to a maximum inclusive value.
    ///
    /// - Parameter value: The maximum allowed floating-point value.
    /// - Returns: A generation guide enforcing the maximum bound.
    public static func maximum(_ value: Float) -> GenerationGuide<Float> {
      GenerationGuide(kind: .doubleBounds(minimum: nil, maximum: Double(value)))
    }

    /// Constrains a floating-point value to a closed range of values.
    ///
    /// - Parameter range: The range of allowed floating-point values.
    /// - Returns: A generation guide enforcing the range bounds.
    public static func range(_ range: ClosedRange<Float>) -> GenerationGuide<Float> {
      GenerationGuide(
        kind: .doubleBounds(
          minimum: Double(range.lowerBound),
          maximum: Double(range.upperBound)
        )
      )
    }
  }

  extension GenerationGuide where Value == Decimal {
    /// Constrains a decimal value to a minimum inclusive value.
    ///
    /// - Parameter value: The minimum allowed decimal value.
    /// - Returns: A generation guide enforcing the minimum bound.
    public static func minimum(_ value: Decimal) -> GenerationGuide<Decimal> {
      GenerationGuide(kind: .doubleBounds(minimum: value.schemaDoubleValue, maximum: nil))
    }

    /// Constrains a decimal value to a maximum inclusive value.
    ///
    /// - Parameter value: The maximum allowed decimal value.
    /// - Returns: A generation guide enforcing the maximum bound.
    public static func maximum(_ value: Decimal) -> GenerationGuide<Decimal> {
      GenerationGuide(kind: .doubleBounds(minimum: nil, maximum: value.schemaDoubleValue))
    }

    /// Constrains a decimal value to a closed range of values.
    ///
    /// - Parameter range: The range of allowed decimal values.
    /// - Returns: A generation guide enforcing the range bounds.
    public static func range(_ range: ClosedRange<Decimal>) -> GenerationGuide<Decimal> {
      GenerationGuide(
        kind: .doubleBounds(
          minimum: range.lowerBound.schemaDoubleValue,
          maximum: range.upperBound.schemaDoubleValue
        )
      )
    }
  }

  extension GenerationGuide where Value == Double {
    /// Constrains a double-precision floating-point value to a minimum inclusive value.
    ///
    /// - Parameter value: The minimum allowed floating-point value.
    /// - Returns: A generation guide enforcing the minimum bound.
    public static func minimum(_ value: Double) -> GenerationGuide<Double> {
      GenerationGuide(kind: .doubleBounds(minimum: value, maximum: nil))
    }

    /// Constrains a double-precision floating-point value to a maximum inclusive value.
    ///
    /// - Parameter value: The maximum allowed floating-point value.
    /// - Returns: A generation guide enforcing the maximum bound.
    public static func maximum(_ value: Double) -> GenerationGuide<Double> {
      GenerationGuide(kind: .doubleBounds(minimum: nil, maximum: value))
    }

    /// Constrains a double-precision floating-point value to a closed range of values.
    ///
    /// - Parameter range: The range of allowed floating-point values.
    /// - Returns: A generation guide enforcing the range bounds.
    public static func range(_ range: ClosedRange<Double>) -> GenerationGuide<Double> {
      GenerationGuide(kind: .doubleBounds(minimum: range.lowerBound, maximum: range.upperBound))
    }
  }

  extension GenerationGuide {
    /// Constrains an array to a minimum element count.
    ///
    /// - Parameter count: The minimum number of elements.
    /// - Returns: A generation guide enforcing the minimum count.
    public static func minimumCount<Element>(
      _ count: Int
    ) -> GenerationGuide<[Element]> where Value == [Element] {
      GenerationGuide<[Element]>(kind: .countBounds(minimum: count, maximum: nil))
    }

    /// Constrains an array to a maximum element count.
    ///
    /// - Parameter count: The maximum number of elements.
    /// - Returns: A generation guide enforcing the maximum count.
    public static func maximumCount<Element>(
      _ count: Int
    ) -> GenerationGuide<[Element]> where Value == [Element] {
      GenerationGuide<[Element]>(kind: .countBounds(minimum: nil, maximum: count))
    }

    /// Constrains an array to an element count within a closed range.
    ///
    /// - Parameter range: The range of allowed element counts.
    /// - Returns: A generation guide enforcing the count range.
    public static func count<Element>(
      _ range: ClosedRange<Int>
    ) -> GenerationGuide<[Element]> where Value == [Element] {
      GenerationGuide<[Element]>(
        kind: .countBounds(minimum: range.lowerBound, maximum: range.upperBound)
      )
    }

    /// Constrains an array to an exact element count.
    ///
    /// - Parameter count: The exact number of elements.
    /// - Returns: A generation guide enforcing the exact count.
    public static func count<Element>(
      _ count: Int
    ) -> GenerationGuide<[Element]> where Value == [Element] {
      GenerationGuide<[Element]>(kind: .countBounds(minimum: count, maximum: count))
    }

    /// Applies a generation guide to each element of an array.
    ///
    /// - Parameter guide: The guide to apply to elements.
    /// - Returns: A generation guide enforcing the element constraint.
    public static func element<Element>(
      _ guide: GenerationGuide<Element>
    ) -> GenerationGuide<[Element]> where Value == [Element] {
      GenerationGuide<[Element]>(kind: .element(guide.kind))
    }
  }

  @_documentation(visibility: private)
  extension GenerationGuide where Value == [Never] {
    /// A placeholder overload for minimum element counts that traps if called.
    ///
    /// - Parameter count: The minimum element count.
    /// - Returns: A generation guide.
    @_documentation(visibility: private)
    public static func minimumCount(_ count: Int) -> GenerationGuide<Value> {
      fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }

    /// A placeholder overload for maximum element counts that traps if called.
    ///
    /// - Parameter count: The maximum element count.
    /// - Returns: A generation guide.
    @_documentation(visibility: private)
    public static func maximumCount(_ count: Int) -> GenerationGuide<Value> {
      fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }

    /// A placeholder overload for element count ranges that traps if called.
    ///
    /// - Parameter range: The range of element counts.
    /// - Returns: A generation guide.
    @_documentation(visibility: private)
    public static func count(_ range: ClosedRange<Int>) -> GenerationGuide<Value> {
      fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }

    /// A placeholder overload for exact element counts that traps if called.
    ///
    /// - Parameter count: The element count.
    /// - Returns: A generation guide.
    @_documentation(visibility: private)
    @_disfavoredOverload
    public static func count(_ count: Int) -> GenerationGuide<Value> {
      fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }
  }
#endif  // compiler(>=6.4)
