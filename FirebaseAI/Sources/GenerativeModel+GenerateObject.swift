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

import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension GenerativeModel {
  /// Generates a structured object of a specified type that conforms to ``FirebaseGenerable``.
  ///
  /// This method simplifies the process of generating structured data by handling the schema
  /// generation, API request, and JSON decoding automatically.
  ///
  /// - Parameters:
  ///   - type: The `FirebaseGenerable` type to generate.
  ///   - prompt: The text prompt to send to the model.
  /// - Returns: An instance of the requested type, decoded from the model's JSON response.
  /// - Throws: A ``GenerateContentError`` if the model fails to generate the content or if
  ///           the response cannot be decoded into the specified type.
  func generateObject<T: FirebaseGenerable>(as type: T.Type,
                                            from prompt: String) async throws -> T {
    // Create a new generation config, inheriting previous settings and overriding for JSON output.
    let newGenerationConfig = GenerationConfig(
      from: generationConfig,
      responseMIMEType: "application/json",
      responseSchema: T.firebaseGenerationSchema
    )

    // Create a new model instance with the overridden config.
    let model = GenerativeModel(copying: self, generationConfig: newGenerationConfig)
    let response = try await model.generateContent(prompt)

    guard let text = response.text, let data = text.data(using: .utf8) else {
      throw GenerateContentError.internalError(
        underlying: GenerateObjectError.responseTextError("Failed to get response text or data.")
      )
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw GenerateContentError
        .internalError(underlying: GenerateObjectError.jsonDecodingError(error))
    }
  }
}
