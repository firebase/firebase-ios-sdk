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

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.LanguageModelSession: _ModelSession {
    /// Returns `true` if the session has history (i.e., it has already had one or more chat turns).
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    public var _hasHistory: Bool {
      return transcript.contains { entry in
        if case .instructions = entry {
          return false
        }

        return true
      }
    }

    /// Sends a prompt to the model and returns a ``_ModelSessionResponse``.
    ///
    /// > Important: This method is for **internal use only** and may change at any time.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
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

      #if DEBUG
        if AILog.additionalLoggingEnabled() {
          AILog.debug(
            code: .foundationModelsResponseTranscript,
            "Foundation Models Transcript: \(response.transcriptEntries)"
          )
        }
      #endif // DEBUG

      return makeResponse(from: response.rawContent, schema: schema)
    }

    /// Sends a prompt to the model and streams the model's response.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
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
            options: options.generationOptions
          )
        }

        let task = Task {
          do {
            for try await snapshot in stream {
              let response = makeResponse(from: snapshot.rawContent, schema: schema)

              continuation.yield(response)
            }

            #if DEBUG
              if AILog.additionalLoggingEnabled() {
                // Streaming has completed but we call `collect()` to get a
                // `LanguageModelSession.Response`, which contains `transcriptEntries`.
                let response = try await stream.collect()
                AILog.debug(
                  code: .foundationModelsStreamResponseTranscript,
                  "Foundation Models Transcript: \(response.transcriptEntries)"
                )
              }
            #endif // DEBUG

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
        parts: [TextPart(responseText, isThought: false, thoughtSignature: nil)]
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

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
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
