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

package import Foundation
package import GeminiAPIDataModels
import Synchronization

#if canImport(Darwin)
  import Foundation
#else
  import FoundationNetworking
#endif

// MARK: - OrcaRouter Client

/// The OrcaRouter transport.
///
/// It speaks the OpenAI wire format against the configured inference origin, translating the SDK's
/// Gemini-shaped requests and responses at the edges. Every AI entry point the SDK exposes routes
/// through this one client, so the two authentication entries never grow their own request paths.
package final class OrcaRouterClient: Sendable {
  /// The provider entry this client serves.
  package let provider: OrcaRouterProvider

  /// The adapter that supplies the credential.
  package let credentialSource: any OrcaRouterCredentialSource

  /// The transport bounds.
  package struct Limits: Sendable, Equatable {
    /// The request timeout.
    package var timeout: TimeInterval = 120
    /// The maximum number of response bytes read for a non-streamed call.
    package var maximumResponseBytes = 16 * 1024 * 1024
    /// The maximum length of a single streamed line.
    package var maximumStreamedLineLength = 1024 * 1024
  }

  private let httpClient: HTTPStreamingClient
  private let sessionConfiguration: URLSessionConfiguration
  private let limits: Limits
  private let decoder = JSONDecoder()

  /// Creates a client.
  ///
  /// - Parameters:
  ///   - provider: The provider entry to serve.
  ///   - credentialSource: The adapter that supplies the credential.
  ///   - sessionConfiguration: The session configuration to use. Defaults to `.ephemeral`.
  ///   - limits: The transport bounds.
  init(
    provider: OrcaRouterProvider,
    credentialSource: any OrcaRouterCredentialSource,
    sessionConfiguration: URLSessionConfiguration = .ephemeral,
    limits: Limits = Limits()
  ) {
    self.provider = provider
    self.credentialSource = credentialSource
    self.sessionConfiguration = sessionConfiguration
    self.limits = limits
    self.httpClient = HTTPStreamingClient(configuration: sessionConfiguration)
  }

  /// Streams a content generation, mirroring `GeminiAPIClient.generateContentStream(for:)`.
  ///
  /// - Parameter request: The SDK's Gemini-shaped request.
  /// - Returns: A backpressured sequence of response chunks, already translated back into the
  ///   SDK's model.
  /// - Throws: `GeminiAPIError` on a transport or origin failure.
  package func generateContentStream(
    for request: GenerateContentRequest
  ) async throws -> OrcaRouterGenerateContentStream {
    let urlRequest = try await makeChatCompletionRequest(
      from: request,
      streaming: true,
      modelID: request.model
    )
    let (lines, response) = try await httpClient.lines(for: urlRequest)

    if response.statusCode != 200 {
      let body = try await collect(lines: lines)
      throw OrcaRouterErrorMapper.error(from: body, statusCode: response.statusCode)
    }

    return OrcaRouterGenerateContentStream(lines: lines)
  }

  /// Counts tokens for a request, mirroring `GeminiAPIClient.countTokens(for:)`.
  ///
  /// OrcaRouter exposes no dedicated token-counting route, so the count is taken from the usage
  /// block of a non-streamed completion against the same model. That is a real request and is
  /// billed as one.
  ///
  /// - Parameter request: The SDK's Gemini-shaped request.
  /// - Returns: The token count.
  /// - Throws: `GeminiAPIError` on a transport or origin failure.
  package func countTokens(for request: CountTokensRequest) async throws -> CountTokensResponse {
    let generateContentRequest = request.makeGenerateContentRequest()
    let urlRequest = try await makeChatCompletionRequest(
      from: generateContentRequest,
      streaming: false,
      modelID: request.model ?? generateContentRequest.model
    )
    let (lines, response) = try await httpClient.lines(for: urlRequest)
    let data = try await collect(lines: lines)

    guard data.count <= limits.maximumResponseBytes else {
      throw GeminiAPIError.httpError(
        statusCode: response.statusCode,
        body: "OrcaRouter response exceeded the permitted size."
      )
    }
    guard response.statusCode == 200 else {
      throw OrcaRouterErrorMapper.error(from: data, statusCode: response.statusCode)
    }

    let completion: OrcaRouterChatCompletion
    do {
      completion = try decoder.decode(OrcaRouterChatCompletion.self, from: data)
    } catch {
      throw GeminiAPIError.httpError(
        statusCode: response.statusCode,
        body: "OrcaRouter token count response could not be read."
      )
    }
    guard let usage = completion.usage else {
      throw GeminiAPIError.httpError(
        statusCode: response.statusCode,
        body: "OrcaRouter token count response carried no usage block."
      )
    }
    return OrcaRouterResponseTranslator.countTokensResponse(from: usage)
  }

  /// Builds an authenticated chat completion request.
  ///
  /// The key is sent to the inference origin only, as a bearer credential, and never placed in the
  /// URL.
  func makeChatCompletionRequest(
    from request: GenerateContentRequest,
    streaming: Bool,
    modelID: String?
  ) async throws -> URLRequest {
    let credential = try await credentialSource.acquire()
    let url = try provider.makeAPIURL(path: OrcaRouterProvider.chatCompletionsPath)

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.timeoutInterval = limits.timeout
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.httpBody = try JSONEncoder().encode(
      OrcaRouterRequestTranslator.chatCompletionRequest(
        from: request,
        modelID: modelID ?? request.model ?? "",
        streaming: streaming
      )
    )
    return urlRequest
  }

  private func collect(lines: HTTPAsyncLineSequence) async throws -> Data {
    var data = Data()
    for try await line in lines {
      if !data.isEmpty { data.append(0x0A) }
      data.append(contentsOf: line.utf8)
    }
    return data
  }
}

// MARK: - Content Stream

/// A stream of OrcaRouter completions translated into the SDK's response model.
package struct OrcaRouterGenerateContentStream: AsyncSequence, Sendable {
  package typealias Element = GeminiAPIDataModels.GenerateContentResponse

  private let lines: HTTPAsyncLineSequence

  init(lines: HTTPAsyncLineSequence) {
    self.lines = lines
  }

  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(lines: lines)
  }

  /// Iterates the origin's server-sent events, accumulating deltas and emitting translated chunks.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var iterator: HTTPAsyncLineSequence.AsyncIterator
    private let decoder = JSONDecoder()
    private var dataBuffer = ""
    private var extraLines = ""
    private var isFinished = false
    private var pending: [GeminiAPIDataModels.GenerateContentResponse] = []

    init(lines: HTTPAsyncLineSequence) {
      self.iterator = lines.makeAsyncIterator()
    }

    package mutating func next() async throws -> GeminiAPIDataModels.GenerateContentResponse? {
      if !pending.isEmpty { return pending.removeFirst() }
      guard !isFinished else { return nil }

      while let line = try await iterator.next() {
        // A blank line terminates one SSE event.
        if line.isEmpty || line.allSatisfy({ $0.isWhitespace }) {
          if dataBuffer.isEmpty { continue }
          let payload = dataBuffer
          dataBuffer = ""
          if let chunk = try await handle(payload: payload) { return chunk }
          continue
        }

        // Comments and control fields are not payload.
        if line.hasPrefix(":") || line.hasPrefix("event:") || line.hasPrefix("id:")
          || line.hasPrefix("retry:")
        {
          continue
        }

        if line.hasPrefix("data:") {
          var content = line.dropFirst(5)
          if content.hasPrefix(" ") { content = content.dropFirst() }
          if content.isEmpty { continue }
          // The OpenAI wire format terminates a stream with a sentinel that is not JSON.
          if content == "[DONE]" {
            isFinished = true
            if !pending.isEmpty { return pending.removeFirst() }
            return nil
          }
          if dataBuffer.count + content.count > 1_048_576 {
            throw GeminiAPIError.httpError(
              statusCode: 200,
              body: "OrcaRouter streamed event exceeded the permitted size."
            )
          }
          if !dataBuffer.isEmpty { dataBuffer.append("\n") }
          dataBuffer.append(contentsOf: content)
          continue
        }

        extraLines.append(line)
        extraLines.append("\n")
      }

      if !dataBuffer.isEmpty {
        let payload = dataBuffer
        dataBuffer = ""
        if let chunk = try await handle(payload: payload) { return chunk }
      }
      if !extraLines.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw OrcaRouterErrorMapper.error(
          from: Data(extraLines.utf8),
          statusCode: 200
        )
      }
      return nil
    }

    private mutating func handle(
      payload: String
    ) async throws -> GeminiAPIDataModels.GenerateContentResponse? {
      let data = Data(payload.utf8)
      guard let chunk = try? decoder.decode(OrcaRouterChatCompletionChunk.self, from: data) else {
        throw OrcaRouterErrorMapper.error(from: data, statusCode: 200)
      }
      return OrcaRouterResponseTranslator.generateContentResponse(from: chunk)
    }
  }
}

// MARK: - Error Mapping

/// Maps OrcaRouter's OpenAI-compatible error envelope onto the SDK's error type.
package enum OrcaRouterErrorMapper {
  /// The origin's error envelope.
  package struct WireError: Decodable, Sendable {
    /// The inner error object.
    package struct Inner: Decodable, Sendable {
      package let message: String?
      package let type: String?
      package let code: String?
      package let param: String?
    }

    package let error: Inner?
  }

  /// Converts an error body into a `GeminiAPIError`.
  ///
  /// A `401` is reported as an authentication failure so the caller can move the exact credential
  /// generation to reauthentication rather than retrying. A `429` preserves the origin's
  /// `Retry-After` hint. No branch echoes the request, and no branch can echo a credential.
  ///
  /// - Parameters:
  ///   - body: The response body.
  ///   - statusCode: The HTTP status code.
  package static func error(from body: Data, statusCode: Int) -> GeminiAPIError {
    let decoded = try? JSONDecoder().decode(WireError.self, from: body)
    let message = decoded?.error?.message

    switch statusCode {
    case 401:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "The OrcaRouter credential was rejected.",
          status: .unauthenticated
        )
      )
    case 403:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "The OrcaRouter credential is not permitted to use this model.",
          status: .permissionDenied
        )
      )
    case 429:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "OrcaRouter is rate limiting this credential.",
          status: .resourceExhausted
        )
      )
    case 400:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "OrcaRouter rejected the request.",
          status: .invalidArgument
        )
      )
    case 404:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "The requested OrcaRouter model does not exist.",
          status: .notFound
        )
      )
    case 503:
      return .apiError(
        GoogleCloudAPIError(
          code: statusCode,
          message: message ?? "OrcaRouter is unavailable.",
          status: .unavailable
        )
      )
    default:
      if let decoded, decoded.error != nil {
        return .apiError(
          GoogleCloudAPIError(
            code: statusCode,
            message: message ?? "OrcaRouter returned an error.",
            status: nil
          )
        )
      }
      return .httpError(
        statusCode: statusCode,
        body: String(decoding: body, as: UTF8.self)
      )
    }
  }
}

// MARK: - Request Bridge

extension CountTokensRequest {
  /// Projects a token-counting request onto a generate-content request.
  ///
  /// OrcaRouter has no dedicated counting route, so the contents, system instruction, tools, and
  /// generation configuration are carried over into a completion request.
  func makeGenerateContentRequest() -> GenerateContentRequest {
    GenerateContentRequest(
      model: model,
      systemInstruction: systemInstruction,
      contents: contents ?? generateContentRequest?.contents ?? [],
      tools: tools ?? generateContentRequest?.tools,
      toolConfig: generateContentRequest?.toolConfig,
      safetySettings: generateContentRequest?.safetySettings,
      generationConfig: generationConfig ?? generateContentRequest?.generationConfig
    )
  }
}

