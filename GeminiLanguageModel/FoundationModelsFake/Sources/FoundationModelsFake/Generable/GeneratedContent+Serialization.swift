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

  // MARK: - jsonString

  extension ContentNode {
    /// Serializes the node for `GeneratedContent.jsonString`.
    ///
    /// Separators are `", "` and `": "`, there are no newlines, `/` isn't escaped, and object keys
    /// follow the explicit order (or dictionary order when there is none). Hidden keys are dropped.
    ///
    /// - Important: Like Apple's framework, this traps when an explicit order names a key that
    ///   has no property, and when a number is NaN or infinite.
    var jsonString: String {
      var result = ""
      appendJSONString(to: &result, trapsOnNonFiniteNumbers: true)
      return result
    }

    /// The `jsonString` form of this node for error messages, with NaN and infinite numbers
    /// written as `nan` and `inf` instead of trapping.
    var descriptionForErrors: String {
      var result = ""
      appendJSONString(to: &result, trapsOnNonFiniteNumbers: false)
      return result
    }

    /// Appends the `jsonString` form of this node to `result`.
    ///
    /// - Parameters:
    ///   - result: The string to append to.
    ///   - trapsOnNonFiniteNumbers: Whether a NaN or infinite number traps. When `false`, such
    ///     numbers are written with `Double.description`.
    func appendJSONString(to result: inout String, trapsOnNonFiniteNumbers: Bool) {
      switch storage {
      case .null:
        result += "null"
      case .bool(let value):
        result += value ? "true" : "false"
      case .number(let value):
        guard let formatted = ContentNode.formatNumber(value) else {
          guard trapsOnNonFiniteNumbers else {
            result += value.description
            return
          }
          fatalError("Can't write the non-finite number \(value) as JSON.")
        }
        result += formatted
      case .string(let value):
        ContentNode.appendQuoted(value, to: &result, escapingSlashes: false)
      case .array(let elements):
        result += "["
        for (index, element) in elements.enumerated() {
          if index > 0 {
            result += ", "
          }
          element.appendJSONString(to: &result, trapsOnNonFiniteNumbers: trapsOnNonFiniteNumbers)
        }
        result += "]"
      case .object(let properties, let order):
        result += "{"
        let keys = order ?? Array(properties.keys)
        for (index, key) in keys.enumerated() {
          guard let value = properties[key] else {
            fatalError("The key order names '\(key)', which has no property.")
          }
          if index > 0 {
            result += ", "
          }
          ContentNode.appendQuoted(key, to: &result, escapingSlashes: false)
          result += ": "
          value.appendJSONString(to: &result, trapsOnNonFiniteNumbers: trapsOnNonFiniteNumbers)
        }
        result += "}"
      }
    }

    /// Formats a number like `JSONEncoder`: integral values have no fraction, and other values use
    /// the shortest round-trip form (`1e+20`, `1e-07`, `0.1`).
    ///
    /// - Parameter value: The number to format.
    /// - Returns: The formatted number, or `nil` if `value` is NaN or infinite.
    static func formatNumber(_ value: Double) -> String? {
      guard value.isFinite else { return nil }
      var text = value.description
      if text.hasSuffix(".0") {
        text.removeLast(2)
      }
      return text
    }

    /// Appends `value` as a quoted JSON string, escaping like `JSONEncoder`.
    ///
    /// Escapes `"`, `\`, `\b`, `\f`, `\n`, `\r`, `\t`, and other control characters as lowercase
    /// `\u00xx`. DEL (0x7F) and non-ASCII characters are written as is.
    ///
    /// - Parameters:
    ///   - value: The string to quote.
    ///   - result: The string to append to.
    ///   - escapingSlashes: Whether to escape `/` as `\/`.
    static func appendQuoted(_ value: String, to result: inout String, escapingSlashes: Bool) {
      result += "\""
      for scalar in value.unicodeScalars {
        switch scalar {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        case "/" where escapingSlashes: result += "\\/"
        case "\u{08}": result += "\\b"
        case "\u{0C}": result += "\\f"
        case "\n": result += "\\n"
        case "\r": result += "\\r"
        case "\t": result += "\\t"
        case "\u{00}"..."\u{1F}":
          let hex = String(scalar.value, radix: 16, uppercase: false)
          result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        default:
          result.unicodeScalars.append(scalar)
        }
      }
      result += "\""
    }
  }

  // MARK: - Codable bridge

  /// A `Codable` wrapper that encodes ``GeneratedContent`` as a plain JSON value.
  ///
  /// Apple's `GeneratedContent` isn't `Codable`, but the transcript format embeds generated content
  /// (structured segments, metadata) as JSON. Use this wrapper inside `Codable` containers:
  ///
  /// - Encoding writes the JSON value, including hidden keys (those missing from `orderedKeys`), like
  ///   Apple's `debugDescription`. Keys are handed to the keyed container in `orderedKeys` order
  ///   followed by hidden keys, but the output order is up to the encoder: `JSONEncoder` on Darwin
  ///   writes keyed containers in hash order unless you set `.sortedKeys`. Encoding throws
  ///   `EncodingError.invalidValue` for NaN or infinite numbers.
  /// - Decoding produces the same content as Apple's framework: every node complete, objects with `order:
  ///   nil` (so decoded content isn't `==` to content built with explicit key order), and a `nil`
  ///   ``GenerationID``. Unlike ``GeneratedContent/init(json:)``, a top-level number decodes as
  ///   complete.
  struct CodableGeneratedContent: Codable, Sendable, Equatable {
    /// The wrapped content.
    var content: GeneratedContent

    /// Wraps generated content for encoding.
    ///
    /// - Parameter content: The content to encode.
    init(_ content: GeneratedContent) {
      self.content = content
    }

    /// Decodes generated content from any JSON value.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: `DecodingError` if the value isn't JSON-compatible.
    init(from decoder: any Decoder) throws {
      let node = try CodableGeneratedJSON(from: decoder).node
      self.content = GeneratedContent(node: node, id: nil)
    }

    /// Encodes the content as a plain JSON value.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: `EncodingError.invalidValue` for NaN or infinite numbers.
    func encode(to encoder: any Encoder) throws {
      try CodableGeneratedJSON(content.node).encode(to: encoder)
    }
  }

  /// The `Codable` implementation behind ``CodableGeneratedContent``, one node at a time.
  struct CodableGeneratedJSON: Codable {
    /// A coding key for arbitrary object property names.
    struct PropertyKey: CodingKey {
      /// The property name.
      var stringValue: String

      /// Always `nil`; property keys are strings.
      var intValue: Int? { nil }

      /// Creates a key for a property name.
      ///
      /// - Parameter stringValue: The property name.
      init(stringValue: String) {
        self.stringValue = stringValue
      }

      /// Returns `nil`; property keys are strings.
      ///
      /// - Parameter intValue: Ignored.
      init?(intValue: Int) {
        nil
      }
    }

    /// The wrapped node.
    var node: ContentNode

    /// Wraps a node for encoding.
    ///
    /// - Parameter node: The node to encode.
    init(_ node: ContentNode) {
      self.node = node
    }

    /// Decodes a node from any JSON value. Every decoded node is complete and objects have no
    /// explicit order.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: `DecodingError` if the value isn't JSON-compatible.
    init(from decoder: any Decoder) throws {
      if let container = try? decoder.container(keyedBy: PropertyKey.self) {
        var properties: [String: ContentNode] = [:]
        for key in container.allKeys {
          properties[key.stringValue] = try container.decode(CodableGeneratedJSON.self, forKey: key)
            .node
        }
        self.node = ContentNode(.object(properties: properties, order: nil))
        return
      }
      if var container = try? decoder.unkeyedContainer() {
        var elements: [ContentNode] = []
        while !container.isAtEnd {
          elements.append(try container.decode(CodableGeneratedJSON.self).node)
        }
        self.node = ContentNode(.array(elements))
        return
      }
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self.node = .null
      } else if let value = try? container.decode(Bool.self) {
        self.node = ContentNode(.bool(value))
      } else if let value = try? container.decode(Double.self) {
        self.node = ContentNode(.number(value))
      } else {
        self.node = ContentNode(.string(try container.decode(String.self)))
      }
    }

    /// Encodes the node as a plain JSON value.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: `EncodingError.invalidValue` for NaN or infinite numbers.
    func encode(to encoder: any Encoder) throws {
      switch node.storage {
      case .null:
        var container = encoder.singleValueContainer()
        try container.encodeNil()
      case .bool(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .number(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .string(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .array(let elements):
        var container = encoder.unkeyedContainer()
        for element in elements {
          try container.encode(CodableGeneratedJSON(element))
        }
      case .object(let properties, let order):
        var container = encoder.container(keyedBy: PropertyKey.self)
        var keys: [String]
        if let order {
          let visible = Set(order)
          keys = order.filter { properties[$0] != nil }
          keys += properties.keys.filter { !visible.contains($0) }.sorted()
        } else {
          keys = Array(properties.keys)
        }
        for key in keys {
          guard let value = properties[key] else { continue }
          try container.encode(CodableGeneratedJSON(value), forKey: PropertyKey(stringValue: key))
        }
      }
    }
  }

  // MARK: - debugDescription

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeneratedContent: CustomDebugStringConvertible {
    /// A compact JSON string representation of the generated content for debugging.
    public var debugDescription: String {
      // Apple's debugDescription is compact JSON of every property (including
      // hidden ones), with `/` escaped, in hash order. This writes the same format directly so the
      // key order is stable: `orderedKeys` first, then hidden keys in sorted order.
      var result = ""
      node.appendCompactJSON(to: &result)
      return result
    }
  }

  extension ContentNode {
    /// Appends the compact `JSONEncoder`-style form of this node, including hidden keys.
    ///
    /// Unlike `jsonString`, this never traps: non-finite numbers are written with their Swift
    /// description and keys missing from the properties are skipped.
    ///
    /// - Parameter result: The string to append to.
    func appendCompactJSON(to result: inout String) {
      switch storage {
      case .null:
        result += "null"
      case .bool(let value):
        result += value ? "true" : "false"
      case .number(let value):
        result += ContentNode.formatNumber(value) ?? value.description
      case .string(let value):
        ContentNode.appendQuoted(value, to: &result, escapingSlashes: true)
      case .array(let elements):
        result += "["
        for (index, element) in elements.enumerated() {
          if index > 0 {
            result += ","
          }
          element.appendCompactJSON(to: &result)
        }
        result += "]"
      case .object(let properties, let order):
        result += "{"
        var keys: [String]
        if let order {
          let listed = Set(order)
          keys = order.filter { properties[$0] != nil }
          keys += properties.keys.filter { !listed.contains($0) }.sorted()
        } else {
          keys = Array(properties.keys)
        }
        for (index, key) in keys.enumerated() {
          guard let value = properties[key] else { continue }
          if index > 0 {
            result += ","
          }
          ContentNode.appendQuoted(key, to: &result, escapingSlashes: true)
          result += ":"
          value.appendCompactJSON(to: &result)
        }
        result += "}"
      }
    }
  }
#endif  // compiler(>=6.4)
