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
  /// A dynamically defined schema describing the structure of generated content.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`DynamicGenerationSchema`](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct DynamicGenerationSchema: Sendable {
    /// The shape of this schema.
    let kind: Kind
  }

  extension DynamicGenerationSchema {
    /// The shape of a dynamic schema.
    indirect enum Kind: Sendable {
      /// A named object.
      case structure(
        name: String,
        description: String?,
        representsNilExplicitly: Bool,
        properties: [Property]
      )

      /// A named string enumeration.
      case enumeration(name: String, description: String?, cases: [String])

      /// A named union of other schemas.
      case union(name: String, description: String?, choices: [DynamicGenerationSchema])

      /// An array.
      case array(element: DynamicGenerationSchema, minimumCount: Int?, maximumCount: Int?)

      /// An object with arbitrary keys whose values share one schema (only produced by decoding).
      case dictionary(value: DynamicGenerationSchema)

      /// A reference to a named schema, resolved by ``GenerationSchema/init(root:dependencies:)``.
      case reference(String)

      /// A reference to the root schema (`{"$ref": "#"}`, only produced by decoding).
      case rootReference

      /// The JSON `null` value.
      case null

      /// A fully formed schema, such as one created from a `Generable` type.
      case schema(GenerationSchema)
    }
  }

  extension DynamicGenerationSchema {
    /// A dynamic schema representing a null value.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var null: DynamicGenerationSchema {
      DynamicGenerationSchema(kind: .null)
    }

    /// Creates a dynamic structure schema with the given name, description, and properties.
    ///
    /// - Parameters:
    ///   - name: The name of the structure schema.
    ///   - description: An optional natural language description of the structure.
    ///   - properties: The properties of the structure.
    public init(
      name: String,
      description: String? = nil,
      properties: [DynamicGenerationSchema.Property]
    ) {
      self.init(
        name: name,
        description: description,
        representNilExplicitlyInGeneratedContent: false,
        properties: properties
      )
    }

    /// Creates a dynamic structure schema, specifying whether nil properties are explicit.
    ///
    /// - Parameters:
    ///   - name: The name of the structure schema.
    ///   - description: An optional natural language description of the structure.
    ///   - explicitNil: Whether `nil` properties are represented explicitly.
    ///   - properties: The properties of the structure.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(
      name: String,
      description: String? = nil,
      representNilExplicitlyInGeneratedContent explicitNil: Bool,
      properties: [DynamicGenerationSchema.Property]
    ) {
      self.init(
        kind: .structure(
          name: name,
          description: description,
          representsNilExplicitly: explicitNil,
          properties: properties
        )
      )
    }

    /// Creates a dynamic union schema that accepts any of the given schemas.
    ///
    /// - Parameters:
    ///   - name: The name of the union schema.
    ///   - description: An optional natural language description of the union.
    ///   - choices: The schemas that make up the union choices.
    public init(name: String, description: String? = nil, anyOf choices: [DynamicGenerationSchema])
    {
      self.init(kind: .union(name: name, description: description, choices: choices))
    }

    /// Creates a dynamic enumeration schema with allowed string choices.
    ///
    /// - Parameters:
    ///   - name: The name of the enumeration schema.
    ///   - description: An optional natural language description of the enumeration.
    ///   - choices: The allowed string values.
    public init(name: String, description: String? = nil, anyOf choices: [String]) {
      self.init(kind: .enumeration(name: name, description: description, cases: choices))
    }

    /// Creates a dynamic array schema with element constraints.
    ///
    /// - Parameters:
    ///   - itemSchema: The schema of the array elements.
    ///   - minimumElements: The minimum number of elements, or `nil`.
    ///   - maximumElements: The maximum number of elements, or `nil`.
    public init(
      arrayOf itemSchema: DynamicGenerationSchema,
      minimumElements: Int? = nil,
      maximumElements: Int? = nil
    ) {
      self.init(
        kind: .array(
          element: itemSchema,
          minimumCount: minimumElements,
          maximumCount: maximumElements
        )
      )
    }

    /// Creates a dynamic schema from a generable type and optional generation guides.
    ///
    /// - Parameters:
    ///   - type: The generable type to base the schema on.
    ///   - guides: Generation guides to apply to the type's schema.
    public init<Value>(
      type: Value.Type,
      guides: [GenerationGuide<Value>] = []
    ) where Value: Generable {
      self.init(kind: .schema(Value.generationSchema.applying(guides.map(\.kind))))
    }

    /// Creates a dynamic schema that references another schema by name.
    ///
    /// - Parameter name: The name of the referenced schema.
    public init(referenceTo name: String) {
      self.init(kind: .reference(name))
    }
  }

  extension DynamicGenerationSchema {
    /// A property definition within a dynamic structure schema.
    ///
    /// - SeeAlso: [`DynamicGenerationSchema.Property`](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/property)
    public struct Property: Sendable {
      /// The property's name.
      let name: String

      /// A natural language description of the property's contents.
      let description: String?

      /// The schema of the property's value.
      let schema: DynamicGenerationSchema

      /// Whether the property may be omitted.
      let isOptional: Bool

      /// Creates a dynamic structure property.
      ///
      /// - Parameters:
      ///   - name: The property's name.
      ///   - description: An optional natural language description of the property.
      ///   - schema: The schema defining the property's value.
      ///   - isOptional: Whether the property may be omitted.
      public init(
        name: String,
        description: String? = nil,
        schema: DynamicGenerationSchema,
        isOptional: Bool = false
      ) {
        self.name = name
        self.description = description
        self.schema = schema
        self.isOptional = isOptional
      }
    }
  }

  extension DynamicGenerationSchema {
    /// The name other schemas can reference this schema by, or `nil` if it isn't a named object,
    /// union, or enumeration.
    var typeName: String? {
      switch kind {
      case .structure(let name, _, _, _): name
      case .enumeration(let name, _, _): name
      case .union(let name, _, _): name
      case .schema(let schema):
        switch schema.kind {
        case .structure, .union, .enumeration: schema.name
        default: nil
        }
      default: nil
      }
    }
  }
#endif  // compiler(>=6.4)
