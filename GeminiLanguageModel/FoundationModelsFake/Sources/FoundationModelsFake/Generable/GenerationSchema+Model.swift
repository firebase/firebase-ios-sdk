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

  // MARK: - Internal model

  /// A schema whose resolution is deferred until it's needed.
  ///
  /// Property, element, and union schemas are stored lazily, so a
  /// `Generable` type can refer to itself (for example, `var children: [TreeNode]`) without
  /// recursing forever while its schema is built.
  struct LazyGenerationSchema: Sendable {
    /// Produces the schema.
    let resolve: @Sendable () -> GenerationSchema

    /// Creates a lazy schema from a closure.
    ///
    /// - Parameter resolve: A closure that produces the schema.
    init(_ resolve: @escaping @Sendable () -> GenerationSchema) {
      self.resolve = resolve
    }

    /// The resolved schema.
    var schema: GenerationSchema {
      resolve()
    }
  }

  extension GenerationSchema {
    /// The shape of a schema.
    enum Kind: Sendable {
      /// An object with named properties (`"type": "object"`), hoisted into `$defs` when nested.
      case structure(StructureSchema)

      /// A union of other schemas (`anyOf`), hoisted into `$defs` when nested.
      case union(UnionSchema)

      /// A named string enumeration, inlined wherever it's used.
      case enumeration(EnumerationSchema)

      /// A string, with optional choices and pattern.
      case string(StringGuides)

      /// An integer, with optional bounds.
      case integer(IntegerGuides)

      /// A floating-point number (`Double`, `Float`, or `Decimal`), with optional bounds.
      case double(DoubleGuides)

      /// A Boolean.
      case bool

      /// The JSON `null` value.
      case null

      /// A constant string (`{"const": value}`), produced by ``GenerationGuide/constant(_:)``.
      case constant(String)

      /// An array, with optional count bounds.
      case array(ArraySchema)

      /// An object with arbitrary keys whose values share one schema (`additionalProperties`).
      case dictionary(DictionarySchema)
    }

    /// An object schema.
    struct StructureSchema: Sendable {
      /// The type name, encoded as `title`.
      var name: String

      /// A natural language description of the type.
      var description: String?

      /// Whether `nil` properties are represented explicitly in generated content.
      ///
      /// This doesn't change the JSON schema.
      var representsNilExplicitly: Bool

      /// The properties, in declaration order.
      var properties: [GenerationSchema.Property]
    }

    /// A union schema.
    struct UnionSchema: Sendable {
      /// The type name, encoded as `title`.
      var name: String

      /// A natural language description of the type.
      var description: String?

      /// The schemas this union chooses between.
      var cases: [LazyGenerationSchema]
    }

    /// A string enumeration schema.
    struct EnumerationSchema: Sendable {
      /// The type name, encoded as `title` only when the enumeration is the root.
      var name: String

      /// A natural language description, encoded only when the enumeration is the root.
      var description: String?

      /// The allowed values.
      var cases: [String]
    }

    /// Guides that apply to a string schema.
    struct StringGuides: Sendable {
      /// The allowed values (`enum`).
      var choices: [String]?

      /// A regular expression the value must match (`pattern`).
      var pattern: String?
    }

    /// Guides that apply to an integer schema.
    struct IntegerGuides: Sendable {
      /// The inclusive lower bound.
      var minimum: Int?

      /// The inclusive upper bound.
      var maximum: Int?
    }

    /// Guides that apply to a floating-point schema.
    struct DoubleGuides: Sendable {
      /// The inclusive lower bound.
      var minimum: Double?

      /// The inclusive upper bound.
      var maximum: Double?
    }

    /// An array schema.
    struct ArraySchema: Sendable {
      /// The schema of each element.
      var element: LazyGenerationSchema

      /// The minimum number of elements (`minItems`).
      var minimumCount: Int?

      /// The maximum number of elements (`maxItems`).
      var maximumCount: Int?
    }

    /// A dictionary schema.
    struct DictionarySchema: Sendable {
      /// The schema of each value.
      var value: LazyGenerationSchema
    }
  }

  // MARK: - Names

  extension GenerationSchema.Kind {
    /// The name of a schema of this kind, as reported by ``GenerationSchema/name``.
    var name: String {
      switch self {
      case .structure(let structure): structure.name
      case .union(let union): union.name
      case .enumeration(let enumeration): enumeration.name
      case .string: "String"
      case .integer: "Int"
      case .double: "Double"
      case .bool: "Bool"
      case .null: "Null"
      case .constant(let value): value
      case .array(let array): "Array<\(array.element.schema.name)>"
      case .dictionary(let dictionary): "Dictionary<String, \(dictionary.value.schema.name)>"
      }
    }

    /// The name under which this kind is hoisted into `$defs`, or `nil` if it's always inlined.
    var definitionName: String? {
      switch self {
      case .structure(let structure): structure.name.isEmpty ? nil : structure.name
      case .union(let union): union.name.isEmpty ? nil : union.name
      default: nil
      }
    }

    /// The description of a named type, or `nil` for other kinds.
    var typeDescription: String? {
      switch self {
      case .structure(let structure): structure.description
      case .union(let union): union.description
      case .enumeration(let enumeration): enumeration.description
      default: nil
      }
    }
  }

  // MARK: - Guides

  extension GenerationSchema {
    /// Returns this schema with the given guides applied in order.
    ///
    /// Guides that don't match the schema's kind (for example, a count guide on a string) are
    /// ignored. Bounds merge, so `.minimum(0)` followed by `.maximum(10)` sets both.
    ///
    /// - Parameter guides: The guides to apply.
    /// - Returns: The constrained schema.
    func applying(_ guides: [GenerationGuideKind]) -> GenerationSchema {
      guides.reduce(self) { $0.applying($1) }
    }

    /// Returns this schema with one guide applied.
    ///
    /// - Parameter guide: The guide to apply.
    /// - Returns: The constrained schema.
    func applying(_ guide: GenerationGuideKind) -> GenerationSchema {
      switch (guide, kind) {
      case (.constant(let value), _):
        return GenerationSchema(kind: .constant(value))
      case (.anyOf(let choices), .string(var guides)):
        guides.choices = choices
        return GenerationSchema(kind: .string(guides))
      case (.pattern(let pattern), .string(var guides)):
        guides.pattern = pattern
        return GenerationSchema(kind: .string(guides))
      case (.integerBounds(let minimum, let maximum), .integer(var guides)):
        guides.minimum = minimum ?? guides.minimum
        guides.maximum = maximum ?? guides.maximum
        return GenerationSchema(kind: .integer(guides))
      case (.doubleBounds(let minimum, let maximum), .double(var guides)):
        guides.minimum = minimum ?? guides.minimum
        guides.maximum = maximum ?? guides.maximum
        return GenerationSchema(kind: .double(guides))
      case (.countBounds(let minimum, let maximum), .array(var array)):
        array.minimumCount = minimum ?? array.minimumCount
        array.maximumCount = maximum ?? array.maximumCount
        return GenerationSchema(kind: .array(array))
      case (.element(let elementGuide), .array(var array)):
        let element = array.element
        array.element = LazyGenerationSchema { element.schema.applying(elementGuide) }
        return GenerationSchema(kind: .array(array))
      default:
        return self
      }
    }
  }
#endif  // compiler(>=6.4)
