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

public extension Array where Element: Equatable {
  /// Returns a Boolean value indicating whether the array contains any of the specified elements.
  ///
  /// ```swift
  /// let numbers = [1, 2, 3]
  /// numbers.containsAny(3, 4, 5) // -> true
  /// numbers.containsAny(7, 8, 9) // -> false
  /// ```
  ///
  /// - Parameter elements: A variadic list of elements to search for.
  /// - Returns: `true` if any of the given elements are found in the array; otherwise, `false`.
  @inlinable func containsAny(_ elements: Element...) -> Bool {
    for element in elements {
      if contains(element) {
        return true
      }
    }

    return false
  }

  /// Returns a Boolean value indicating whether the array contains any of the specified collections
  /// of elements.
  ///
  /// - Parameter elements: An array of collections whose elements match this array's element type.
  /// - Returns: `true` if any of the given collections match an element in this array; otherwise,
  /// `false`.
  @inlinable func containsAny<C: Collection>(_ elements: [C]) -> Bool where C.Element == Element {
    for element in elements {
      if contains(element) {
        return true
      }
    }

    return false
  }
}
