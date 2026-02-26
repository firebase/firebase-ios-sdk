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
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .custom { keys in
        let lastKey = keys.last!
        if lastKey.stringValue == "x-order" {
          return SchemaCodingKey(stringValue: "propertyOrdering")
        }
        return lastKey
      }

      let generationSchemaData = try encoder.encode(self)
      let jsonSchema = try JSONDecoder().decode(JSONObject.self, from: generationSchemaData)

      return jsonSchema
    }

    private struct SchemaCodingKey: CodingKey {
      let stringValue: String
      let intValue: Int? = nil

      init(stringValue: String) {
        self.stringValue = stringValue
      }

      init?(intValue: Int) {
        assertionFailure("Unexpected \(Self.self) with integer value: \(intValue)")
        stringValue = String(intValue)
      }
    }
  }
#endif // canImport(FoundationModels)
