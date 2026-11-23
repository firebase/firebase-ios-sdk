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
  /// Content produced by a language model or provided as structured input.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`GeneratedContent`](https://developer.apple.com/documentation/foundationmodels/generatedcontent).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeneratedContent: Sendable, Equatable, Generable {
    /// The unique generation identifier associated with this content, or `nil`.
    public var id: GenerationID?

    /// The JSON value. Nested nodes carry no ``GenerationID``.
    var node: ContentNode

    /// Creates content from a JSON node and an identifier.
    ///
    /// - Parameters:
    ///   - node: The JSON value.
    ///   - id: The generation identifier of the top-level content.
    init(node: ContentNode, id: GenerationID?) {
      self.node = node
      self.id = id
    }

    /// Returns whether two generated content instances are equal.
    ///
    /// - Parameters:
    ///   - a: The first content instance.
    ///   - b: The second content instance.
    /// - Returns: `true` if the content instances are equal; otherwise, `false`.
    public static func == (a: GeneratedContent, b: GeneratedContent) -> Bool {
      // The stored nodes (including explicit-versus-nil key order and per-node completeness) and
      // the top-level id are compared. Nested content has no ids to compare.
      a.id == b.id && a.node == b.node
    }
  }

  extension GeneratedContent {
    /// The schema describing arbitrary generated content JSON.
    public static var generationSchema: GenerationSchema {
      GenerationSchema._generatedContent
    }

    /// Creates a copy of the given generated content.
    ///
    /// - Parameter content: The generated content to copy.
    /// - Throws: Never throws; present for protocol conformance.
    public init(_ content: GeneratedContent) throws {
      self = content
    }

    /// The generated content representation of this instance.
    public var generatedContent: GeneratedContent {
      self
    }

    /// Creates a structure from key-value pairs and an optional identifier.
    ///
    /// - Parameters:
    ///   - properties: Key-value pairs representing structure properties.
    ///   - id: The generation identifier, or `nil`.
    public init(
      properties: KeyValuePairs<String, any ConvertibleToGeneratedContent>,
      id: GenerationID? = nil
    ) {
      // `Dictionary(uniqueKeysWithValues:)` traps on duplicates with "Duplicate values for key",
      // like Apple's framework.
      let nodes = Dictionary(
        uniqueKeysWithValues: properties.map { ($0.key, $0.value.generatedContent.node) }
      )
      self.init(node: .object(nodes, order: properties.map(\.key)), id: id)
    }

    /// Creates a structure from a sequence of key-value pairs, resolving duplicate keys.
    ///
    /// - Parameters:
    ///   - properties: A sequence of key-value pairs.
    ///   - id: The generation identifier, or `nil`.
    ///   - combine: A closure called to resolve values for duplicate keys.
    /// - Throws: Rethrows any error thrown by `combine`.
    public init<S>(
      properties: S,
      id: GenerationID? = nil,
      uniquingKeysWith combine: (GeneratedContent, GeneratedContent) throws ->
        some ConvertibleToGeneratedContent
    ) rethrows where S: Sequence, S.Element == (String, any ConvertibleToGeneratedContent) {
      var values: [String: GeneratedContent] = [:]
      var order: [String] = []
      for (key, value) in properties {
        let newValue = value.generatedContent
        guard let existing = values[key] else {
          values[key] = newValue
          order.append(key)
          continue
        }
        let combined = try combine(existing, newValue).generatedContent
        values[key] = combined
        // A duplicated key keeps its first position only when the combiner returns a value equal
        // to the existing one (including a copy of it); any other result, such as the second value
        // or a merged value, moves the key to its latest position.
        if combined != existing, let index = order.firstIndex(of: key) {
          order.remove(at: index)
          order.append(key)
        }
      }
      self.init(node: .object(values.mapValues(\.node), order: order), id: id)
    }

    /// Creates an array from a sequence of elements and an optional identifier.
    ///
    /// - Parameters:
    ///   - elements: A sequence of convertible elements.
    ///   - id: The generation identifier, or `nil`.
    public init<S>(
      elements: S,
      id: GenerationID? = nil
    ) where S: Sequence, S.Element == any ConvertibleToGeneratedContent {
      self.init(node: .array(elements.map { $0.generatedContent.node }), id: id)
    }

    /// Creates generated content from a convertible value.
    ///
    /// - Parameter value: The value to convert into generated content.
    public init(_ value: some ConvertibleToGeneratedContent) {
      self = value.generatedContent
    }

    /// Creates generated content from a convertible value and an explicit identifier.
    ///
    /// - Parameters:
    ///   - value: The value to convert into generated content.
    ///   - id: The generation identifier.
    public init(_ value: some ConvertibleToGeneratedContent, id: GenerationID) {
      self.init(node: value.generatedContent.node, id: id)
    }

    /// Creates generated content by parsing a JSON string.
    ///
    /// - Parameter json: The JSON string to parse.
    /// - Throws: An error if the JSON is malformed.
    public init(json: String) throws {
      self.init(node: try PartialJSONParser.parse(json), id: nil)
    }

    /// The JSON string representation of this generated content.
    public var jsonString: String {
      node.jsonString
    }

    /// Converts this content into the specified type.
    ///
    /// - Parameter type: The target type to convert into.
    /// - Returns: The converted value.
    /// - Throws: An error if conversion to `type` fails.
    public func value<Value>(
      _ type: Value.Type = Value.self
    ) throws -> Value where Value: ConvertibleFromGeneratedContent {
      try Value(self)
    }

    /// Extracts and converts a required property value from this structure.
    ///
    /// - Parameters:
    ///   - type: The target type to convert the property into.
    ///   - property: The name of the property to extract.
    /// - Returns: The converted property value.
    /// - Throws: An error if the property is missing, null, or fails conversion.
    public func value<Value>(
      _ type: Value.Type = Value.self,
      forProperty property: String
    ) throws -> Value where Value: ConvertibleFromGeneratedContent {
      guard let child = try visibleProperty(property), child.storage != .null else {
        throw conversionError("a property '\(property)'")
      }
      return try Value(GeneratedContent(node: child, id: id))
    }

    /// Extracts and converts an optional property value from this structure.
    ///
    /// - Parameters:
    ///   - type: The optional target type to convert the property into.
    ///   - property: The name of the property to extract.
    /// - Returns: The converted property value, or `nil` if missing or null.
    /// - Throws: An error if conversion to `type` fails.
    public func value<Value>(
      _ type: Value?.Type = Value?.self,
      forProperty property: String
    ) throws -> Value? where Value: ConvertibleFromGeneratedContent {
      guard let child = try visibleProperty(property), child.storage != .null else {
        return nil
      }
      return try Value(GeneratedContent(node: child, id: id))
    }

    /// A Boolean value indicating whether this content is complete.
    public var isComplete: Bool {
      node.isComplete
    }
  }

  // MARK: - Conversion helpers

  extension GeneratedContent {
    /// Returns the visible property named `property`.
    ///
    /// - Parameter property: The property name.
    /// - Returns: The property, or `nil` if it's missing or hidden from `orderedKeys`.
    /// - Throws: ``ParsingError`` if this content isn't a structure.
    private func visibleProperty(_ property: String) throws -> ContentNode? {
      guard case .object = node.storage else {
        throw conversionError("an object")
      }
      return node.visibleProperty(property)
    }

    /// Creates the error thrown when content doesn't hold the expected value.
    ///
    /// The message names what was expected and includes the content's JSON, which is also the
    /// error's `rawContent`. Building it doesn't trap for NaN or infinite numbers.
    ///
    /// - Parameter expected: What the content should contain, for example `"String"`, `"an Int"`,
    ///   or `"a property 'name'"`.
    /// - Returns: A parsing error.
    func conversionError(_ expected: String) -> ParsingError {
      let json = node.descriptionForErrors
      return ParsingError(
        rawContent: json,
        debugDescription: "Expected generated content to hold \(expected).\nContent: \(json)"
      )
    }
  }

  extension GeneratedContent {
    /// The kinds of values that generated content can represent.
    ///
    /// - SeeAlso: [`GeneratedContent.Kind`](https://developer.apple.com/documentation/foundationmodels/generatedcontent/kind)
    public enum Kind: Equatable, Sendable {
      /// A null value.
      case null

      /// A Boolean value.
      case bool(Bool)

      /// A numeric value.
      case number(Double)

      /// A string value.
      case string(String)

      /// An array of generated content values.
      case array([GeneratedContent])

      /// A structure value containing named properties and an explicit key order.
      case structure(properties: [String: GeneratedContent], orderedKeys: [String])
    }
  }

  extension GeneratedContent {
    /// Creates generated content representing the specified kind and identifier.
    ///
    /// - Parameters:
    ///   - kind: The kind of value to represent.
    ///   - id: The generation identifier, or `nil`.
    public init(kind: GeneratedContent.Kind, id: GenerationID? = nil) {
      let node: ContentNode
      switch kind {
      case .null:
        node = .null
      case .bool(let value):
        node = ContentNode(.bool(value))
      case .number(let value):
        node = ContentNode(.number(value))
      case .string(let value):
        node = ContentNode(.string(value))
      case .array(let elements):
        node = .array(elements.map(\.node))
      case .structure(let properties, let orderedKeys):
        node = .object(properties.mapValues(\.node), order: orderedKeys)
      }
      self.init(node: node, id: id)
    }

    /// The kind of value represented by this generated content.
    public var kind: GeneratedContent.Kind {
      // Nested content inherits the top-level id, as with Apple's framework.
      switch node.storage {
      case .null:
        return .null
      case .bool(let value):
        return .bool(value)
      case .number(let value):
        return .number(value)
      case .string(let value):
        return .string(value)
      case .array(let elements):
        return .array(elements.map { GeneratedContent(node: $0, id: id) })
      case .object(let properties, let order):
        // Like Apple, `properties` only holds the visible keys: properties missing from an
        // explicit order are left out, although `debugDescription` still shows them.
        var visible = properties
        if let order {
          let listed = Set(order)
          visible = properties.filter { listed.contains($0.key) }
        }
        return .structure(
          properties: visible.mapValues { GeneratedContent(node: $0, id: id) },
          orderedKeys: order ?? Array(properties.keys)
        )
      }
    }
  }
#endif  // compiler(>=6.4)
