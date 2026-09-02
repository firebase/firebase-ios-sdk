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

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

// MARK: - Gemini API Client

/// A client for communicating with Google Gemini backend endpoints.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package struct GeminiAPIClient: Sendable {
  /// The resource path of the target model (e.g., `"v1beta/models/gemini-3.5-flash-lite"`
  /// or `"v1beta1/projects/p/locations/l/publishers/google/models/gemini-3.5-flash-lite"`).
  let modelResourcePath: String

  /// The base URL of the Gemini API endpoint.
  let baseURL: URL

  /// An optional async provider for dynamic headers (such as API keys or Bearer tokens).
  let headerProvider: (@Sendable () async throws -> [String: String])?

  private let httpClient: HTTPStreamingClient

  /// Initializes a new Gemini API client with a model resource path and target base URL.
  ///
  /// - Parameters:
  ///   - modelResourcePath: The resource path of the target model (e.g.,
  ///     `"v1beta/models/gemini-3.5-flash-lite"`).
  ///   - baseURL: The base URL of the Gemini API endpoint.
  ///   - headerProvider: An optional async provider for dynamic headers (such as API keys or Bearer
  ///     tokens).
  ///   - sessionConfiguration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
  package init(
    modelResourcePath: String,
    baseURL: URL,
    headerProvider: (@Sendable () async throws -> [String: String])? = nil,
    sessionConfiguration: URLSessionConfiguration = .ephemeral
  ) {
    assert(!modelResourcePath.isEmpty, "modelResourcePath must not be empty.")
    self.modelResourcePath = modelResourcePath
    self.baseURL = baseURL
    self.headerProvider = headerProvider
    self.httpClient = HTTPStreamingClient(configuration: sessionConfiguration)
  }

  /// Sends a streaming text generation request and delivers responses asynchronously as a
  /// backpressured `GenerateContentStream` sequence.
  ///
  /// - Parameter request: The structured content generation request.
  /// - Returns: A backpressured `GenerateContentStream` async sequence.
  /// - Throws: `GeminiAPIError.apiError` on API failures, or standard network errors.
  package func generateContentStream(
    for request: GenerateContentRequest
  ) async throws -> GenerateContentStream {
    let urlRequest = try await makeURLRequest(
      action: "streamGenerateContent",
      queryItems: [URLQueryItem(name: "alt", value: "sse")],
      body: request
    )

    let (lines, response) = try await httpClient.lines(for: urlRequest)

    if response.statusCode != 200 {
      let bodyData = try await collectBody(from: lines)
      throw parseError(from: bodyData, statusCode: response.statusCode, response: response)
    }

    return GenerateContentStream(lines: lines, response: response)
  }

  /// Counts the number of tokens in the given request.
  ///
  /// - Parameter request: The token count calculation request.
  /// - Returns: The calculated `CountTokensResponse`.
  /// - Throws: `GeminiAPIError.apiError` on API failures, or standard network errors.
  package func countTokens(
    for request: CountTokensRequest
  ) async throws -> CountTokensResponse {
    let urlRequest = try await makeURLRequest(
      action: "countTokens",
      body: request
    )

    let (lines, response) = try await httpClient.lines(for: urlRequest)
    let bodyData = try await collectBody(from: lines)

    if response.statusCode != 200 {
      throw parseError(from: bodyData, statusCode: response.statusCode, response: response)
    }

    return try JSONDecoder().decode(CountTokensResponse.self, from: bodyData)
  }

  private func makeURLRequest<Body: Encodable>(
    action: String,
    queryItems: [URLQueryItem]? = nil,
    body: Body
  ) async throws -> URLRequest {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw URLError(.badURL)
    }

    let sanitizedResourcePath = modelResourcePath.drop { $0 == "/" }
    let basePath =
      components.path.hasSuffix("/")
      ? String(components.path.dropLast())
      : components.path
    components.path = "\(basePath)/\(sanitizedResourcePath):\(action)"
    if let queryItems {
      components.queryItems = (components.queryItems ?? []) + queryItems
    }
    guard let requestURL = components.url else {
      throw URLError(.badURL)
    }

    var urlRequest = URLRequest(url: requestURL)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let headerProvider {
      for (key, value) in try await headerProvider() {
        urlRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    urlRequest.httpBody = try JSONEncoder().encode(body)
    return urlRequest
  }

  private func collectBody(from lines: HTTPAsyncLineSequence) async throws -> Data {
    return try await lines.reduce(into: Data()) { result, line in
      if !result.isEmpty {
        result.append(0x0A)  // "\n"
      }
      result.append(contentsOf: line.utf8)
    }
  }
}

// MARK: - Generate Content Stream

/// An asynchronous sequence of `GenerateContentResponse` chunks streamed from Gemini.
///
/// Iterates on-demand over Server-Sent Events with backpressure and zero unstructured `Task`
/// allocation. Cancellation propagates directly to the underlying network stream.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package struct GenerateContentStream: AsyncSequence, Sendable {
  /// The type of element produced by this asynchronous sequence.
  package typealias Element = GenerateContentResponse

  private let lines: HTTPAsyncLineSequence
  private let response: HTTPURLResponse

  /// Initializes a new content stream from an underlying HTTP line sequence and response metadata.
  ///
  /// - Parameters:
  ///   - lines: The sequence of text lines received from the server.
  ///   - response: The initial HTTP response headers and status code.
  init(lines: HTTPAsyncLineSequence, response: HTTPURLResponse) {
    self.lines = lines
    self.response = response
  }

  /// Creates an asynchronous iterator over the stream of generated content response chunks.
  ///
  /// - Returns: An `AsyncIterator` instance.
  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(linesIterator: lines.makeAsyncIterator(), response: response)
  }

  /// An asynchronous iterator over Server-Sent Events decoded into
  /// `GenerateContentResponse` chunks.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var linesIterator: HTTPAsyncLineSequence.AsyncIterator
    private let response: HTTPURLResponse
    private let decoder = JSONDecoder()
    private var sseDataBuffer = ""
    private var extraLinesBuffer = ""

    init(linesIterator: HTTPAsyncLineSequence.AsyncIterator, response: HTTPURLResponse) {
      self.linesIterator = linesIterator
      self.response = response
    }

    /// Asynchronously advances to and returns the next `GenerateContentResponse` chunk.
    ///
    /// - Returns: The next decoded `GenerateContentResponse`, or `nil` if the stream has finished.
    /// - Throws: An error if reading or decoding fails, or if a mid-stream API error occurs.
    package mutating func next() async throws -> GenerateContentResponse? {
      while let line = try await linesIterator.next() {
        // Empty line marks the end of an SSE event
        if line.isEmpty || line.allSatisfy({ $0.isWhitespace }) {
          if !sseDataBuffer.isEmpty {
            let dataString = sseDataBuffer
            sseDataBuffer = ""
            return try decodeEventData(dataString)
          }
          continue
        }

        // SSE comment line (e.g. ": keep-alive")
        if line.hasPrefix(":") {
          continue
        }

        // SSE control fields (e.g. "event: message", "id: 1", "retry: 5000")
        if line.hasPrefix("event:") || line.hasPrefix("id:") || line.hasPrefix("retry:") {
          continue
        }

        // SSE data field
        if line.hasPrefix("data:") {
          var dataContent = line.dropFirst(5)
          // The SSE specification only allows a single leading space after the colon.
          if dataContent.hasPrefix(" ") {
            dataContent = dataContent.dropFirst()
          }
          if !dataContent.isEmpty {
            if !sseDataBuffer.isEmpty {
              sseDataBuffer.append("\n")
            }
            sseDataBuffer.append(contentsOf: dataContent)
          }
          continue
        }

        // Non-SSE payload line (e.g. raw JSON error block or unexpected content)
        extraLinesBuffer.append(line)
        extraLinesBuffer.append("\n")
      }

      // Flush any pending SSE event data
      if !sseDataBuffer.isEmpty {
        let dataString = sseDataBuffer
        sseDataBuffer = ""
        return try decodeEventData(dataString)
      }

      // If extra non-SSE lines were accumulated, parse as error
      let trimmedExtra = extraLinesBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmedExtra.isEmpty {
        let data = Data(trimmedExtra.utf8)
        throw parseError(from: data, statusCode: response.statusCode, response: response)
      }

      return nil
    }

    private func decodeEventData(_ jsonString: String) throws -> GenerateContentResponse {
      let data = Data(jsonString.utf8)
      // Fast-path: only attempt error decoding if the payload contains an "error" key.
      // GoogleCloudAPIError requires top-level code and message, avoiding false positives.
      if jsonString.contains("\"error\""),
        let apiError = try? decoder.decode(GoogleCloudAPIError.self, from: data)
      {
        let headerRetryAfter = parseRetryAfterHeader(from: response)
        let resolvedError = headerRetryAfter.map { apiError.withRetryDelay($0) } ?? apiError
        throw GeminiAPIError.apiError(resolvedError)
      }
      return try decoder.decode(GenerateContentResponse.self, from: data)
    }
  }
}

// MARK: - Internal Error Parsing Helpers

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private func parseError(
  from data: Data,
  statusCode: Int,
  response: HTTPURLResponse
) -> GeminiAPIError {
  if let apiError = try? JSONDecoder().decode(GoogleCloudAPIError.self, from: data) {
    let headerRetryAfter = parseRetryAfterHeader(from: response)
    let resolvedError = headerRetryAfter.map { apiError.withRetryDelay($0) } ?? apiError
    return GeminiAPIError.apiError(resolvedError)
  } else {
    return GeminiAPIError.httpError(
      statusCode: statusCode,
      body: String(decoding: data, as: UTF8.self)
    )
  }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private func parseRetryAfterHeader(from response: HTTPURLResponse) -> Duration? {
  if let headerValue = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(
    in: .whitespaces
  ) {
    if let seconds = Double(headerValue), seconds >= 0 {
      return .seconds(seconds)
    }
  }

  return nil
}
