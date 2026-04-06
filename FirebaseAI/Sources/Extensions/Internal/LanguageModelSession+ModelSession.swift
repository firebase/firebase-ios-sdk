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
  extension FoundationModels.LanguageModelSession: ModelSession {
    func respond(to prompt: any PartsRepresentable, schema: FirebaseAI.GenerationSchema?,
                 includeSchemaInPrompt: Bool, options: GenerationConfig?) async throws
      -> GenerativeModelSession.Response<FirebaseAI.GeneratedContent> {
      let prompt = try prompt.toFoundationModelsPrompt()

      let response: FoundationModels.LanguageModelSession
        .Response<FoundationModels.GeneratedContent>
      if let schema {
        response = try await respond(
          to: prompt,
          schema: schema.generationSchema,
          includeSchemaInPrompt: includeSchemaInPrompt
          // TODO: Add options: GenerationOptions
        )
      } else {
        response = try await respond(
          to: prompt,
          schema: String.generationSchema
        )
      }

      let responseText: String
      if schema == nil, case let .string(text) = response.content.kind {
        responseText = text
      } else {
        responseText = response.content.jsonString
      }

      let generatedContent = response.content.firebaseGeneratedContent
      let modelContent = ModelContent(
        role: "model",
        parts: [InternalPart(.text(responseText), isThought: false, thoughtSignature: nil)]
      )
      let candidate = Candidate(
        content: modelContent,
        safetyRatings: [],
        finishReason: nil,
        citationMetadata: nil
      )
      let rawResponse = GenerateContentResponse(
        candidates: [candidate],
        modelVersion: SystemLanguageModel.modelName
      )

      return GenerativeModelSession.Response(
        content: generatedContent,
        rawContent: generatedContent,
        rawResponse: rawResponse
      )
    }

    func streamResponse<Content, PartialContent>(to prompt: [any PartsRepresentable],
                                                 schema: FirebaseAI.GenerationSchema?,
                                                 generating type: Content.Type,
                                                 includeSchemaInPrompt: Bool,
                                                 options: GenerationConfig?)
      throws -> sending GenerativeModelSession.ResponseStream<Content, PartialContent> {
      // TODO: Create a new error type
      throw NSError(
        domain: Constants.baseErrorDomain,
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Hybrid streaming support is not yet implemented."]
      )
    }
  }
#endif // canImport(FoundationModels)
