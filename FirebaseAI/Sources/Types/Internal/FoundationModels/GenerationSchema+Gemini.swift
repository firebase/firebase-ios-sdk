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
      let jsonData = try JSONEncoder().encode(self)
      var jsonSchema = try JSONDecoder().decode(JSONObject.self, from: jsonData)
      updatePropertyOrdering(&jsonSchema)

      return jsonSchema
    }
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  fileprivate func updatePropertyOrdering(_ schema: inout JSONObject) {
    guard let propertyOrdering = schema.removeValue(forKey: "x-order") else {
      return
    }
    guard case let .array(values) = propertyOrdering else {
      return
    }
    guard values.allSatisfy({
      guard case .string = $0 else { return false }
      return true
    }) else {
      return
    }

    schema["propertyOrdering"] = propertyOrdering
  }
#endif // canImport(FoundationModels)
