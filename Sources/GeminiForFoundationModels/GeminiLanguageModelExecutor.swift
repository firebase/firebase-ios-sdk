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
    /// The executor responsible for translating Foundation Models session requests to Gemini API calls.
    public struct Executor: LanguageModelExecutor {
      /// The cacheable configuration for this executor.
      public struct Configuration: Hashable, Sendable {
        /// The model resource configuration specifying identifiers for URL routing and payloads.
        package let modelResource: ModelResource

        /// The network endpoint configuration defining scheme, host, port, and API version.
        package let endpointConfiguration: EndpointConfiguration

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
        package init(
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
      /// - Throws: `LanguageModelError` on known failures or standard Gemini/network errors.
      public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: GeminiLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
          request.transcript
        )
        let generateRequest = GenerateContentRequest(
          model: nil,
          systemInstruction: systemInstruction,
          contents: contents
        )

        let client = GeminiAPIClient(
          modelResource: configuration.modelResource,
          endpointConfiguration: configuration.endpointConfiguration,
          headerProvider: configuration.headerProvider,
          sessionConfiguration: configuration.sessionConfiguration
        )

        let responseEntryID = UUID().uuidString
        let reasoningEntryID = UUID().uuidString

        do {
          let stream = try await client.generateContentStream(for: generateRequest)

          for try await chunk in stream {
            try Task.checkCancellation()

            if let promptFeedback = chunk.promptFeedback,
              let blockReason = promptFeedback.blockReason
            {
              throw LanguageModelError.guardrailViolation(
                .init(debugDescription: "Gemini blocked the prompt: \(blockReason)")
              )
            }

            guard let candidates = chunk.candidates, let candidate = candidates.first else {
              continue
            }

            if candidate.finishReason == .safety {
              throw LanguageModelError.guardrailViolation(
                .init(
                  debugDescription: candidate.finishMessage
                    ?? "Content generation blocked by safety filters."
                )
              )
            }

            if let parts = candidate.content?.parts {
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
                  await channel.send(
                    .response(
                      entryID: responseEntryID,
                      action: .appendText(text, tokenCount: 1)
                    )
                  )
                }
              }
            }
          }
        } catch let error as LanguageModelError {
          throw error
        } catch let GeminiAPIError.apiError(apiError) {
          if apiError.code == 429 || apiError.status == .resourceExhausted {
            let resetDate = apiError.retryDelay.map {
              Date.now.addingTimeInterval(Double($0.components.seconds))
            }
            throw LanguageModelError.rateLimited(
              .init(resetDate: resetDate, debugDescription: apiError.message)
            )
          }
          throw GeminiAPIError.apiError(apiError)
        } catch let error as URLError where error.code == .timedOut {
          throw LanguageModelError.timeout(.init(debugDescription: error.localizedDescription))
        }
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
