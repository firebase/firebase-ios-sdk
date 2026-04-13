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

#if compiler(>=6.2.3) && canImport(FoundationModels)
  import Foundation
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.LanguageModelSession: ModelSession {
    var hasHistory: Bool {
      if transcript.isEmpty {
        return false
      }

      for entry in transcript {
        switch entry {
        case .instructions:
          continue
        case .prompt:
          return true
        case .toolCalls:
          return true
        case .toolOutput:
          return true
        case .response:
          return true
        @unknown default:
          // Unknown entry type, assuming that it is session history.
          return true
        }
      }

      return false
    }

    func respondTo(promptParts: [any Part], schema: FirebaseAI.GenerationSchema?,
                   includeSchemaInPrompt: Bool, options: GenerationConfig?) async throws
      -> ModelSessionResponse {
      let prompt = try promptParts.toFoundationModelsPrompt()

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
          // TODO: Add options: GenerationOptions
        )
      }

      // TODO: Extract common response handling code into a helper method.
      let responseText: String
      if schema == nil, case let .string(text) = response.rawContent.kind {
        responseText = text
      } else {
        responseText = response.rawContent.jsonString
      }

      let generatedContent = response.rawContent.firebaseGeneratedContent
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

      return ModelSessionResponse(rawContent: generatedContent, rawResponse: rawResponse)
    }

    func streamResponseTo(promptParts: [any Part],
                          schema: FirebaseAI.GenerationSchema?,
                          includeSchemaInPrompt: Bool,
                          options: GenerationConfig?)
      -> sending AsyncThrowingStream<ModelSessionResponse, any Error> {
      return AsyncThrowingStream { continuation in
        let prompt: Prompt
        do {
          prompt = try promptParts.toFoundationModelsPrompt()
        } catch {
          continuation.finish(throwing: error)
          return
        }

        let stream: FoundationModels.LanguageModelSession
          .ResponseStream<FoundationModels.GeneratedContent>
        if let schema {
          stream = streamResponse(
            to: prompt,
            schema: schema.generationSchema,
            includeSchemaInPrompt: includeSchemaInPrompt
            // TODO: Add options: GenerationOptions
          )
        } else {
          stream = streamResponse(
            to: prompt,
            schema: String.generationSchema
            // TODO: Check `includeSchemaInPrompt: includeSchemaInPrompt` behaviour with `String`
            // TODO: Add options: GenerationOptions
          )
        }

        let task = Task {
          do {
            for try await snapshot in stream {
              // TODO: Extract common response handling code into a helper method.
              let responseText: String
              if schema == nil, case let .string(text) = snapshot.rawContent.kind {
                responseText = text
              } else {
                responseText = snapshot.rawContent.jsonString
              }

              let generatedContent = snapshot.rawContent.firebaseGeneratedContent
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

              let response = ModelSessionResponse(
                rawContent: generatedContent,
                rawResponse: rawResponse
              )

              continuation.yield(response)
            }
            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
            return
          }
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }
#endif // compiler(>=6.2.3) && canImport(FoundationModels)
