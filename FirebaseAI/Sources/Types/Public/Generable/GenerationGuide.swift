// Copyright 2025 Google LLC
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

/// Guides that control how values are generated.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct GenerationGuide<Value> {
  let wrapped: AnyGenerationGuides
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerationGuide where Value == String {
  /// Enforces that the string be precisely the given value.
  static func constant(_ value: String) -> GenerationGuide<String> {
    GenerationGuide(wrapped: AnyGenerationGuides(string: StringGuides(anyOf: [value])))
  }

  /// Enforces that the string be one of the provided values.
  static func anyOf(_ values: [String]) -> GenerationGuide<String> {
    GenerationGuide(wrapped: AnyGenerationGuides(string: StringGuides(anyOf: values)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerationGuide where Value == Int {
  /// Enforces a minimum value.
  ///
  /// Use a `minimum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value greater than or equal to some minimum value. For example, you can specify
  /// that all characters in your game start at level 1:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .minimum(1))
  ///     var level: Int
  /// }
  /// ```
  static func minimum(_ value: Int) -> GenerationGuide<Int> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(integer: IntegerGuides(minimum: value, maximum: nil))
    )
  }

  /// Enforces a maximum value.
  ///
  /// Use a `maximum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value less than or equal to some maximum value. For example, you can specify that
  /// the highest level a character in your game can achieve is 100:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .maximum(100))
  ///     var level: Int
  /// }
  /// ```
  static func maximum(_ value: Int) -> GenerationGuide<Int> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(integer: IntegerGuides(minimum: nil, maximum: value))
    )
  }

  /// Enforces values fall within a range.
  ///
  /// Use a `range` generation guide --- whose bounds are inclusive --- to ensure the model produces
  /// a value that falls within a range. For example, you can specify that the level of characters
  /// in your game are between 1 and 100:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .range(1...100))
  ///     var level: Int
  /// }
  /// ```
  static func range(_ range: ClosedRange<Int>) -> GenerationGuide<Int> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        integer: IntegerGuides(minimum: range.lowerBound, maximum: range.upperBound)
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerationGuide where Value == Float {
  /// Enforces a minimum value.
  ///
  /// Use a `minimum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value greater than or equal to some minimum value. For example, you can specify
  /// that all characters in your game start at level 1.0:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .minimum(1.0))
  ///     var level: Float
  /// }
  /// ```
  static func minimum(_ value: Float) -> GenerationGuide<Float> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: Double(value), maximum: nil))
    )
  }

  /// Enforces a maximum value.
  ///
  /// Use a `maximum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value less than or equal to some maximum value. For example, you can specify that
  /// the highest level a character in your game can achieve is 100.0:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .maximum(100.0))
  ///     var level: Float
  /// }
  /// ```
  static func maximum(_ value: Float) -> GenerationGuide<Float> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: nil, maximum: Double(value)))
    )
  }

  /// Enforces values fall within a range.
  ///
  /// Bounds are inclusive.
  ///
  /// A `range` generation guide may be used when you want to ensure the model produces a value that
  /// falls in some range, such as the cost for an item in a game.
  ///
  /// ```swift
  /// @Generable
  /// struct struct ShopItem {
  ///     @Guide(description: "A creative name for an item sold in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A cost for the item", .range(1...1000))
  ///     var cost: Float
  /// }
  /// ```
  static func range(_ range: ClosedRange<Float>) -> GenerationGuide<Float> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(minimum: Double(range.lowerBound), maximum: Double(range.upperBound))
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerationGuide where Value == Double {
  /// Enforces a minimum value.
  ///
  /// Use a `minimum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value greater than or equal to some minimum value. For example, you can specify
  /// that all characters in your game start at level 1.0:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .minimum(1.0))
  ///     var level: Double
  /// }
  /// ```
  static func minimum(_ value: Value) -> GenerationGuide<Value> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: value, maximum: nil))
    )
  }

  /// Enforces a maximum value.
  ///
  /// Use a `maximum` generation guide --- whose bounds are inclusive --- to ensure the model
  /// produces a value less than or equal to some maximum value. For example, you can specify that
  /// the highest level a character in your game can achieve is 5000.0:
  ///
  /// ```swift
  /// @Generable
  /// struct struct GameCharacter {
  ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
  ///     var name: String
  ///
  ///     @Guide(description: "A level for the character", .maximum(5000.0))
  ///     var level: Double
  /// }
  /// ```
  static func maximum(_ value: Value) -> GenerationGuide<Value> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: nil, maximum: value))
    )
  }

  /// Enforces values fall within a range.
  ///
  /// Bounds are inclusive.
  ///
  /// A `range` generation guide may be used when you want to ensure the model produces a value that
  /// falls in some range, such as the cost for an item in a game.
  ///
  /// ```swift
  /// @Generable
  /// struct struct ShopItem {
  ///     @Guide(description: "A creative name for an item sold in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A cost for the item", .range(1...1000))
  ///     var cost: Double
  /// }
  /// ```
  static func range(_ range: ClosedRange<Value>) -> GenerationGuide<Value> {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(minimum: range.lowerBound, maximum: range.upperBound)
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerationGuide {
  /// Enforces a minimum number of elements in the array.
  ///
  /// The bounds are inclusive.
  ///
  /// A `minimumCount` generation guide may be used when you want to ensure the model produces a
  /// number of array elements greater than or equal to to some minimum value, such as the number of
  /// items in a game's shop.
  ///
  /// ```swift
  /// @Generable
  /// struct struct Shop {
  ///     @Guide(description: "A creative name for a shop in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A list of items for sale", .minimumCount(3))
  ///     var inventory: [ShopItem]
  /// }
  /// ```
  static func minimumCount<Element>(_ count: Int) -> GenerationGuide<[Element]>
    where Value == [Element] {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: count, maximumCount: nil, element: nil)
      )
    )
  }

  /// Enforces a maximum number of elements in the array.
  ///
  /// The bounds are inclusive.
  ///
  /// A `maximumCount` generation guide may be used when you want to ensure the model produces a
  /// number of array elements less than or equal to to some maximum value, such as the number of
  /// items in a game's shop.
  ///
  /// ```swift
  /// @Generable
  /// struct struct Shop {
  ///     @Guide(description: "A creative name for a shop in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A list of items for sale", .maximumCount(10))
  ///     var inventory: [ShopItem]
  /// }
  /// ```
  static func maximumCount<Element>(_ count: Int) -> GenerationGuide<[Element]>
    where Value == [Element] {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: nil, maximumCount: count, element: nil)
      )
    )
  }

  /// Enforces that the number of elements in the array fall within a closed range.
  ///
  /// Bounds are inclusive.
  ///
  /// A `count` generation guide may be used when you want to ensure the model produces a number of
  /// array elements that falls within a given range, such as the number of items in a game's shop.
  ///
  /// ```swift
  /// @Generable
  /// struct struct Shop {
  ///     @Guide(description: "A creative name for a shop in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A list of items for sale", .count(2...10))
  ///     var inventory: [ShopItem]
  /// }
  /// ```
  static func count<Element>(_ range: ClosedRange<Int>) -> GenerationGuide<[Element]>
    where Value == [Element] {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(
          minimumCount: range.lowerBound,
          maximumCount: range.upperBound,
          element: nil
        )
      )
    )
  }

  /// Enforces that the array has exactly a certain number elements.
  ///
  /// A `count` generation guide may be used when you want to ensure the model produces exactly a
  /// certain number array elements, such as the number of items in a game's shop.
  ///
  /// ```swift
  /// @Generable
  /// struct struct Shop {
  ///     @Guide(description: "A creative name for a shop in a fantasy RPG"
  ///     var name: String
  ///
  ///     @Guide(description: "A list of items for sale", .count(3))
  ///     var inventory: [ShopItem]
  /// }
  /// ```
  static func count<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: count, maximumCount: count, element: nil)
      )
    )
  }

  /// Enforces a guide on the elements within the array.
  ///
  /// An `element` generation guide may be used when you want to apply guides to the values a model
  /// produces within an array. For example, you may want to generate an array of integers, where
  /// all the integers are in the range 0-9.
  ///
  /// ```swift
  /// @Generable
  /// struct struct FortuneCookie {
  ///     @Guide(description: "A fortune from a fortune cookie"
  ///     var name: String
  ///
  ///     @Guide(description: "A list lucky numbers", .element(.range(0...9)), .count(4))
  ///     var luckyNumbers: [Int]
  /// }
  /// ```
  static func element<Element>(_ guide: GenerationGuide<Element>) -> GenerationGuide<[Element]>
    where Value == [Element] {
    GenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: nil, maximumCount: nil, element: guide.wrapped)
      )
    )
  }
}
