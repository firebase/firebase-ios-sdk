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
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  // MARK: - Encoding

  /// Helpers for comparing encoded schemas.
  enum SchemaJSON {
    /// Returns a schema encoded compactly with sorted keys.
    ///
    /// - Parameter schema: The schema to encode.
    /// - Returns: The JSON text.
    static func compactSortedJSON(_ schema: GenerationSchema) throws -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
      return String(decoding: try encoder.encode(schema), as: UTF8.self)
    }
  }

  // MARK: - Test types

  /// A `Generable` type used only for its schema; its content conversions are placeholders.
  protocol SchemaOnlyGenerable: Generable {}

  /// The error thrown when a schema-only type is created from content.
  struct SchemaOnlyError: Error {}

  extension SchemaOnlyGenerable {
    /// Always throws; schema-only types aren't created from content.
    ///
    /// - Parameter content: Ignored.
    init(_ content: GeneratedContent) throws {
      throw SchemaOnlyError()
    }

    /// Placeholder content.
    var generatedContent: GeneratedContent {
      "".generatedContent
    }
  }

  /// Hand-written `Generable` types, built the way the `@Generable` macro expands them.
  enum SchemaTestTypes {
    /// A simple object with two string properties.
    struct Address: SchemaOnlyGenerable {
      /// The macro-equivalent schema.
      static var generationSchema: GenerationSchema {
        GenerationSchema(
          type: Self.self,
          properties: [
            GenerationSchema.Property(name: "street", type: String.self),
            GenerationSchema.Property(name: "city", type: String.self),
          ]
        )
      }
    }
  }
#endif  // compiler(>=6.4)
