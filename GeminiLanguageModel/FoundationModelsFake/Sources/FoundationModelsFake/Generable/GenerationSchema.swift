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

  /// A schema that defines the structure and constraints of generated content.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`GenerationSchema`](https://developer.apple.com/documentation/foundationmodels/generationschema).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GenerationSchema: Sendable {
    /// The shape of this schema.
    let kind: Kind
  }

  extension GenerationSchema {
    /// The name of the schema.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var name: String {
      kind.name
    }

    /// The description of the root type, or `nil` if the root isn't a described object, union, or
    /// enumeration.
    var typeDescription: String? {
      kind.typeDescription
    }

    /// Returns whether two schemas encode to the same JSON.
    ///
    /// - Parameter other: The schema to compare with.
    /// - Returns: `true` if both schemas have the same `debugDescription`.
    func isEquivalent(to other: GenerationSchema) -> Bool {
      debugDescription == other.debugDescription
    }
  }

  extension GenerationSchema {
    /// A property within a structured generation schema.
    ///
    /// - SeeAlso: [`GenerationSchema.Property`](https://developer.apple.com/documentation/foundationmodels/generationschema/property)
    public struct Property: Sendable {
      /// The property's name.
      let name: String

      /// A natural language description of what to generate for this property.
      let description: String?

      /// Whether the property may be omitted (it's left out of `required`).
      let isOptional: Bool

      /// The guides to apply to the property's schema.
      let guides: [GenerationGuideKind]

      /// The property's unconstrained schema, resolved lazily.
      let schema: LazyGenerationSchema

      /// Creates a property from its parts.
      ///
      /// - Parameters:
      ///   - name: The property's name.
      ///   - description: A description of the property.
      ///   - isOptional: Whether the property may be omitted.
      ///   - guides: The guides to apply to the property's schema.
      ///   - schema: The property's unconstrained schema.
      init(
        name: String,
        description: String?,
        isOptional: Bool,
        guides: [GenerationGuideKind],
        schema: LazyGenerationSchema
      ) {
        self.name = name
        self.description = description
        self.isOptional = isOptional
        self.guides = guides
        self.schema = schema
      }

      /// The property's schema with its guides applied.
      var resolvedSchema: GenerationSchema {
        schema.schema.applying(guides)
      }
    }
  }

  extension GenerationSchema.Property {
    /// Creates a required property for a generable type.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A description of the property.
    ///   - type: The generable type of the property value.
    ///   - guides: The guides constraining the property value.
    public init<Value>(
      name: String,
      description: String? = nil,
      type: Value.Type,
      guides: [GenerationGuide<Value>] = []
    ) where Value: Generable {
      self.init(
        name: name,
        description: description,
        isOptional: false,
        guides: guides.map(\.kind),
        schema: LazyGenerationSchema { Value.generationSchema }
      )
    }

    /// Creates an optional property for a generable type.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A description of the property.
    ///   - type: The optional generable type of the property value.
    ///   - guides: The guides constraining the property value.
    public init<Value>(
      name: String,
      description: String? = nil,
      type: Value?.Type,
      guides: [GenerationGuide<Value>] = []
    ) where Value: Generable {
      self.init(
        name: name,
        description: description,
        isOptional: true,
        guides: guides.map(\.kind),
        schema: LazyGenerationSchema { Value.generationSchema }
      )
    }

    /// Creates a required string property constrained by regular expression guides.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A description of the property.
    ///   - type: The string type.
    ///   - guides: Regular expression patterns constraining the string.
    public init<RegexOutput>(
      name: String,
      description: String? = nil,
      type: String.Type,
      guides: [Regex<RegexOutput>] = []
    ) {
      self.init(
        name: name,
        description: description,
        isOptional: false,
        guides: guides.last.map { [.pattern($0)] } ?? [],
        schema: LazyGenerationSchema { GenerationSchema._string }
      )
    }

    /// Creates an optional string property constrained by regular expression guides.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A description of the property.
    ///   - type: The optional string type.
    ///   - guides: Regular expression patterns constraining the string.
    public init<RegexOutput>(
      name: String,
      description: String? = nil,
      type: String?.Type,
      guides: [Regex<RegexOutput>] = []
    ) {
      self.init(
        name: name,
        description: description,
        isOptional: true,
        guides: guides.last.map { [.pattern($0)] } ?? [],
        schema: LazyGenerationSchema { GenerationSchema._string }
      )
    }
  }

  extension GenerationSchema {
    /// Creates a structure schema for a generable type and its properties.
    ///
    /// - Parameters:
    ///   - type: The generable type.
    ///   - description: A description of the schema.
    ///   - properties: The properties of the structure.
    public init(
      type: any Generable.Type,
      description: String? = nil,
      properties: [GenerationSchema.Property]
    ) {
      self.init(
        __name: String(describing: type),
        description: description,
        representNilExplicitlyInGeneratedContent: false,
        properties: properties
      )
    }

    /// Creates a structure schema with the given name, properties, and explicit nil behavior.
    ///
    /// The fake's `@Generable` macro expansion calls this initializer; it isn't part of Apple's
    /// API.
    ///
    /// - Parameters:
    ///   - name: The name of the schema.
    ///   - description: A description of the schema.
    ///   - explicitNil: Whether `nil` values are represented explicitly.
    ///   - properties: The properties of the structure.
    @_documentation(visibility: private)
    public init(
      __name name: String,
      description: String? = nil,
      representNilExplicitlyInGeneratedContent explicitNil: Bool = false,
      properties: [GenerationSchema.Property]
    ) {
      self.init(
        kind: .structure(
          StructureSchema(
            name: name,
            description: description,
            representsNilExplicitly: explicitNil,
            properties: properties
          )
        )
      )
    }

    /// Creates an enumeration schema with string choices.
    ///
    /// - Parameters:
    ///   - name: The name of the schema.
    ///   - description: A description of the schema.
    ///   - choices: The allowed string cases.
    @_documentation(visibility: private)
    public init(__name name: String, description: String? = nil, anyOf choices: [String]) {
      self.init(
        kind: .enumeration(EnumerationSchema(name: name, description: description, cases: choices))
      )
    }

    /// Creates a union schema from a list of generable types.
    ///
    /// - Parameters:
    ///   - name: The name of the schema.
    ///   - description: A description of the schema.
    ///   - types: The generable types comprising the union.
    @_documentation(visibility: private)
    public init(
      __name name: String,
      description: String? = nil,
      anyOf types: [any Generable.Type]
    ) {
      let cases = types.map { type in LazyGenerationSchema { type.generationSchema } }
      self.init(kind: .union(UnionSchema(name: name, description: description, cases: cases)))
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension GenerationSchema: Codable {
    /// Decodes a generation schema from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: An error if the schema cannot be decoded.
    public init(from decoder: any Decoder) throws {
      self = try GenerationSchema.decodeRoot(from: decoder)
    }

    /// Encodes this generation schema into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    public func encode(to encoder: any Encoder) throws {
      try jsonSchema().encode(to: encoder)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension GenerationSchema: CustomDebugStringConvertible {
    /// A formatted JSON string representation of the schema for debugging.
    public var debugDescription: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      guard let data = try? encoder.encode(self) else {
        return ""
      }
      return String(decoding: data, as: UTF8.self)
    }
  }

  extension GenerationSchema {
    /// Creates a structure schema for a generable type, specifying explicit nil representation.
    ///
    /// - Parameters:
    ///   - type: The generable type.
    ///   - description: A description of the schema.
    ///   - explicitNil: Whether `nil` values are represented explicitly.
    ///   - properties: The properties of the structure.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(
      type: any Generable.Type,
      description: String? = nil,
      representNilExplicitlyInGeneratedContent explicitNil: Bool,
      properties: [GenerationSchema.Property]
    ) {
      self.init(
        __name: String(describing: type),
        description: description,
        representNilExplicitlyInGeneratedContent: explicitNil,
        properties: properties
      )
    }

    /// Creates an enumeration schema for a generable type with string choices.
    ///
    /// - Parameters:
    ///   - type: The generable type.
    ///   - description: A description of the schema.
    ///   - choices: The allowed string cases.
    public init(type: any Generable.Type, description: String? = nil, anyOf choices: [String]) {
      self.init(__name: String(describing: type), description: description, anyOf: choices)
    }

    /// Creates a union schema for a generable type from a list of member types.
    ///
    /// - Parameters:
    ///   - type: The generable type.
    ///   - description: A description of the schema.
    ///   - types: The generable types comprising the union.
    public init(
      type: any Generable.Type,
      description: String? = nil,
      anyOf types: [any Generable.Type]
    ) {
      self.init(__name: String(describing: type), description: description, anyOf: types)
    }

    /// Creates a generation schema by resolving a dynamic root schema and its dependencies.
    ///
    /// - Parameters:
    ///   - root: The dynamic root schema.
    ///   - dependencies: The dynamic schemas that references may resolve to.
    /// - Throws: An error if reference resolution or validation fails.
    public init(root: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema]) throws {
      self = try DynamicGenerationSchema.resolve(root: root, dependencies: dependencies)
    }
  }
#endif  // compiler(>=6.4)
