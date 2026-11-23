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
  /// The JSON value stored inside ``GeneratedContent``.
  ///
  /// Every node carries its own completeness flag, objects store their properties in a
  /// `Dictionary` plus an optional explicit key order, and nested nodes carry no ``GenerationID``.
  /// Equality is synthesized, so it compares the storage (including `order`, where `nil` differs
  /// from an explicit order) and `isComplete` at every level.
  struct ContentNode: Sendable, Equatable {
    /// The kinds of values a node can hold.
    enum Storage: Sendable, Equatable {
      /// A JSON `null`.
      case null

      /// A JSON Boolean.
      case bool(Bool)

      /// A JSON number. All numbers are stored as `Double`.
      case number(Double)

      /// A JSON string.
      case string(String)

      /// A JSON array.
      case array([ContentNode])

      /// A JSON object.
      ///
      /// `order` is `nil` for parsed content, in which case the dictionary's iteration order is
      /// used. Keys in `properties` that are missing from an explicit `order` are hidden from
      /// ``GeneratedContent/jsonString`` and ``GeneratedContent/value(_:forProperty:)``.
      case object(properties: [String: ContentNode], order: [String]?)
    }

    /// The value of this node.
    var storage: Storage

    /// Whether this node was fully generated.
    var isComplete: Bool

    /// Creates a node from its storage and completeness.
    ///
    /// - Parameters:
    ///   - storage: The value of the node.
    ///   - isComplete: Whether the node was fully generated.
    init(_ storage: Storage, isComplete: Bool = true) {
      self.storage = storage
      self.isComplete = isComplete
    }

    /// A complete `null` node.
    static let null = ContentNode(.null)

    /// Creates a complete array node whose completeness is the conjunction of its elements'.
    ///
    /// - Parameter elements: The elements of the array.
    /// - Returns: An array node.
    static func array(_ elements: [ContentNode]) -> ContentNode {
      ContentNode(.array(elements), isComplete: elements.allSatisfy(\.isComplete))
    }

    /// Creates an object node whose completeness is the conjunction of its properties'.
    ///
    /// - Parameters:
    ///   - properties: The properties of the object.
    ///   - order: The explicit key order, or `nil` to use dictionary order.
    /// - Returns: An object node.
    static func object(_ properties: [String: ContentNode], order: [String]?) -> ContentNode {
      ContentNode(
        .object(properties: properties, order: order),
        isComplete: properties.values.allSatisfy(\.isComplete)
      )
    }
  }

  // MARK: - Object helpers

  extension ContentNode {
    /// The keys that are visible through `jsonString`, `kind`, and `value(_:forProperty:)`, in
    /// order, or `nil` if this node isn't an object.
    ///
    /// Keys listed in an explicit order but missing from the properties are included.
    var orderedKeys: [String]? {
      guard case .object(let properties, let order) = storage else { return nil }
      return order ?? Array(properties.keys)
    }

    /// Returns the property for `key` if this node is an object and `key` is visible.
    ///
    /// - Parameter key: The property name.
    /// - Returns: The property value, or `nil` if it's missing or hidden.
    func visibleProperty(_ key: String) -> ContentNode? {
      guard case .object(let properties, let order) = storage else { return nil }
      if let order, !order.contains(key) {
        return nil
      }
      return properties[key]
    }
  }
#endif  // compiler(>=6.4)
