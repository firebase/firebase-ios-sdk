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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FirebaseGenerationGuide<Value> {
  let wrapped: AnyGenerationGuides
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide where Value == String {
  static func constant(_ value: String) -> FirebaseGenerationGuide<String> {
    FirebaseGenerationGuide(wrapped: AnyGenerationGuides(string: StringGuides(anyOf: [value])))
  }

  static func anyOf(_ values: [String]) -> FirebaseGenerationGuide<String> {
    FirebaseGenerationGuide(wrapped: AnyGenerationGuides(string: StringGuides(anyOf: values)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide where Value == Int {
  static func minimum(_ value: Int) -> FirebaseGenerationGuide<Int> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(integer: IntegerGuides(minimum: value, maximum: nil))
    )
  }

  static func maximum(_ value: Int) -> FirebaseGenerationGuide<Int> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(integer: IntegerGuides(minimum: nil, maximum: value))
    )
  }

  static func range(_ range: ClosedRange<Int>) -> FirebaseGenerationGuide<Int> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        integer: IntegerGuides(minimum: range.lowerBound, maximum: range.upperBound)
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide where Value == Float {
  static func minimum(_ value: Float) -> FirebaseGenerationGuide<Float> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: Double(value), maximum: nil))
    )
  }

  static func maximum(_ value: Float) -> FirebaseGenerationGuide<Float> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: nil, maximum: Double(value)))
    )
  }

  static func range(_ range: ClosedRange<Float>) -> FirebaseGenerationGuide<Float> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(minimum: Double(range.lowerBound), maximum: Double(range.upperBound))
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide where Value == Double {
  static func minimum(_ value: Value) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: value, maximum: nil))
    )
  }

  static func maximum(_ value: Value) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(double: DoubleGuides(minimum: nil, maximum: value))
    )
  }

  static func range(_ range: ClosedRange<Value>) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(minimum: range.lowerBound, maximum: range.upperBound)
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide where Value == Decimal {
  static func minimum(_ value: Decimal) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(
          minimum: (value as NSDecimalNumber).doubleValue,
          maximum: nil
        )
      )
    )
  }

  static func maximum(_ value: Decimal) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(
          minimum: nil,
          maximum: (value as NSDecimalNumber).doubleValue
        )
      )
    )
  }

  static func range(_ range: ClosedRange<Decimal>) -> FirebaseGenerationGuide<Value> {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        double: DoubleGuides(
          minimum: (range.lowerBound as NSDecimalNumber).doubleValue,
          maximum: (range.upperBound as NSDecimalNumber).doubleValue
        )
      )
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerationGuide {
  static func minimumCount<Element>(_ count: Int) -> FirebaseGenerationGuide<[Element]>
    where Value == [Element] {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: count, maximumCount: nil, element: nil)
      )
    )
  }

  static func maximumCount<Element>(_ count: Int) -> FirebaseGenerationGuide<[Element]>
    where Value == [Element] {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: nil, maximumCount: count, element: nil)
      )
    )
  }

  static func count<Element>(_ range: ClosedRange<Int>) -> FirebaseGenerationGuide<[Element]>
    where Value == [Element] {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(
          minimumCount: range.lowerBound,
          maximumCount: range.upperBound,
          element: nil
        )
      )
    )
  }

  static func count<Element>(_ count: Int) -> FirebaseGenerationGuide<[Element]>
    where Value == [Element] {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: count, maximumCount: count, element: nil)
      )
    )
  }

  static func element<Element>(_ guide: FirebaseGenerationGuide<Element>)
    -> FirebaseGenerationGuide<[Element]>
    where Value == [Element] {
    FirebaseGenerationGuide(
      wrapped: AnyGenerationGuides(
        array: ArrayGuides(minimumCount: nil, maximumCount: nil, element: guide.wrapped)
      )
    )
  }
}
