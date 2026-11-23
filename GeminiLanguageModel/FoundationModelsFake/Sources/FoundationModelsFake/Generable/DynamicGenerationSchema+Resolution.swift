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
  // MARK: - Resolving dynamic schemas

  /// A problem with decoded schema JSON that the public API can't produce, such as a reference
  /// cycle; decoding reports it as a `DecodingError`.
  struct DecodedSchemaError: Error {
    /// A description of the problem.
    let debugDescription: String
  }

  extension DynamicGenerationSchema {
    /// The named schemas that references resolve against.
    private struct ResolutionContext: Sendable {
      /// The root schema, which `{"$ref": "#"}` refers to.
      let root: DynamicGenerationSchema

      /// The named schemas (the named types in the root's tree and the dependencies), keyed by name.
      let definitions: [String: DynamicGenerationSchema]
    }

    /// Validates a root schema and its dependencies and converts them to a generation schema.
    ///
    /// Validation reports, in this order: dependencies whose names collide with each other or with
    /// a named type in the root's tree, objects with duplicate property names, unions or
    /// enumerations with no choices, and references to names that aren't defined. Dependencies
    /// that nothing references are dropped when the schema is encoded.
    ///
    /// - Parameters:
    ///   - root: The root schema.
    ///   - dependencies: The schemas references can resolve to.
    ///   - dependencyNames: The name to register each dependency under, or `nil` to use each
    ///     dependency's own name. Decoding passes the `$defs` keys.
    /// - Returns: The resolved generation schema.
    /// - Throws: ``GenerationSchema/SchemaError``, or ``DecodedSchemaError`` for references that
    ///   only decoded JSON can contain and that can't be resolved.
    static func resolve(
      root: DynamicGenerationSchema,
      dependencies: [DynamicGenerationSchema],
      dependencyNames: [String?]? = nil
    ) throws -> GenerationSchema {
      let rootName = root.typeName
      // Like Apple, every named type in the root's tree (the root itself, inline named objects,
      // unions, and enumerations, and the named types inside `Generable` schemas) can be referenced
      // by name. Repeated names in the root's tree silently share the first definition; only a
      // dependency whose name is already taken is an error.
      var definitions: [String: DynamicGenerationSchema] = [:]
      root.collectNamedTypes(into: &definitions)
      for (index, dependency) in dependencies.enumerated() {
        guard let name = dependencyNames?[index] ?? dependency.typeName else {
          continue
        }
        guard definitions[name] == nil else {
          throw GenerationSchema.SchemaError.duplicateType(
            schema: rootName,
            type: name,
            context: GenerationSchema.SchemaError.Context(
              debugDescription:
                "The type name \(name) is used more than once in \(rootName ?? "the schema")"
            )
          )
        }
        definitions[name] = dependency
      }

      try root.validate()
      for dependency in dependencies {
        try dependency.validate()
      }

      var undefined: [String] = []
      for schema in [root] + dependencies {
        schema.forEachReference { name in
          if definitions[name] == nil, !undefined.contains(name) {
            undefined.append(name)
          }
        }
      }
      guard undefined.isEmpty else {
        throw GenerationSchema.SchemaError.undefinedReferences(
          schema: rootName,
          references: undefined,
          context: GenerationSchema.SchemaError.Context(
            debugDescription:
              "Types referred to but not defined: [\(undefined.joined(separator: ", "))]"
          )
        )
      }

      // Encoding refers back to the root by its name, so an unnamed root (such as an untitled
      // object) that's referenced with `{"$ref": "#"}` would be inlined forever.
      if (rootName ?? "").isEmpty, ([root] + dependencies).contains(where: \.containsRootReference) {
        throw DecodedSchemaError(
          debugDescription: "The root schema is referenced with \"#\" but has no title."
        )
      }

      let context = ResolutionContext(root: root, definitions: definitions)
      // `converted(in:)` follows references eagerly, so a chain of references that never reaches a
      // schema (such as `{"$ref": "#"}` at the root) would recurse forever.
      for schema in [root] + definitions.values {
        try schema.throwIfReferenceCycle(in: context)
      }
      return root.converted(in: context)
    }

    /// Whether this schema or a schema nested in it is a reference to the root (`#`).
    ///
    /// References to named schemas aren't followed.
    private var containsRootReference: Bool {
      switch kind {
      case .structure(_, _, _, let properties):
        properties.contains { $0.schema.containsRootReference }
      case .union(_, _, let choices):
        choices.contains { $0.containsRootReference }
      case .array(let element, _, _):
        element.containsRootReference
      case .dictionary(let value):
        value.containsRootReference
      case .rootReference:
        true
      case .enumeration, .reference, .null, .schema:
        false
      }
    }

    /// Throws if following references from this schema loops without reaching a schema.
    ///
    /// - Parameter context: The named schemas references resolve against.
    /// - Throws: ``DecodedSchemaError`` naming the references in the cycle.
    private func throwIfReferenceCycle(in context: ResolutionContext) throws {
      var chain: [String] = []
      var current = self
      while true {
        let target: String
        let next: DynamicGenerationSchema?
        switch current.kind {
        case .reference(let name):
          target = name
          next = context.definitions[name]
        case .rootReference:
          target = "#"
          next = context.root
        default:
          return
        }
        if let start = chain.firstIndex(of: target) {
          let cycle = chain[start...].joined(separator: ", ")
          throw DecodedSchemaError(
            debugDescription: "References that only refer to each other: [\(cycle)]"
          )
        }
        chain.append(target)
        guard let next else {
          return
        }
        current = next
      }
    }

    /// Registers this schema and the named types nested in it, keeping the first schema registered
    /// under each name.
    ///
    /// References aren't followed.
    ///
    /// - Parameter definitions: The named schemas found so far.
    private func collectNamedTypes(into definitions: inout [String: DynamicGenerationSchema]) {
      if let name = typeName, !name.isEmpty, definitions[name] == nil {
        definitions[name] = self
      }
      switch kind {
      case .structure(_, _, _, let properties):
        for property in properties {
          property.schema.collectNamedTypes(into: &definitions)
        }
      case .union(_, _, let choices):
        for choice in choices {
          choice.collectNamedTypes(into: &definitions)
        }
      case .array(let element, _, _):
        element.collectNamedTypes(into: &definitions)
      case .dictionary(let value):
        value.collectNamedTypes(into: &definitions)
      case .schema(let schema):
        var visited: Set<String> = []
        schema.collectNamedTypes(into: &definitions, visited: &visited)
      case .enumeration, .reference, .rootReference, .null:
        break
      }
    }

    /// Throws if this schema or a schema nested in it has duplicate properties or no choices.
    ///
    /// References aren't followed; each dependency is validated separately.
    ///
    /// - Throws: ``GenerationSchema/SchemaError``.
    private func validate() throws {
      switch kind {
      case .structure(let name, _, _, let properties):
        var seen: Set<String> = []
        for property in properties {
          guard seen.insert(property.name).inserted else {
            throw GenerationSchema.SchemaError.duplicateProperty(
              schema: name,
              property: property.name,
              context: GenerationSchema.SchemaError.Context(
                debugDescription:
                  "The schema \(name) defines the property \(property.name) more than once."
              )
            )
          }
        }
        for property in properties {
          try property.schema.validate()
        }
      case .enumeration(let name, _, let cases):
        guard !cases.isEmpty else {
          throw GenerationSchema.SchemaError.emptyChoices(in: name)
        }
      case .union(let name, _, let choices):
        guard !choices.isEmpty else {
          throw GenerationSchema.SchemaError.emptyChoices(in: name)
        }
        for choice in choices {
          try choice.validate()
        }
      case .array(let element, _, _):
        try element.validate()
      case .dictionary(let value):
        try value.validate()
      case .reference, .rootReference, .null, .schema:
        break
      }
    }

    /// Calls a closure with the name of every reference in this schema, in order.
    ///
    /// - Parameter body: The closure to call.
    private func forEachReference(_ body: (String) -> Void) {
      switch kind {
      case .structure(_, _, _, let properties):
        for property in properties {
          property.schema.forEachReference(body)
        }
      case .union(_, _, let choices):
        for choice in choices {
          choice.forEachReference(body)
        }
      case .array(let element, _, _):
        element.forEachReference(body)
      case .dictionary(let value):
        value.forEachReference(body)
      case .reference(let name):
        body(name)
      case .enumeration, .rootReference, .null, .schema:
        break
      }
    }

    /// Converts this schema to a generation schema, resolving references lazily.
    ///
    /// - Parameter context: The named schemas references resolve against.
    /// - Returns: The generation schema.
    private func converted(in context: ResolutionContext) -> GenerationSchema {
      switch kind {
      case .structure(let name, let description, let explicitNil, let properties):
        let properties = properties.map { property in
          GenerationSchema.Property(
            name: property.name,
            description: property.description,
            isOptional: property.isOptional,
            guides: [],
            schema: LazyGenerationSchema { property.schema.converted(in: context) }
          )
        }
        return GenerationSchema(
          kind: .structure(
            GenerationSchema.StructureSchema(
              name: name,
              description: description,
              representsNilExplicitly: explicitNil,
              properties: properties
            )
          )
        )
      case .enumeration(let name, let description, let cases):
        return GenerationSchema(
          kind: .enumeration(
            GenerationSchema.EnumerationSchema(name: name, description: description, cases: cases)
          )
        )
      case .union(let name, let description, let choices):
        let cases = choices.map { choice in
          LazyGenerationSchema { choice.converted(in: context) }
        }
        return GenerationSchema(
          kind: .union(
            GenerationSchema.UnionSchema(name: name, description: description, cases: cases)
          )
        )
      case .array(let element, let minimumCount, let maximumCount):
        return GenerationSchema(
          kind: .array(
            GenerationSchema.ArraySchema(
              element: LazyGenerationSchema { element.converted(in: context) },
              minimumCount: minimumCount,
              maximumCount: maximumCount
            )
          )
        )
      case .dictionary(let value):
        return GenerationSchema(
          kind: .dictionary(
            GenerationSchema.DictionarySchema(
              value: LazyGenerationSchema { value.converted(in: context) }
            )
          )
        )
      case .reference(let name):
        // Validation guarantees the name is defined; `null` is an unreachable fallback.
        return context.definitions[name]?.converted(in: context) ?? GenerationSchema._null
      case .rootReference:
        return context.root.converted(in: context)
      case .null:
        return GenerationSchema._null
      case .schema(let schema):
        return schema
      }
    }
  }

  extension GenerationSchema.SchemaError {
    /// Returns the error for a union or enumeration with no choices.
    ///
    /// - Parameter name: The schema's name.
    /// - Returns: An ``emptyTypeChoices(schema:context:)`` error.
    fileprivate static func emptyChoices(in name: String) -> GenerationSchema.SchemaError {
      .emptyTypeChoices(
        schema: name,
        context: GenerationSchema.SchemaError.Context(
          debugDescription: "The schema \(name) has an empty list of choices.")
      )
    }
  }

  extension GenerationSchema {
    /// Registers the named types nested in this schema, keeping the first schema registered under
    /// each name.
    ///
    /// - Parameters:
    ///   - definitions: The named schemas found so far.
    ///   - visited: The names already walked, which stops recursive types.
    fileprivate func collectNamedTypes(
      into definitions: inout [String: DynamicGenerationSchema],
      visited: inout Set<String>
    ) {
      let name: String? =
        switch kind {
        case .structure, .union, .enumeration: self.name
        default: nil
        }
      if let name, !name.isEmpty {
        guard visited.insert(name).inserted else {
          return
        }
        if definitions[name] == nil {
          definitions[name] = DynamicGenerationSchema(kind: .schema(self))
        }
      }
      switch kind {
      case .structure(let structure):
        for property in structure.properties {
          property.resolvedSchema.collectNamedTypes(into: &definitions, visited: &visited)
        }
      case .union(let union):
        for choice in union.cases {
          choice.schema.collectNamedTypes(into: &definitions, visited: &visited)
        }
      case .array(let array):
        array.element.schema.collectNamedTypes(into: &definitions, visited: &visited)
      case .dictionary(let dictionary):
        dictionary.value.schema.collectNamedTypes(into: &definitions, visited: &visited)
      default:
        break
      }
    }
  }
#endif  // compiler(>=6.4)
