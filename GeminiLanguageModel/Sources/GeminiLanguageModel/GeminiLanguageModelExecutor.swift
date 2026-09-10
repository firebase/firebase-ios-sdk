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
  package import Foundation
  public import FoundationModels
  package import GeminiAPIClient
  import GeminiAPIDataModels
  import GeminiSharedDataModels
  import InteractionsDataModels

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    /// The executor responsible for translating Foundation Models requests to Gemini API calls.
    public struct Executor: LanguageModelExecutor {
      /// The cacheable configuration for this executor.
      public struct Configuration: Hashable, Sendable {
        /// The model resource configuration specifying identifiers for URL routing and payloads.
        let modelResource: ModelResource

        /// The network endpoint configuration defining scheme, host, port, and API version.
        let endpointConfiguration: EndpointConfiguration

        /// An optional async provider for dynamic headers (such as API keys or Bearer tokens).
        let headerProvider: HeaderProvider?

        /// The `URLSessionConfiguration` to use.
        let sessionConfiguration: URLSessionConfiguration

        /// The API variant to use for generation.
        let apiVariant: APIVariant

        /// Initializes an executor configuration.
        ///
        /// - Parameters:
        ///   - modelResource: The model resource configuration.
        ///   - endpointConfiguration: The network endpoint configuration.
        ///   - headerProvider: An optional async provider for dynamic headers.
        ///   - sessionConfiguration: The `URLSessionConfiguration` to use.
        ///   - apiVariant: The API variant to use for generation. Defaults to `.generateContent`.
        init(
          modelResource: ModelResource,
          endpointConfiguration: EndpointConfiguration,
          headerProvider: HeaderProvider?,
          sessionConfiguration: URLSessionConfiguration,
          apiVariant: APIVariant = .generateContent
        ) {
          self.modelResource = modelResource
          self.endpointConfiguration = endpointConfiguration
          self.headerProvider = headerProvider
          self.sessionConfiguration = sessionConfiguration
          self.apiVariant = apiVariant
        }
      }

      private let configuration: Configuration

      /// Initializes a new executor with the specified configuration.
      ///
      /// - Parameter configuration: The executor configuration.
      public init(configuration: Configuration) throws {
        self.configuration = configuration
      }

      /// Responds to a generation request from a Foundation Models session.
      ///
      /// - Parameters:
      ///   - request: The generation request containing the conversation transcript.
      ///   - model: The Gemini language model instance.
      ///   - channel: The generation channel used to stream events back to the session.
      /// - Throws: `LanguageModelError` on known failures or `GeminiLanguageModel.Error` for
      ///   Gemini-specific errors.
      public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: GeminiLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        let responseEntryID = UUID().uuidString
        let reasoningEntryID = UUID().uuidString
        let toolCallsEntryID = UUID().uuidString
        let jsonEncoder = JSONEncoder()

        switch configuration.apiVariant {
        case .generateContent:
          try await respondWithGenerateContent(
            to: request,
            streamingInto: channel,
            responseEntryID: responseEntryID,
            reasoningEntryID: reasoningEntryID,
            toolCallsEntryID: toolCallsEntryID,
            jsonEncoder: jsonEncoder
          )
        case .interactions:
          try await respondWithInteractions(
            to: request,
            streamingInto: channel,
            responseEntryID: responseEntryID,
            reasoningEntryID: reasoningEntryID,
            toolCallsEntryID: toolCallsEntryID,
            jsonEncoder: jsonEncoder
          )
        }
      }

      private func respondWithGenerateContent(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel,
        responseEntryID: String,
        reasoningEntryID: String,
        toolCallsEntryID: String,
        jsonEncoder: JSONEncoder
      ) async throws {
        let generateRequest = try GeminiRequestTranslator.translate(request)

        let client = GeminiAPIClient(
          modelResource: configuration.modelResource,
          endpointConfiguration: configuration.endpointConfiguration,
          headerProvider: configuration.headerProvider,
          sessionConfiguration: configuration.sessionConfiguration
        )

        do {
          let stream = try await client.generateContentStream(for: generateRequest)

          for try await chunk in stream {
            try Task.checkCancellation()

            try GeminiErrorMapper.checkGuardrails(in: chunk)

            if let candidates = chunk.candidates, let candidate = candidates.first,
              let parts = candidate.content?.parts
            {
              for part in parts {
                if let thoughtSignature = part.thoughtSignature, !thoughtSignature.isEmpty {
                  let signatureData = Data(thoughtSignature.utf8)
                  await channel.send(
                    .reasoning(
                      entryID: reasoningEntryID,
                      action: .updateSignature(signatureData, tokenCount: 0)
                    )
                  )
                }

                if case .text(let text) = part.data, !text.isEmpty {
                  if part.thought == true {
                    await channel.send(
                      .reasoning(
                        entryID: reasoningEntryID,
                        action: .appendText(text, tokenCount: 1)
                      )
                    )
                  } else {
                    await channel.send(
                      .response(
                        entryID: responseEntryID,
                        action: .appendText(text, tokenCount: 1)
                      )
                    )
                  }
                }

                if case .functionCall(let call) = part.data {
                  let callID = call.id ?? UUID().uuidString
                  let argsString: String
                  if let args = call.args, !args.isEmpty {
                    let data = try jsonEncoder.encode(JSONValue.object(args))
                    argsString = String(decoding: data, as: UTF8.self)
                  } else {
                    argsString = "{}"
                  }

                  await channel.send(
                    .toolCalls(
                      entryID: toolCallsEntryID,
                      action: .toolCall(
                        id: callID,
                        name: call.name,
                        action: .appendArguments(argsString, tokenCount: 1)
                      )
                    )
                  )
                }
              }
            }

            if let usage = chunk.usageMetadata {
              await channel.send(
                .response(
                  entryID: responseEntryID,
                  action: .updateUsage(
                    input: .init(
                      totalTokenCount: usage.promptTokenCount ?? 0,
                      cachedTokenCount: usage.cachedContentTokenCount ?? 0
                    ),
                    output: .init(
                      totalTokenCount: usage.candidatesTokenCount ?? 0,
                      reasoningTokenCount: usage.thoughtsTokenCount ?? 0
                    )
                  )
                )
              )
            }
          }
        } catch {
          throw GeminiErrorMapper.map(error)
        }
      }

      private func respondWithInteractions(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel,
        responseEntryID: String,
        reasoningEntryID: String,
        toolCallsEntryID: String,
        jsonEncoder: JSONEncoder
      ) async throws {
        let interactionRequest = try GeminiInteractionsRequestTranslator.translate(
          request,
          modelResource: configuration.modelResource
        )

        let client = GeminiAPIClient(
          modelResource: configuration.modelResource,
          endpointConfiguration: configuration.endpointConfiguration,
          headerProvider: configuration.headerProvider,
          sessionConfiguration: configuration.sessionConfiguration
        )

        var activeToolCalls: [Int: (id: String, name: String)] = [:]
        var lastToolCall: (id: String, name: String)?
        var toolCallArgumentsSent: Set<Int> = []

        do {
          let stream = try await client.interactionStream(for: interactionRequest)

          for try await event in stream {
            try Task.checkCancellation()

            switch event {
            case .stepStart(let stepStart):
              let index = stepStart.index ?? 0
              if let step = stepStart.step, case .functionCallStep(let fc) = step {
                let toolCall = (id: fc.id ?? UUID().uuidString, name: fc.name ?? "")
                activeToolCalls[index] = toolCall
                lastToolCall = toolCall
                if let args = fc.arguments {
                  let argsString: String
                  if !args.isEmpty {
                    let data = try jsonEncoder.encode(JSONValue.object(args))
                    argsString = String(decoding: data, as: UTF8.self)
                  } else {
                    argsString = "{}"
                  }
                  toolCallArgumentsSent.insert(index)
                  await channel.send(
                    .toolCalls(
                      entryID: toolCallsEntryID,
                      action: .toolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        action: .appendArguments(argsString, tokenCount: 1)
                      )
                    )
                  )
                }
              }

            case .stepDelta(let stepDelta):
              let index = stepDelta.index ?? 0
              guard let delta = stepDelta.delta else { break }

              switch delta {
              case .textDelta(let textDelta):
                if let text = textDelta.text, !text.isEmpty {
                  await channel.send(
                    .response(
                      entryID: responseEntryID,
                      action: .appendText(text, tokenCount: 1)
                    )
                  )
                }

              case .thoughtSummaryDelta(let thoughtDelta):
                if case .textContent(let textContent) = thoughtDelta.content,
                  let text = textContent.text, !text.isEmpty
                {
                  await channel.send(
                    .reasoning(
                      entryID: reasoningEntryID,
                      action: .appendText(text, tokenCount: 1)
                    )
                  )
                }

              case .thoughtSignatureDelta(let signatureDelta):
                if let signature = signatureDelta.signature, !signature.isEmpty {
                  await channel.send(
                    .reasoning(
                      entryID: reasoningEntryID,
                      action: .updateSignature(signature, tokenCount: 0)
                    )
                  )
                }

              case .argumentsDelta(let argsDelta):
                let toolCall =
                  activeToolCalls[index] ?? lastToolCall ?? (id: UUID().uuidString, name: "")
                if let args = argsDelta.arguments, !args.isEmpty {
                  toolCallArgumentsSent.insert(index)
                  await channel.send(
                    .toolCalls(
                      entryID: toolCallsEntryID,
                      action: .toolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        action: .appendArguments(args, tokenCount: 1)
                      )
                    )
                  )
                }

              default:
                break
              }

            case .stepStop(let stepStop):
              let index = stepStop.index ?? 0
              if let toolCall = activeToolCalls[index] {
                if !toolCallArgumentsSent.contains(index) {
                  await channel.send(
                    .toolCalls(
                      entryID: toolCallsEntryID,
                      action: .toolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        action: .appendArguments("{}", tokenCount: 1)
                      )
                    )
                  )
                }
              }
              if let index = stepStop.index {
                activeToolCalls.removeValue(forKey: index)
                toolCallArgumentsSent.remove(index)
              }

            case .interactionCompletedEvent(let completed):
              if let usage = completed.interaction?.usage {
                await channel.send(
                  .response(
                    entryID: responseEntryID,
                    action: .updateUsage(
                      input: .init(
                        totalTokenCount: usage.totalInputTokens ?? 0,
                        cachedTokenCount: usage.totalCachedTokens ?? 0
                      ),
                      output: .init(
                        totalTokenCount: usage.totalOutputTokens ?? 0,
                        reasoningTokenCount: usage.totalThoughtTokens ?? 0
                      )
                    )
                  )
                )
              }

            case .errorEvent(let errorEvent):
              let message = errorEvent.error?.message ?? "An error occurred during interaction."
              let code = errorEvent.error?.code ?? "ERROR"
              throw GeminiLanguageModel.Error.apiError(
                GeminiLanguageModel.Error.APIError(
                  code: code,
                  statusCode: 400,
                  message: message,
                  metadata: [:]
                )
              )

            default:
              break
            }
          }
        } catch {
          throw GeminiErrorMapper.map(error)
        }
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
