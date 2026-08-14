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

import GenerateContentDataModels
import HTTPStreamingClient
import SharedDataModels

#if canImport(FoundationEssentials) && canImport(FoundationNetworking)
  import FoundationEssentials
  import FoundationNetworking
  import Foundation
#else
  import Foundation
#endif

/// A client for communicating with the Google Gemini API.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
package struct GeminiAPIClient: Sendable {
  let model: String

  private let baseURL: URL
  private let httpClient: HTTPStreamingClient
  private let headerProvider: (@Sendable () async throws -> [String: String])?

  /// Initializes a new Gemini API client.
  ///
  /// - Parameters:
  ///   - model: The Gemini model identifier (e.g., `"gemini-3.5-flash-lite"`).
  ///   - baseURL: The base URL of the Gemini API endpoint.
  ///   - headerProvider: An optional async provider for dynamic headers (such as API keys or Bearer
  ///     tokens).
  ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
  package init(
    model: String,
    baseURL: URL,
    headerProvider: (@Sendable () async throws -> [String: String])? = nil,
    configuration: URLSessionConfiguration = .ephemeral
  ) {
    self.model = model
    self.baseURL = baseURL
    self.headerProvider = headerProvider
    self.httpClient = HTTPStreamingClient(configuration: configuration)
  }

  /// Sends a streaming text generation request and delivers responses asynchronously as Server-Sent
  /// Events.
  ///
  /// - Parameter request: The structured content generation request.
  /// - Returns: An asynchronous stream of `GenerateContentResponse` chunks.
  /// - Throws: `GeminiAPIError.apiError` on API failures, or standard network errors.
  package func generateContentStream(
    request: GenerateContentRequest
  ) async throws -> AsyncThrowingStream<GenerateContentResponse, any Error> {
    let endpointURL = baseURL.appendingPathComponent("v1beta/models/\(model):streamGenerateContent")
    guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) else {
      throw URLError(.badURL)
    }
    components.queryItems = [URLQueryItem(name: "alt", value: "sse")]

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

    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (bytes, response) = try await httpClient.bytes(for: urlRequest)

    if response.statusCode != 200 {
      let bodyData = try await bytes.collect()
      throw parseError(from: bodyData, statusCode: response.statusCode, response: response)
    }

    return AsyncThrowingStream<GenerateContentResponse, any Error> {
      continuation in
      let streamTask = Task {
        let decoder = JSONDecoder()
        var extraLines = ""
        do {
          for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix(":") else { continue }

            if trimmed.hasPrefix("data:") {
              let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
              guard !jsonString.isEmpty else { continue }
              let data = Data(jsonString.utf8)
              if let apiError = try? decoder.decode(GoogleCloudAPIError.self, from: data) {
                let headerRetryAfter = parseRetryAfterHeader(from: response)
                let resolvedError = headerRetryAfter.map { apiError.withRetryDelay($0) } ?? apiError
                throw GeminiAPIError.apiError(resolvedError)
              }
              let responseChunk = try decoder.decode(GenerateContentResponse.self, from: data)
              continuation.yield(responseChunk)
            } else {
              extraLines.append(line)
              extraLines.append("\n")
            }
          }

          let trimmedExtra = extraLines.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmedExtra.isEmpty {
            let data = Data(trimmedExtra.utf8)
            throw parseError(from: data, statusCode: response.statusCode, response: response)
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in
        streamTask.cancel()
        bytes.task?.cancel()
      }
    }
  }

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
}
