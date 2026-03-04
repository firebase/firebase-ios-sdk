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

import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationSchema {
  /// Returns a Gemini-compatible JSON Schema of this `GenerationSchema`.
  func toGeminiJSONSchema() throws -> JSONObject {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .custom { keys in
      guard let lastKey = keys.last else {
        assertionFailure("Unexpected empty coding path.")
        return SchemaCodingKey(stringValue: "")
      }
      if lastKey.stringValue == "x-order" {
        return SchemaCodingKey(stringValue: "propertyOrdering")
      }
      return lastKey
    }

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        let generationSchemaData = try encoder.encode(self)
        let jsonSchema = try JSONDecoder().decode(JSONObject.self, from: generationSchemaData)

        return jsonSchema
      }
    #endif // canImport(FoundationModels)

    // TODO: Implement FirebaseAI.GenerationSchema encoding for for iOS < 26.
    assertionFailure("TODO: \(Self.self).#\(#function) not yet implemented for iOS < 26.")
    return [:]
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
