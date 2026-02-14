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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct SchemaEncoder {
  enum Target {
    case gemini
    case foundationModels
  }

  let target: Target

  // MARK: - Entry Point

  func encode(_ schema: FirebaseGenerationSchema) throws -> FirebaseGenerationSchema.Internal {
    let state = State(target: target, rootIdentifier: schema.type)
    return try state.process(schema, isRoot: true)
  }

  // MARK: - Encoding State

  private class State {
    /// Stores the encoded schema bodies for types that are referenced by title.
    var definitions: [String: FirebaseGenerationSchema.Internal] = [:]

    /// Tracks the types that have been successfully processed or are currently being processed as
    /// definitions.
    var visitedTypes: Set<FirebaseGenerableType> = []

    /// Tracks the current traversal path to detect infinite recursion in inline (nil-title)
    /// schemas.
    var codingPath: Set<FirebaseGenerableType> = []

    /// The configuration target for this encoding session.
    let target: Target

    /// The identifier of the root schema, used to create recursive references to "#".
    let rootIdentifier: FirebaseGenerableType

    init(target: Target, rootIdentifier: FirebaseGenerableType) {
      self.target = target
      self.rootIdentifier = rootIdentifier
      // Register root immediately to handle recursive references to root
      visitedTypes.insert(rootIdentifier)
    }

    // MARK: - Recursive Processing

    func process(_ schema: FirebaseGenerationSchema, isRoot: Bool) throws -> FirebaseGenerationSchema.Internal {
      // 1. Check for Root Reference
      // If this is not the root call, but the type matches the root, return a ref to "#".
      if !isRoot, schema.type == rootIdentifier {
        return FirebaseGenerationSchema.Internal(ref: "#")
      }

      // 2. Check for Definition Reference
      // If this is not the root call and the schema has a title, it's a candidate for $defs.
      if !isRoot, let title = schema.title {
        if visitedTypes.contains(schema.type) {
          // Already visited (or currently visiting as root/def), return reference
          return FirebaseGenerationSchema.Internal(ref: "#/$defs/\(title)")
        }

        // New Definition:
        visitedTypes.insert(schema.type)
        let body = try encodeBody(schema)
        definitions[title] = body
        return FirebaseGenerationSchema.Internal(ref: "#/$defs/\(title)")
      }

      // 3. Inline Encoding (Recursion Check)
      // Anonymous objects (nil title) must be inlined.
      if codingPath.contains(schema.type) {
        throw FirebaseGenerationSchema.SchemaError.circularDependency(
          type: String(describing: schema.title),
          context: .init(debugDescription: "Circular dependency detected for type \(schema)")
        )
      }

      codingPath.insert(schema.type)
      let body = try encodeBody(schema)
      codingPath.remove(schema.type)

      // 4. Assemble Root
      if isRoot {
        body.defs = definitions.isEmpty ? nil : definitions
        if let title = schema.title {
          body.title = title
        }
      }

      return body
    }

    // MARK: - Body Encoding

    func encodeBody(_ schema: FirebaseGenerationSchema) throws -> FirebaseGenerationSchema.Internal {
      let internalSchema = FirebaseGenerationSchema.Internal()
      internalSchema.description = schema.description

      switch schema.kind {
      case let .string(guides):
        internalSchema.type = .string
        if let anyOf = guides.anyOf {
          internalSchema.enumValues = anyOf.sorted().map { JSONValue.string($0) }
        }

      case let .integer(guides):
        internalSchema.type = .integer
        if let min = guides.minimum { internalSchema.minimum = Double(min) }
        if let max = guides.maximum { internalSchema.maximum = Double(max) }

      case let .double(guides):
        internalSchema.type = .number
        internalSchema.minimum = guides.minimum
        internalSchema.maximum = guides.maximum

      case .boolean:
        internalSchema.type = .boolean

      case let .array(itemType, guides):
        internalSchema.type = .array
        internalSchema.items = try process(itemType.firebaseGenerationSchema, isRoot: false)
        if let min = guides.minimumCount { internalSchema.minItems = min }
        if let max = guides.maximumCount { internalSchema.maxItems = max }

      case let .object(properties):
        internalSchema.type = .object
        internalSchema.additionalProperties = false
        var props: [String: FirebaseGenerationSchema.Internal] = [:]
        var required: [String] = []
        let orderedNames = properties.map(\.name)

        if target == .gemini {
          internalSchema.propertyOrdering = orderedNames
        } else {
          internalSchema.xOrder = orderedNames
        }

        for property in properties {
          let propSchema = property.type.firebaseGenerationSchema
          let internalProp = try process(propSchema, isRoot: false)

          internalProp.description = property.description ?? internalProp.description
          applyIntersectedGuides(to: internalProp, from: property.guides)

          props[property.name] = internalProp
          if !property.isOptional {
            required.append(property.name)
          }
        }
        internalSchema.properties = props
        if !required.isEmpty {
          internalSchema.required = required
        }

      case let .anyOf(types):
        internalSchema.anyOf = try types
          .map { try process($0.firebaseGenerationSchema, isRoot: false) }
      }

      return internalSchema
    }

    // MARK: - Guide Helpers

    /// Merges (intersects) the provided guides into the schema.
    ///
    /// This effectively narrows the allowed values of the schema (e.g., if the schema says
    /// min: 0 and guides says min: 5, the result is min: 5).
    func applyIntersectedGuides(to schema: FirebaseGenerationSchema.Internal,
                                from guides: AnyGenerationGuides) {
      // String narrowing (enum intersection)
      if let s = guides.string {
        if let newAnyOf = s.anyOf {
          let newSet = Set(newAnyOf)
          if let existing = schema.enumValues {
            let existingStrings = existing.compactMap {
              if case let .string(v) = $0 { return v } else { return nil }
            }
            let existingSet = Set(existingStrings)
            let intersection = existingSet.intersection(newSet)
            schema.enumValues = intersection.sorted().map { .string($0) }
          } else {
            schema.enumValues = newAnyOf.sorted().map { .string($0) }
          }
        }
      }

      // Integer narrowing
      if let i = guides.integer {
        if let min = i.minimum {
          schema.minimum = max(schema.minimum ?? -Double.infinity, Double(min))
        }
        if let max = i.maximum {
          schema.maximum = min(schema.maximum ?? Double.infinity, Double(max))
        }
      }

      // Double narrowing
      if let d = guides.double {
        if let min = d.minimum {
          schema.minimum = max(schema.minimum ?? -Double.infinity, min)
        }
        if let max = d.maximum {
          schema.maximum = min(schema.maximum ?? Double.infinity, max)
        }
      }

      // Array narrowing
      if let a = guides.array {
        if let min = a.minimumCount {
          schema.minItems = max(schema.minItems ?? 0, min)
        }
        if let max = a.maximumCount {
          schema.maxItems = min(schema.maxItems ?? Int.max, max)
        }
        // Recursively apply element guides
        if let elementGuides = a.element, let itemsSchema = schema.items {
          applyIntersectedGuides(to: itemsSchema, from: elementGuides)
        }
      }
    }
  }
}
