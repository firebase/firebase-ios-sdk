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

#if canImport(FoundationModels)
  import Foundation
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension GenerationSchema {
    /// Returns a Gemini-compatible JSON Schema of this `GenerationSchema`.
    func toGeminiJSONSchema() throws -> JSONObject {
      let generationSchemaData = try JSONEncoder().encode(self)
      guard var jsonSchemaJSON = String(data: generationSchemaData, encoding: .utf8) else {
        throw EncodingError.invalidValue(
          generationSchemaData,
          EncodingError.Context(
            codingPath: [],
            debugDescription: "Failed to convert `GenerationSchema` data to a UTF-8 string."
          )
        )
      }
      jsonSchemaJSON = jsonSchemaJSON.replacingOccurrences(
        of: #""x-order""#, with: #""propertyOrdering""#
      )
      guard let jsonSchemaData = jsonSchemaJSON.data(using: .utf8) else {
        throw EncodingError.invalidValue(
          jsonSchemaJSON,
          EncodingError.Context(
            codingPath: [],
            debugDescription: "Failed to convert JSON Schema string to UTF-8 Data."
          )
        )
      }
      let jsonSchema = try JSONDecoder().decode(JSONObject.self, from: jsonSchemaData)

      return jsonSchema
    }
  }
#endif // canImport(FoundationModels)
