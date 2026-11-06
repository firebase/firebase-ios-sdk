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
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  extension GenerationSchema {
    /// An error that occurs during schema validation or construction.
    ///
    /// - SeeAlso: [`GenerationSchema.SchemaError`](https://developer.apple.com/documentation/foundationmodels/generationschema/schemaerror)
    @nonexhaustive
    public enum SchemaError: Error, LocalizedError {
      /// An error indicating that multiple types share the same name in a schema.
      case duplicateType(
        schema: String?, type: String, context: GenerationSchema.SchemaError.Context)

      /// An error indicating that a schema defines multiple properties with the same name.
      case duplicateProperty(
        schema: String,
        property: String,
        context: GenerationSchema.SchemaError.Context
      )

      /// An error indicating that a union schema provides no type choices.
      case emptyTypeChoices(schema: String, context: GenerationSchema.SchemaError.Context)

      /// An error indicating that a schema references type names that are not defined.
      case undefinedReferences(
        schema: String?,
        references: [String],
        context: GenerationSchema.SchemaError.Context
      )
    }
  }

  extension GenerationSchema.SchemaError {
    /// Contextual information associated with a schema error.
    ///
    /// - SeeAlso: [`GenerationSchema.SchemaError.Context`](https://developer.apple.com/documentation/foundationmodels/generationschema/schemaerror/context)
    public struct Context: Sendable {
      /// A textual description of the schema error context.
      public let debugDescription: String

      /// Creates a schema error context with the given debug description.
      ///
      /// - Parameter debugDescription: A description of the error context.
      public init(debugDescription: String) {
        self.debugDescription = debugDescription
      }
    }
  }

  extension GenerationSchema.SchemaError {
    /// A localized message describing the schema error.
    public var errorDescription: String? {
      switch self {
      case .duplicateType(let schema, let type, _):
        return "The type name \(type) is used more than once in \(schema ?? "the schema")"
      case .duplicateProperty(let schema, let property, _):
        return "The property \(property) is declared more than once in \(schema)"
      case .emptyTypeChoices(let schema, _):
        return "\(schema) offers no type choices"
      case .undefinedReferences(let schema, let references, _):
        let list = references.joined(separator: ", ")
        return "\(schema ?? "The schema") refers to types that aren't defined: [\(list)]"
      }
    }

    /// A localized suggestion for recovering from the schema error.
    public var recoverySuggestion: String? {
      switch self {
      case .duplicateType:
        "Give each type a unique name."
      case .duplicateProperty:
        "Give each property a unique name."
      case .emptyTypeChoices:
        "Add at least one choice."
      case .undefinedReferences:
        "Add a dependency schema for each referenced type."
      }
    }
  }
#endif  // compiler(>=6.4)
