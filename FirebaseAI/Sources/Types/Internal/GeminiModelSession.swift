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
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

#if compiler(>=6.2.3)
  /// An object that represents a back-and-forth chat with a model, capturing the history and saving
  /// the context in memory between each message sent.
  final class GeminiModelSession: _ModelSession {
    let chat: Chat
    private let functionDeclarations: [String: FunctionDeclaration]

    init(model: GenerativeModel, history: [ModelContent]) {
      chat = model.startChat(history: history)
      functionDeclarations = model.functionDeclarationsByName()
    }

    // MARK: ModelSession Conformance

    /// Returns `true` if the session has history (i.e., it has already had one or more chat turns).
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    var _hasHistory: Bool {
      return !chat.history.isEmpty
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
    nonisolated(nonsending)
    func _respond(to prompt: [any Part],
                  schema: FirebaseAI.GenerationSchema?,
                  includeSchemaInPrompt: Bool,
                  options: any GenerationOptionsRepresentable) async throws
      -> _ModelSessionResponse {
      let parts = [ModelContent(parts: prompt)]
      let config = try buildConfig(
        options: options.responseGenerationOptions.geminiGenerationConfig,
        schema: schema,
        includeSchemaInPrompt: includeSchemaInPrompt
      )

      var response = try await chat.sendMessage(parts, generationConfig: config)

      var autoFunctionCallTurns = 0
      while !response.functionCalls.isEmpty {
        guard autoFunctionCallTurns < GenerativeModelSession.maxAutoFunctionCallTurns else {
          throw GenerativeModelSession.GenerationError.internalError(
            GenerativeModelSession.GenerationError.Context(
              debugDescription: """
              The model exceeded the maximum allowed automatic function call iterations \
              (\(GenerativeModelSession.maxAutoFunctionCallTurns)).
              """
            ),
            underlyingError: GenerativeModelSession.FunctionCallingError
              .maxFunctionCallTurnsExceeded
          )
        }

        let functionResponses = try await execute(functionCalls: response.functionCalls)

        guard !functionResponses.isEmpty else { break }
        response = try await chat.sendMessage(
          [ModelContent(role: "user", parts: functionResponses)],
          generationConfig: config
        )

        autoFunctionCallTurns += 1
      }

      let text: String
      if let responseText = response.text(isThought: false) {
        text = responseText
      } else if let parts = response.candidates.first?.content.parts, !parts.isEmpty {
        text = ""
      } else {
        throw GenerativeModelSession.GenerationError.decodingFailure(
          GenerativeModelSession.GenerationError
            .Context(debugDescription: "No parts in response: \(response)")
        )
      }
      let generationID = response.responseID.map {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return FirebaseAI.GenerationID(responseID: $0, generationID: GenerationID())
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

        return FirebaseAI.GenerationID(responseID: $0, generationID: nil)
      }

      let rawContent = try GenerativeModelSession.makeRawContent(
        from: text,
        generationID: generationID,
        hasSchema: schema != nil,
        isComplete: true
      )

      return _ModelSessionResponse(rawContent: rawContent, rawResponse: response)
    }

    /// Sends a prompt to the model and streams the model's response.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
    @available(macOS 12.0, watchOS 8.0, *)
    func _streamResponse(to prompt: [any Part],
                         schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: any GenerationOptionsRepresentable)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
      let initialParts = [ModelContent(parts: prompt)]
      return AsyncThrowingStream { continuation in
        let task = Task {
          do {
            let config = try self.buildConfig(
              options: options.responseGenerationOptions.geminiGenerationConfig,
              schema: schema,
              includeSchemaInPrompt: includeSchemaInPrompt
            )

            var currentParts = initialParts
            var generationID: FirebaseAI.GenerationID?
            var autoFunctionCallTurns = 0

            functionCallingLoop: while true {
              let stream = try self.chat.sendMessageStream(currentParts, generationConfig: config)

              var streamedText = ""
              var functionCalls = [FunctionCallPart]()

              // 1. Create a buffer to hold the previous iteration's data in order to differentiate
              //    the last chunk to accurately set `isComplete`.
              var pendingChunkData: (
                text: String,
                id: FirebaseAI.GenerationID?,
                response: GenerateContentResponse
              )?

              for try await chunk in stream {
                functionCalls.append(contentsOf: chunk.functionCalls)

                let text: String
                if let responseText = chunk.text(isThought: false) {
                  text = responseText
                } else if let parts = chunk.candidates.first?.content.parts, !parts.isEmpty {
                  text = ""
                } else {
                  throw GenerativeModelSession.GenerationError.decodingFailure(
                    GenerativeModelSession.GenerationError
                      .Context(debugDescription: "No parts in response: \(chunk)")
                  )
                }

                // 2. If we have pending data, we now know it wasn't the last chunk.
                if let pending = pendingChunkData,
                   !pending.text.isEmpty || pending.response.text(isThought: true) != nil {
                  let rawContent = try GenerativeModelSession.makeRawContent(
                    from: pending.text,
                    generationID: pending.id,
                    hasSchema: schema != nil,
                    isComplete: false
                  )
                  let response = _ModelSessionResponse(
                    rawContent: rawContent,
                    rawResponse: pending.response
                  )
                  continuation.yield(response)
                }

                // 3. Update our cumulative state for the current chunk
                streamedText.append(text)
                if generationID == nil {
                  generationID = chunk.responseID.map {
                    #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
                      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                        return FirebaseAI.GenerationID(
                          responseID: $0, generationID: FoundationModels.GenerationID()
                        )
                      }
                    #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

                    return FirebaseAI.GenerationID(responseID: $0, generationID: nil)
                  }
                }

                // 4. Save the current state as the new pending chunk.
                pendingChunkData = (text: streamedText, id: generationID, response: chunk)
              }

              // Stream for the current turn finished. Check if there are function calls to handle.
              if !functionCalls.isEmpty {
                guard autoFunctionCallTurns < GenerativeModelSession.maxAutoFunctionCallTurns else {
                  throw GenerativeModelSession.GenerationError.internalError(
                    GenerativeModelSession.GenerationError.Context(
                      debugDescription: """
                      The model exceeded the maximum allowed automatic function call iterations \
                      (\(GenerativeModelSession.maxAutoFunctionCallTurns)).
                      """
                    ),
                    underlyingError: GenerativeModelSession.FunctionCallingError
                      .maxFunctionCallTurnsExceeded
                  )
                }
                let functionResponses = try await self.execute(functionCalls: functionCalls)

                if !functionResponses.isEmpty {
                  // Yield any pending text if it's not empty, but mark it as NOT complete yet.
                  if let pending = pendingChunkData,
                     !pending.text.isEmpty || pending.response.text(isThought: true) != nil {
                    let rawContent = try GenerativeModelSession.makeRawContent(
                      from: pending.text,
                      generationID: pending.id,
                      hasSchema: schema != nil,
                      isComplete: false
                    )
                    let response = _ModelSessionResponse(
                      rawContent: rawContent,
                      rawResponse: pending.response
                    )
                    continuation.yield(response)
                  }

                  currentParts = [ModelContent(role: "user", parts: functionResponses)]
                  autoFunctionCallTurns += 1
                  continue functionCallingLoop
                }
              }

              // 5. The remaining pending chunk is the final one.
              if let finalChunk = pendingChunkData {
                let rawContent = try GenerativeModelSession.makeRawContent(
                  from: finalChunk.text,
                  generationID: finalChunk.id,
                  hasSchema: schema != nil,
                  isComplete: true
                )
                let response = _ModelSessionResponse(
                  rawContent: rawContent,
                  rawResponse: finalChunk.response
                )
                continuation.yield(response)
              }

              break functionCallingLoop
            }

            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
          }
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }

    private func execute(functionCalls: [FunctionCallPart]) async throws -> [FunctionResponsePart] {
      var functionResponses = [FunctionResponsePart]()
      for functionCall in functionCalls {
        guard let functionDeclaration = functionDeclarations[functionCall.name] else {
          throw GenerativeModelSession.GenerationError.internalError(
            GenerativeModelSession.GenerationError.Context(debugDescription: """
            No function named "\(functionCall.name)" was declared.
            """),
            underlyingError: GenerativeModelSession.FunctionCallingError.invalidFunctionCall
          )
        }

        switch functionDeclaration.kind {
        case .manual:
          continue
        case let .foundationModels(tool):
          #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
              guard let tool = tool as? (any FoundationModels.Tool) else {
                assertionFailure("The value '\(tool)' is not a Foundation Models `Tool`.")
                throw GenerativeModelSession.TypeConversionError(
                  from: (any Sendable).self, to: (any FoundationModels.Tool).self
                )
              }
              try functionResponses.append(await FunctionDeclaration.call(
                tool: tool,
                functionCall: functionCall
              ))
              continue
            }
          #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          assertionFailure("""
          A Foundation Models `Tool` '\(tool)' was provided but not running on a supported platform.
          """)
        }
      }

      return functionResponses
    }

    private func buildConfig(options: GenerationConfig?,
                             schema: FirebaseAI.GenerationSchema?,
                             includeSchemaInPrompt: Bool) throws -> GenerationConfig {
      var config = GenerationConfig.merge(
        chat.generationConfig, with: options
      ) ?? GenerationConfig()

      if let schema {
        config.responseMIMEType = "application/json"
        config.responseJSONSchema = includeSchemaInPrompt ? try schema.toGeminiJSONSchema() : nil
        config.responseSchema = nil // `responseSchema` must not be set with `responseJSONSchema`
      }

      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      return config
    }
  }
#endif // compiler(>=6.2.3)
