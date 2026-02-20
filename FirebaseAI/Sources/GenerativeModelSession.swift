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
  public final class GenerativeModelSession: Sendable {
    let generativeModel: GenerativeModel

    public init(model: GenerativeModel) {
      generativeModel = model
    }

    @discardableResult
    public final nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<String> {
      let parts = [ModelContent(parts: prompt)]

      var config = GenerationConfig.merge(
        generativeModel.generationConfig, with: options
      ) ?? GenerationConfig()
      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      let response = try await generativeModel.generateContent(parts, generationConfig: config)
      guard let text = response.text else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No text in response: \(response)")
        )
      }
      let generatedContent = GeneratedContent(kind: .string(text))

      return GenerativeModelSession.Response(
        content: text, rawContent: generatedContent, rawResponse: response
      )
    }

    @discardableResult
    public final nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., schema: GenerationSchema,
                 includeSchemaInPrompt: Bool = true, options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<GeneratedContent> {
      let parts = [ModelContent(parts: prompt)]
      var config = GenerationConfig.merge(
        generativeModel.generationConfig, with: options
      ) ?? GenerationConfig()
      config.responseMIMEType = "application/json"
      config.responseJSONSchema = includeSchemaInPrompt ? try schema.toGeminiJSONSchema() : nil
      config.responseSchema = nil // `responseSchema` must not be set with `responseJSONSchema`
      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      let response = try await generativeModel.generateContent(parts, generationConfig: config)
      guard let text = response.text else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No text in response: \(response)")
        )
      }
      let generatedContent = try GeneratedContent(json: text)

      return GenerativeModelSession.Response(
        content: generatedContent, rawContent: generatedContent, rawResponse: response
      )
    }

    @discardableResult
    public final nonisolated(nonsending)
    func respond<Content>(to prompt: PartsRepresentable...,
                          generating type: Content.Type = Content.self,
                          includeSchemaInPrompt: Bool = true,
                          options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<Content> where Content: Generable {
      let response = try await respond(
        to: prompt,
        schema: type.generationSchema,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )

      let content = try Content(response.rawContent)

      return GenerativeModelSession.Response(
        content: content, rawContent: response.rawContent, rawResponse: response.rawResponse
      )
    }

    public struct Response<Content> where Content: Generable {
      public let content: Content
      public let rawContent: GeneratedContent
      public let rawResponse: GenerateContentResponse
    }

    public enum GenerationError: Error, LocalizedError {
      public struct Context: Sendable {
        public let debugDescription: String

        init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      case decodingFailure(GenerativeModelSession.GenerationError.Context)
    }
  }
#endif // canImport(FoundationModels)
