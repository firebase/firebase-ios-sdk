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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIDataModels
  import Synchronization

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GenerationSchema {
    /// Returns a Gemini-compatible JSON Schema of this `GenerationSchema`.
    ///
    /// When encoded to JSON, `FoundationModels.GenerationSchema` uses the Foundation Models
    /// `x-order` key for property ordering. This method translates `x-order` to Gemini's expected
    /// `propertyOrdering` key.
    ///
    /// - Returns: A `JSONObject` representing the Gemini-compatible JSON Schema.
    /// - Throws: `LanguageModelError.unsupportedGenerationGuide` if an unsupported regex pattern
    ///   guide is present, or an error if encoding or decoding fails.
    func toGeminiJSONSchema() throws -> JSONObject {
      let hasPatternGuide = Mutex(false)
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .custom { keys in
        guard let lastKey = keys.last else {
          assertionFailure("Unexpected empty coding path.")
          return SchemaCodingKey(stringValue: "")
        }
        if lastKey.stringValue == "pattern" {
          hasPatternGuide.withLock { $0 = true }
        }
        if lastKey.stringValue == "x-order" {
          return SchemaCodingKey(stringValue: "propertyOrdering")
        }
        return lastKey
      }

      let generationSchemaData = try encoder.encode(self)
      if hasPatternGuide.withLock({ $0 }) {
        throw LanguageModelError.unsupportedGenerationGuide(
          LanguageModelError.UnsupportedGenerationGuide(
            schemaName: self.name,
            debugDescription: "Gemini does not support regular expression pattern guides."
          )
        )
      }

      let jsonSchema = try JSONDecoder().decode(JSONObject.self, from: generationSchemaData)

      return jsonSchema
    }

    /// Returns a Gemini-compatible JSON Schema of this `GenerationSchema` as a `JSONValue`.
    ///
    /// - Returns: A `JSONValue.object` representing the Gemini-compatible JSON Schema.
    /// - Throws: `LanguageModelError.unsupportedGenerationGuide` if an unsupported regex pattern
    ///   guide is present, or an error if encoding or decoding fails.
    func toGeminiJSONValue() throws -> JSONValue {
      .object(try toGeminiJSONSchema())
    }

    private struct SchemaCodingKey: CodingKey {
      let stringValue: String
      let intValue: Int? = nil

      init(stringValue: String) {
        self.stringValue = stringValue
      }

      init?(intValue: Int) {
        assertionFailure("Unexpected \(Self.self) with integer value: \(intValue)")
        return nil
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
