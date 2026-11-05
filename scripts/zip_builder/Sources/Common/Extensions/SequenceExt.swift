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

public extension Sequence {
  /// Creates a dictionary with sequence elements keyed by the property at the given key path.
  ///
  /// If multiple elements produce duplicate keys, the first element encountered is preserved.
  ///
  /// ```swift
  /// let targets = [targetA, targetB]
  /// let targetMap = targets.keyedBy(\.name)
  /// ```
  ///
  /// - Parameter keyPath: The key path on `Element` used to extract each dictionary key.
  /// - Returns: A dictionary mapping extracted keys to their corresponding elements.
  func keyedBy<Key: Hashable>(_ keyPath: KeyPath<Element, Key>) -> [Key: Element] {
    Dictionary(map { ($0[keyPath: keyPath], $0) }, uniquingKeysWith: { first, _ in first })
  }
}
