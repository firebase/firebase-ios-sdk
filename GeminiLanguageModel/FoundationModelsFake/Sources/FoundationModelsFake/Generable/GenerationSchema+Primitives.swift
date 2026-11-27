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
  // MARK: - Schemas for the standard `Generable` conformances

  extension GenerationSchema {
    /// The schema of `String`: `{"type": "string"}`, named `String`.
    static let _string = GenerationSchema(kind: .string(StringGuides()))

    /// The schema of `Int`: `{"type": "integer"}`, named `Int`.
    static let _integer = GenerationSchema(kind: .integer(IntegerGuides()))

    /// The schema of `Double`, `Float`, and `Decimal`: `{"type": "number"}`, named `Double`.
    static let _double = GenerationSchema(kind: .double(DoubleGuides()))

    /// The schema of `Bool`: `{"type": "boolean"}`, named `Bool`.
    static let _boolean = GenerationSchema(kind: .bool)

    /// The `null` schema: `{"type": "null"}`, named `Null`.
    static let _null = GenerationSchema(kind: .null)

    /// The schema of an array whose elements match another schema, named `Array<Element>`.
    ///
    /// The element schema is resolved lazily so that recursive types don't recurse forever.
    ///
    /// - Parameter element: The schema of each element.
    /// - Returns: An array schema.
    static func _array(
      of element: @autoclosure @escaping @Sendable () -> GenerationSchema
    ) -> GenerationSchema {
      GenerationSchema(kind: .array(ArraySchema(element: LazyGenerationSchema(element))))
    }

    /// The schema of `GeneratedContent`: any legal JSON, named `GeneratedContent`.
    ///
    /// It's a union of an object whose values are any legal JSON, an array of any legal JSON, a
    /// Boolean, a number, and a string. The nested references encode as `{"$ref": "#"}` when this
    /// schema is the root.
    static var _generatedContent: GenerationSchema {
      GenerationSchema(
        kind: .union(
          UnionSchema(
            name: "GeneratedContent",
            description: "Any legal JSON",
            cases: [
              LazyGenerationSchema {
                GenerationSchema(
                  kind: .dictionary(
                    DictionarySchema(
                      value: LazyGenerationSchema { GenerationSchema._generatedContent })
                  )
                )
              },
              LazyGenerationSchema {
                GenerationSchema._array(of: GenerationSchema._generatedContent)
              },
              LazyGenerationSchema { GenerationSchema._boolean },
              LazyGenerationSchema { GenerationSchema._double },
              LazyGenerationSchema { GenerationSchema._string },
            ]
          )
        )
      )
    }
  }
#endif  // compiler(>=6.4)
