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

  /// Translates Foundation Models requests into Gemini API data models.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiRequestTranslator {
    /// Translates a `LanguageModelExecutorGenerationRequest` into a `GenerateContentRequest`.
    ///
    /// - Parameter request: The generation request from the Foundation Models session.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest
    ) throws -> GenerateContentRequest {
      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let generationConfig = try translateGenerationConfig(schema: request.schema)

      return GenerateContentRequest(
        systemInstruction: systemInstruction,
        contents: contents,
        generationConfig: generationConfig
      )
    }

    /// Translates an optional `GenerationSchema` into a Gemini `GenerationConfig`.
    ///
    /// - Parameter schema: An optional generation schema specifying structured output constraints.
    /// - Returns: A `GenerationConfig` configured with response schema, or `nil` if `schema`
    ///   is `nil`.
    /// - Throws: An error if encoding the schema fails or if an unsupported generation guide is
    ///   detected.
    static func translateGenerationConfig(
      schema: GenerationSchema?
    ) throws -> GenerationConfig? {
      guard let schema else { return nil }

      let jsonSchema = try schema.toGeminiJSONSchema()
      let textFormat = TextResponseFormat(
        mimeType: .applicationJson,
        schema: .object(jsonSchema)
      )
      return GenerationConfig(responseFormat: ResponseFormatConfig(text: textFormat))
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
