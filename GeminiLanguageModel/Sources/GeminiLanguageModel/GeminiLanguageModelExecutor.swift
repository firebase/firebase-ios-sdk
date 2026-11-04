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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  #if canImport(FoundationNetworking)
    import Foundation
    package import FoundationNetworking
  #else
    package import Foundation
  #endif
  #if FoundationModelsFake
    public import FoundationModelsFake
  #else
    public import FoundationModels
  #endif
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

        /// The maximum number of tool-calling turns allowed in response to a single prompt.
        ///
        /// A tool-calling turn is a model response that calls one or more tools. When this limit
        /// is reached, the next request tells Gemini not to call functions; if it returns a
        /// function call anyway, the executor throws `GeminiLanguageModel.Error.invalidResponse`.
        let maximumToolCallingTurns: Int

        /// The default maximum number of tool-calling turns allowed in response to a single
        /// prompt.
        static let defaultMaximumToolCallingTurns = 10

        /// Initializes an executor configuration.
        ///
        /// - Parameters:
        ///   - modelResource: The model resource configuration.
        ///   - endpointConfiguration: The network endpoint configuration.
        ///   - headerProvider: An optional async provider for dynamic headers.
        ///   - sessionConfiguration: The `URLSessionConfiguration` to use.
        ///   - maximumToolCallingTurns: The maximum number of tool-calling turns allowed in
        ///     response to a single prompt. Must be greater than zero.
        init(
          modelResource: ModelResource,
          endpointConfiguration: EndpointConfiguration,
          headerProvider: HeaderProvider?,
          sessionConfiguration: URLSessionConfiguration,
          maximumToolCallingTurns: Int = Configuration.defaultMaximumToolCallingTurns
        ) {
          precondition(maximumToolCallingTurns > 0, "maximumToolCallingTurns must be positive.")
          self.modelResource = modelResource
          self.endpointConfiguration = endpointConfiguration
          self.headerProvider = headerProvider
          self.sessionConfiguration = sessionConfiguration
          self.maximumToolCallingTurns = maximumToolCallingTurns
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
        // The session keeps calling tools for as long as the model returns function calls, so
        // limit the number of tool-calling turns to bound the number of requests.
        let isAtToolCallingTurnLimit =
          GeminiRequestTranslator.toolCallingTurns(in: request.transcript)
          >= configuration.maximumToolCallingTurns
        let generateRequest = try GeminiRequestTranslator.translate(
          request,
          isAtToolCallingTurnLimit: isAtToolCallingTurnLimit
        )

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
          // Usage is reported once, after the stream ends, instead of after every chunk (#17040).
          // `updateUsage` is documented to replace the turn's usage totals; in testing (macOS
          // 27.2), `LanguageModelSession` also has these undocumented constraints:
          //
          // - It only produces a streamed snapshot for an event that raises the turn's output
          //   token count above its previous high. The Gemini Enterprise Agent Platform omits
          //   token counts until the final chunk, so reporting 0 after every chunk held back all
          //   snapshots until the response finished.
          // - `updateUsage` traps if the uncached input token count (`total - cached`) decreases.
          //   The Gemini Developer API reports `cachedContentTokenCount` only in the final chunk,
          //   so reporting earlier chunks' usage crashed on implicit cache hits.
          // - The final `updateUsage` is accepted even if it lowers the output count.
          //
          // While streaming, the `appendText` token counts track Gemini's running output totals
          // instead (see `StreamedTokenCounter`); the final usage replaces them.
          var latestUsage: UsageMetadata?
          var responseTokenCounter = StreamedTokenCounter()
          var reasoningTokenCounter = StreamedTokenCounter()

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
                    let tokenCount = reasoningTokenCounter.nextTokenCount(
                      forRunningTotal: chunk.usageMetadata?.thoughtsTokenCount
                    )
                    await channel.send(
                      .reasoning(
                        entryID: reasoningEntryID,
                        action: .appendText(text, tokenCount: tokenCount)
                      )
                    )
                  } else {
                    let tokenCount = responseTokenCounter.nextTokenCount(
                      forRunningTotal: chunk.usageMetadata?.candidatesTokenCount
                    )
                    await channel.send(
                      .response(
                        entryID: responseEntryID,
                        action: .appendText(text, tokenCount: tokenCount)
                      )
                    )
                  }
                }

                if case .functionCall(let call) = part.data {
                  // Gemini doesn't always follow a function calling mode of `NONE`, so never pass a
                  // function call to the session once the limit is reached.
                  guard !isAtToolCallingTurnLimit else {
                    throw GeminiLanguageModel.Error.invalidResponse(
                      GeminiLanguageModel.Error.InvalidResponse(
                        debugDescription: """
                          Gemini returned a function call after the maximum of \
                          \(configuration.maximumToolCallingTurns) tool-calling turns was reached.
                          """
                      )
                    )
                  }
                  guard let name = call.name else {
                    throw GeminiLanguageModel.Error.invalidResponse(
                      GeminiLanguageModel.Error.InvalidResponse(
                        debugDescription: "Gemini returned a function call without a name."
                      )
                    )
                  }
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
                        name: name,
                        action: .appendArguments(argsString, tokenCount: 1)
                      )
                    )
                  )
                }
              }
            }

            if let usage = chunk.usageMetadata {
              latestUsage = usage
            }
          }

          if let usage = latestUsage {
            // `cachedTokenCount` is documented to be at most `totalTokenCount`, and a cached count
            // above the total traps (see above), so clamp it in case Gemini omits or under-reports
            // `promptTokenCount`.
            let promptTokenCount = usage.promptTokenCount ?? 0
            // The session's output total includes reasoning tokens (`reasoningTokenCount` is
            // documented to be at most `totalTokenCount`), but Gemini's `candidatesTokenCount`
            // excludes thinking tokens, which it reports separately.
            let candidatesTokenCount = usage.candidatesTokenCount ?? 0
            let thoughtsTokenCount = usage.thoughtsTokenCount ?? 0
            await channel.send(
              .response(
                entryID: responseEntryID,
                action: .updateUsage(
                  input: .init(
                    totalTokenCount: promptTokenCount,
                    cachedTokenCount: min(usage.cachedContentTokenCount ?? 0, promptTokenCount)
                  ),
                  output: .init(
                    totalTokenCount: candidatesTokenCount + thoughtsTokenCount,
                    reasoningTokenCount: thoughtsTokenCount
                  )
                )
              )
            )
          }
        } catch {
          throw GeminiErrorMapper.map(error)
        }
      }
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
