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
  extension FoundationModels.LanguageModelSession: _ModelSession {
    public var _hasHistory: Bool {
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

    public func _respond(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: any GenerationOptionsRepresentable) async throws
      -> _ModelSessionResponse {
      let prompt = try prompt.toFoundationModelsPrompt()

      let response: FoundationModels.LanguageModelSession
        .Response<FoundationModels.GeneratedContent>
      if let schema {
        response = try await respond(
          to: prompt,
          schema: schema.generationSchema,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options.generationOptions
        )
      } else {
        response = try await respond(
          to: prompt,
          schema: String.generationSchema,
          options: options.generationOptions
        )
      }

      return makeResponse(from: response.rawContent, schema: schema)
    }

    public func _streamResponse(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                                includeSchemaInPrompt: Bool,
                                options: any GenerationOptionsRepresentable)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
      return AsyncThrowingStream { continuation in
        let foundationModelsPrompt: Prompt
        do {
          foundationModelsPrompt = try prompt.toFoundationModelsPrompt()
        } catch {
          continuation.finish(throwing: error)
          return
        }

        let stream: FoundationModels.LanguageModelSession
          .ResponseStream<FoundationModels.GeneratedContent>
        if let schema {
          stream = streamResponse(
            to: foundationModelsPrompt,
            schema: schema.generationSchema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options.generationOptions
          )
        } else {
          stream = streamResponse(
            to: foundationModelsPrompt,
            schema: String.generationSchema,
            // TODO: Check `includeSchemaInPrompt: includeSchemaInPrompt` behaviour with `String`
            options: options.generationOptions
          )
        }

        let task = Task {
          do {
            for try await snapshot in stream {
              let response = makeResponse(from: snapshot.rawContent, schema: schema)

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

    private func makeResponse(from content: FoundationModels.GeneratedContent,
                              schema: FirebaseAI.GenerationSchema?) -> _ModelSessionResponse {
      let responseText: String
      if schema == nil, case let .string(text) = content.kind {
        responseText = text
      } else {
        responseText = content.jsonString
      }

      let generatedContent = content.firebaseGeneratedContent
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
        modelVersion: FirebaseAI.SystemLanguageModel.modelName
      )

      return _ModelSessionResponse(rawContent: generatedContent, rawResponse: rawResponse)
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  private extension GenerationOptionsRepresentable {
    var generationOptions: FoundationModels.GenerationOptions {
      guard let options = responseGenerationOptions.foundationModelsGenerationOptions else {
        return FoundationModels.GenerationOptions()
      }

      return options.toFoundationModels()
    }
  }
#endif // compiler(>=6.2.3) && canImport(FoundationModels)
