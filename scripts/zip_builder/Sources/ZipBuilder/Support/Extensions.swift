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

extension Sequence {
  /// The elements in order, keeping only the first with each `key`.
  func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
    var seen = Set<Key>()
    return filter { seen.insert(key($0)).inserted }
  }
}

extension Sequence where Element: Hashable {
  /// The elements in order, keeping only the first of each.
  func uniqued() -> [Element] {
    uniqued(by: { $0 })
  }
}

extension Sequence where Element: Sequence, Element.Element: Equatable {
  /// Returns a flat array containing the unique elements of the nested sequences in order.
  ///
  /// Only needs `Equatable`, unlike `uniqued()`: privacy manifests union `NSDictionary` entries,
  /// which should compare by value without relying on how they hash.
  func union() -> [Element.Element] {
    joined().reduce(into: []) { result, element in
      if !result.contains(element) {
        result.append(element)
      }
    }
  }
}
