// Copyright 2025 Google LLC
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
    func asGeminiJSONSchema() throws -> JSONObject {
      let generationSchemaJSONData = try JSONEncoder().encode(self)
      guard let generationSchemaJSON = String(data: generationSchemaJSONData, encoding: .utf8)
      else {
        fatalError("Failed to convert \(GenerationSchema.self) JSON data to a string.")
      }
      let geminiJSONSchemaJSON = generationSchemaJSON.replacingOccurrences(
        of: "\"x-order\"",
        with: "\"propertyOrdering\""
      )
      guard let geminiJSONSchemaJSONData = geminiJSONSchemaJSON.data(using: .utf8) else {
        fatalError("Failed to convert Gemini JSON Schema to data.")
      }
      return try JSONDecoder().decode(JSONObject.self, from: geminiJSONSchemaJSONData)
    }
  }
#endif // canImport(FoundationModels)
