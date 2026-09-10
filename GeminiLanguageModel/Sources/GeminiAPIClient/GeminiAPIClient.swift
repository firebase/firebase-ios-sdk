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

package import GeminiAPIDataModels
package import GeminiSharedDataModels
package import InteractionsDataModels

#if canImport(Darwin)
  package import Foundation
#else
  import Foundation
  package import FoundationNetworking
#endif

// MARK: - Gemini API Client

/// A client for communicating with Google Gemini backend endpoints.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package struct GeminiAPIClient: Sendable {
  /// The model resource configuration specifying identifiers for URL routing and payloads.
  let modelResource: ModelResource

  /// The network endpoint configuration defining scheme, host, port, and API version.
  let endpointConfiguration: EndpointConfiguration

  /// An optional async provider for dynamic headers (such as API keys or Bearer tokens).
  let headerProvider: HeaderProvider?

  private let httpClient: HTTPStreamingClient

  /// Initializes a new Gemini API client with a model resource and target endpoint configuration.
  ///
  /// - Parameters:
  ///   - modelResource: The model resource configuration.
  ///   - endpointConfiguration: The network endpoint configuration.
  ///   - headerProvider: An optional async provider for dynamic headers (such as API keys or Bearer
  ///     tokens).
  ///   - sessionConfiguration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
  package init(
    modelResource: ModelResource,
    endpointConfiguration: EndpointConfiguration,
    headerProvider: HeaderProvider? = nil,
    sessionConfiguration: URLSessionConfiguration = .ephemeral
  ) {
    assert(
      !modelResource.urlResourceName.isEmpty, "modelResource.urlResourceName must not be empty.")
    self.modelResource = modelResource
    self.endpointConfiguration = endpointConfiguration
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

  /// Sends an interaction generation request and delivers responses asynchronously as a
  /// backpressured `InteractionStream` sequence.
  ///
  /// - Parameter request: The structured interaction generation request.
  /// - Returns: A backpressured `InteractionStream` async sequence.
  /// - Throws: `GeminiAPIError.apiError` on API failures, or standard network errors.
  package func interactionStream(
    for request: CreateModelInteraction
  ) async throws -> InteractionStream {
    let urlRequest = try await makeInteractionsURLRequest(body: request)

    let (lines, response) = try await httpClient.lines(for: urlRequest)

    if response.statusCode != 200 {
      let bodyData = try await collectBody(from: lines)
      throw parseError(from: bodyData, statusCode: response.statusCode, response: response)
    }

    return InteractionStream(lines: lines, response: response)
  }

  /// Assembles the complete request URL for the configured model resource and endpoint.
  ///
  /// - Parameters:
  ///   - action: The RPC action to invoke (e.g., `"streamGenerateContent"`).
  ///   - queryItems: An optional array of query items to append to the URL.
  /// - Returns: The resolved `URL`.
  /// - Throws: `URLError(.badURL)` if the components do not form a valid URL.
  func makeRequestURL(
    action: String,
    queryItems: [URLQueryItem]? = nil
  ) throws -> URL {
    var components = URLComponents()
    components.scheme = endpointConfiguration.scheme
    components.host = endpointConfiguration.host
    components.port = endpointConfiguration.port

    let slashSet = CharacterSet(charactersIn: "/")
    let sanitizedVersion = endpointConfiguration.apiVersion.trimmingCharacters(in: slashSet)
    let versionComponent = sanitizedVersion.isEmpty ? "" : "/\(sanitizedVersion)"
    let sanitizedResourcePath = modelResource.urlResourceName.trimmingCharacters(in: slashSet)
    components.path = "\(versionComponent)/\(sanitizedResourcePath):\(action)"

    if let queryItems, !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let url = components.url else {
      throw URLError(.badURL)
    }
    return url
  }

  private func makeURLRequest<Body: Encodable>(
    action: String,
    queryItems: [URLQueryItem]? = nil,
    body: Body
  ) async throws -> URLRequest {
    let requestURL = try makeRequestURL(action: action, queryItems: queryItems)

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

  /// Assembles the complete request URL for the Interactions API based on the configured model
  /// resource and endpoint.
  ///
  /// The path is constructed by extracting any parent project or location hierarchy preceding
  /// `/models/` or `/publishers/` in `modelResource.urlResourceName`, routing to `/interactions`.
  ///
  /// - Parameter queryItems: An optional array of query items to append to the URL.
  /// - Returns: The resolved Interactions API `URL`.
  /// - Throws: `URLError(.badURL)` if the components do not form a valid URL.
  func makeInteractionsRequestURL(
    queryItems: [URLQueryItem]? = nil
  ) throws -> URL {
    var components = URLComponents()
    components.scheme = endpointConfiguration.scheme
    components.host = endpointConfiguration.host
    components.port = endpointConfiguration.port

    let slashSet = CharacterSet(charactersIn: "/")
    let sanitizedVersion = endpointConfiguration.apiVersion.trimmingCharacters(in: slashSet)
    let versionComponent = sanitizedVersion.isEmpty ? "" : "/\(sanitizedVersion)"
    let sanitizedResourcePath = modelResource.urlResourceName.trimmingCharacters(in: slashSet)

    let parent: String
    if sanitizedResourcePath.hasPrefix("models/") {
      parent = ""
    } else if let range = sanitizedResourcePath.range(of: "/publishers/") {
      parent = String(sanitizedResourcePath[..<range.lowerBound])
    } else if let range = sanitizedResourcePath.range(of: "/models/") {
      parent = String(sanitizedResourcePath[..<range.lowerBound])
    } else {
      parent = ""
    }

    let parentComponent = parent.isEmpty ? "" : "/\(parent)"
    components.path = "\(versionComponent)\(parentComponent)/interactions"

    if let queryItems, !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let url = components.url else {
      throw URLError(.badURL)
    }
    return url
  }

  private func makeInteractionsURLRequest<Body: Encodable>(
    queryItems: [URLQueryItem]? = nil,
    body: Body
  ) async throws -> URLRequest {
    let requestURL = try makeInteractionsRequestURL(queryItems: queryItems)

    var urlRequest = URLRequest(url: requestURL)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

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

// MARK: - Interaction Stream

/// An asynchronous sequence of `InteractionSSEEvent` chunks streamed from Gemini Interactions API.
///
/// Iterates on-demand over Server-Sent Events with backpressure and zero unstructured `Task`
/// allocation. Cancellation propagates directly to the underlying network stream.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package struct InteractionStream: AsyncSequence, Sendable {
  /// The type of element produced by this asynchronous sequence.
  package typealias Element = InteractionSSEEvent

  private let lines: HTTPAsyncLineSequence
  private let response: HTTPURLResponse

  /// Initializes a new interaction stream from an underlying HTTP line sequence and response metadata.
  ///
  /// - Parameters:
  ///   - lines: The sequence of text lines received from the server.
  ///   - response: The initial HTTP response headers and status code.
  init(lines: HTTPAsyncLineSequence, response: HTTPURLResponse) {
    self.lines = lines
    self.response = response
  }

  /// Creates an asynchronous iterator over the stream of interaction SSE events.
  ///
  /// - Returns: An `AsyncIterator` instance.
  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(linesIterator: lines.makeAsyncIterator(), response: response)
  }

  /// An asynchronous iterator over Server-Sent Events decoded into
  /// `InteractionSSEEvent` chunks.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var linesIterator: HTTPAsyncLineSequence.AsyncIterator
    private let response: HTTPURLResponse
    private let decoder = JSONDecoder()
    private var sseDataBuffer = ""
    private var extraLinesBuffer = ""
    private var currentEvent: String?

    init(linesIterator: HTTPAsyncLineSequence.AsyncIterator, response: HTTPURLResponse) {
      self.linesIterator = linesIterator
      self.response = response
    }

    /// Asynchronously advances to and returns the next `InteractionSSEEvent` chunk.
    ///
    /// - Returns: The next decoded `InteractionSSEEvent`, or `nil` if the stream has finished.
    /// - Throws: An error if reading or decoding fails, or if a mid-stream API error occurs.
    package mutating func next() async throws -> InteractionSSEEvent? {
      while let line = try await linesIterator.next() {
        // Empty line marks the end of an SSE event
        if line.isEmpty || line.allSatisfy({ $0.isWhitespace }) {
          if !sseDataBuffer.isEmpty {
            let dataString = sseDataBuffer
            let eventName = currentEvent
            sseDataBuffer = ""
            currentEvent = nil
            if dataString == "[DONE]" {
              return nil
            }
            return try decodeEventData(dataString, eventName: eventName)
          }
          currentEvent = nil
          continue
        }

        // SSE comment line (e.g. ": keep-alive")
        if line.hasPrefix(":") {
          continue
        }

        // SSE event field
        if line.hasPrefix("event:") {
          var eventContent = line.dropFirst(6)
          if eventContent.hasPrefix(" ") {
            eventContent = eventContent.dropFirst()
          }
          currentEvent = String(eventContent)
          continue
        }

        // SSE control fields (e.g. "id: 1", "retry: 5000")
        if line.hasPrefix("id:") || line.hasPrefix("retry:") {
          continue
        }

        // SSE data field
        if line.hasPrefix("data:") {
          var dataContent = line.dropFirst(5)
          // The SSE specification only allows a single leading space after the colon.
          if dataContent.hasPrefix(" ") {
            dataContent = dataContent.dropFirst()
          }
          if dataContent == "[DONE]" {
            sseDataBuffer = "[DONE]"
            continue
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
        let eventName = currentEvent
        sseDataBuffer = ""
        currentEvent = nil
        if dataString == "[DONE]" {
          return nil
        }
        return try decodeEventData(dataString, eventName: eventName)
      }

      // If extra non-SSE lines were accumulated, parse as error
      let trimmedExtra = extraLinesBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmedExtra.isEmpty {
        let data = Data(trimmedExtra.utf8)
        throw parseError(from: data, statusCode: response.statusCode, response: response)
      }

      return nil
    }

    private func decodeEventData(
      _ jsonString: String,
      eventName: String? = nil
    ) throws -> InteractionSSEEvent {
      let data = Data(jsonString.utf8)
      // Fast-path: only attempt GoogleCloudAPIError decoding if payload contains an "error" key.
      if jsonString.contains("\"error\""),
        let apiError = try? decoder.decode(GoogleCloudAPIError.self, from: data)
      {
        let headerRetryAfter = parseRetryAfterHeader(from: response)
        let resolvedError = headerRetryAfter.map { apiError.withRetryDelay($0) } ?? apiError
        throw GeminiAPIError.apiError(resolvedError)
      }
      if let event = try? decoder.decode(InteractionSSEEvent.self, from: data) {
        return event
      }
      if let streamEvent = try? decoder.decode(InteractionSSEStreamEvent.self, from: data),
        let event = streamEvent.data
      {
        return event
      }
      // If neither worked and we have an SSE eventName, attempt injecting it into the JSON object
      if let eventName,
        var jsonObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      {
        if jsonObject["type"] == nil && jsonObject["event_type"] == nil {
          jsonObject["event_type"] = eventName
          if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject) {
            if let event = try? decoder.decode(InteractionSSEEvent.self, from: modifiedData) {
              return event
            }
          }
        }
      }
      return try decoder.decode(InteractionSSEEvent.self, from: data)
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
