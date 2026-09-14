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

import ArgumentParser
import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels

  /// Builds a `FoundationModels.GenerationSchema` from CLI property declarations and modifiers.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct SchemaBuilder: Sendable {
    public enum PropertyKind: Sendable, Equatable {
      case string
      case integer
      case double
      case boolean
      case object(schemaJSON: String?)
    }

    public struct DeclaredProperty: Sendable {
      public var path: [String]
      public var kind: PropertyKind
      public var description: String?
      public var isArray: Bool = false
      public var isOptional: Bool = false

      public init(
        path: [String],
        kind: PropertyKind,
        description: String? = nil,
        isArray: Bool = false,
        isOptional: Bool = false
      ) {
        self.path = path
        self.kind = kind
        self.description = description
        self.isArray = isArray
        self.isOptional = isOptional
      }
    }

    /// Parses command-line arguments to construct a `GenerationSchema`.
    ///
    /// - Parameter arguments: Raw command line arguments following `schema object`.
    /// - Returns: A generated `GenerationSchema`.
    /// - Throws: `ValidationError` if required options are missing or invalid.
    public static func build(from arguments: [String]) throws -> GenerationSchema {
      var rootName: String?
      var properties: [DeclaredProperty] = []
      var anyOfSchemas: [String] = []
      var isAnyOfMode = false

      var index = 0
      while index < arguments.count {
        let arg = arguments[index]
        switch arg {
        case "--name":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing value for --name")
          }
          rootName = arguments[index]

        case "--string":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing property name for --string")
          }
          properties.append(
            DeclaredProperty(path: parsePath(arguments[index]), kind: .string)
          )

        case "--integer", "--int":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing property name for \(arg)")
          }
          properties.append(
            DeclaredProperty(path: parsePath(arguments[index]), kind: .integer)
          )

        case "--double":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing property name for --double")
          }
          properties.append(
            DeclaredProperty(path: parsePath(arguments[index]), kind: .double)
          )

        case "--boolean", "--bool":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing property name for \(arg)")
          }
          properties.append(
            DeclaredProperty(path: parsePath(arguments[index]), kind: .boolean)
          )

        case "--object":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing property name for --object")
          }
          properties.append(
            DeclaredProperty(path: parsePath(arguments[index]), kind: .object(schemaJSON: nil))
          )

        case "--schema":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing schema JSON for --schema")
          }
          let schemaString = arguments[index]
          if isAnyOfMode {
            anyOfSchemas.append(schemaString)
          } else if !properties.isEmpty {
            let lastIdx = properties.count - 1
            if case .object = properties[lastIdx].kind {
              properties[lastIdx].kind = .object(schemaJSON: schemaString)
            }
          }

        case "--anyOf":
          isAnyOfMode = true

        case "--array":
          if !properties.isEmpty {
            properties[properties.count - 1].isArray = true
          }

        case "--description":
          index += 1
          guard index < arguments.count else {
            throw ValidationError("Missing text for --description")
          }
          if !properties.isEmpty {
            properties[properties.count - 1].description = arguments[index]
          }

        case "--optional":
          if !properties.isEmpty {
            properties[properties.count - 1].isOptional = true
          }

        default:
          break
        }
        index += 1
      }

      guard let name = rootName, !name.isEmpty else {
        throw ValidationError("Missing required option: --name <name>")
      }

      if isAnyOfMode && !anyOfSchemas.isEmpty {
        let dependencies: [DynamicGenerationSchema] = []
        var choices: [DynamicGenerationSchema] = []
        for schemaJSON in anyOfSchemas {
          if let data = schemaJSON.data(using: .utf8),
            let genSchema = try? JSONDecoder().decode(GenerationSchema.self, from: data)
          {
            choices.append(DynamicGenerationSchema(referenceTo: genSchema.name))
          }
        }
        let root = DynamicGenerationSchema(name: name, anyOf: choices)
        return try GenerationSchema(root: root, dependencies: dependencies)
      }

      return try buildSchema(name: name, properties: properties)
    }

    private static func parsePath(_ raw: String) -> [String] {
      raw.split(separator: ".").map(String.init)
    }

    private static func buildSchema(
      name: String,
      properties: [DeclaredProperty]
    ) throws -> GenerationSchema {
      var dependencies: [DynamicGenerationSchema] = []
      var rootProperties: [DynamicGenerationSchema.Property] = []

      // Group properties by top-level name
      var topLevelOrder: [String] = []
      var groups: [String: [DeclaredProperty]] = [:]

      for prop in properties {
        guard let first = prop.path.first else { continue }
        if groups[first] == nil {
          topLevelOrder.append(first)
          groups[first] = []
        }
        groups[first]?.append(prop)
      }

      for topLevelKey in topLevelOrder {
        guard let group = groups[topLevelKey], !group.isEmpty else { continue }

        if group.count == 1 && group[0].path.count == 1 {
          let prop = group[0]
          let baseSchema = try makePrimitiveSchema(kind: prop.kind)
          let finalSchema = prop.isArray ? DynamicGenerationSchema(arrayOf: baseSchema) : baseSchema
          rootProperties.append(
            DynamicGenerationSchema.Property(
              name: topLevelKey,
              description: prop.description,
              schema: finalSchema,
              isOptional: prop.isOptional
            )
          )
        } else {
          // Nested object
          let typeName = topLevelKey.prefix(1).uppercased() + topLevelKey.dropFirst()
          var childProperties: [DynamicGenerationSchema.Property] = []

          for prop in group {
            let childName = prop.path.dropFirst().joined(separator: ".")
            guard !childName.isEmpty else { continue }
            let baseSchema = try makePrimitiveSchema(kind: prop.kind)
            let finalSchema =
              prop.isArray ? DynamicGenerationSchema(arrayOf: baseSchema) : baseSchema
            childProperties.append(
              DynamicGenerationSchema.Property(
                name: childName,
                description: prop.description,
                schema: finalSchema,
                isOptional: prop.isOptional
              )
            )
          }

          let nestedObjectSchema = DynamicGenerationSchema(
            name: typeName,
            properties: childProperties
          )
          dependencies.append(nestedObjectSchema)

          let refSchema = DynamicGenerationSchema(referenceTo: typeName)
          let finalRef = group[0].isArray ? DynamicGenerationSchema(arrayOf: refSchema) : refSchema
          rootProperties.append(
            DynamicGenerationSchema.Property(
              name: topLevelKey,
              description: group[0].description,
              schema: finalRef,
              isOptional: group[0].isOptional
            )
          )
        }
      }

      let rootSchema = DynamicGenerationSchema(name: name, properties: rootProperties)
      return try GenerationSchema(root: rootSchema, dependencies: dependencies)
    }

    private static func makePrimitiveSchema(kind: PropertyKind) throws -> DynamicGenerationSchema {
      switch kind {
      case .string:
        return DynamicGenerationSchema(type: String.self)
      case .integer:
        return DynamicGenerationSchema(type: Int.self)
      case .double:
        return DynamicGenerationSchema(type: Double.self)
      case .boolean:
        return DynamicGenerationSchema(type: Bool.self)
      case .object(let schemaJSON):
        if let schemaJSON, let data = schemaJSON.data(using: .utf8),
          let genSchema = try? JSONDecoder().decode(GenerationSchema.self, from: data)
        {
          return DynamicGenerationSchema(referenceTo: genSchema.name)
        }
        return DynamicGenerationSchema(name: "Object", properties: [])
      }
    }

    /// Formats a `GenerationSchema` as a pretty-printed JSON string matching `fm schema object`.
    ///
    /// - Parameter schema: The schema to format.
    /// - Returns: A pretty-printed JSON string.
    public static func formatJSON(_ schema: GenerationSchema) throws -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(schema)
      guard let string = String(data: data, encoding: .utf8) else {
        throw ValidationError("Failed to decode encoded schema JSON as UTF-8 string.")
      }
      return string
    }
  }
#endif
