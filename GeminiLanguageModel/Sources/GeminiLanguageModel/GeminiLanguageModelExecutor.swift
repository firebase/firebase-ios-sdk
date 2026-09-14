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

        /// Initializes an executor configuration.
        ///
        /// - Parameters:
        ///   - modelResource: The model resource configuration.
        ///   - endpointConfiguration: The network endpoint configuration.
        ///   - headerProvider: An optional async provider for dynamic headers.
        ///   - sessionConfiguration: The `URLSessionConfiguration` to use.
        init(
          modelResource: ModelResource,
          endpointConfiguration: EndpointConfiguration,
          headerProvider: HeaderProvider?,
          sessionConfiguration: URLSessionConfiguration
        ) {
          self.modelResource = modelResource
          self.endpointConfiguration = endpointConfiguration
          self.headerProvider = headerProvider
          self.sessionConfiguration = sessionConfiguration
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
        let generateRequest = try GeminiRequestTranslator.translate(request)

        let client = GeminiAPIClient(
          modelResource: configuration.modelResource,
          endpointConfiguration: configuration.endpointConfiguration,
          headerProvider: configuration.headerProvider,
          sessionConfiguration: configuration.sessionConfiguration
        )

        let responseEntryID = UUID().uuidString
        let reasoningEntryID = UUID().uuidString
        let toolCallsEntryID = UUID().uuidString
        let jsonEncoder = JSONEncoder()

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
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
