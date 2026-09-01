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
import GeminiAPIDataModels
import HTTPStreamingClient
import SharedDataModels
import SharedTestUtilities
import Testing

@testable import GeminiAPIClient

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("GeminiAPIClient Tests")
struct GeminiAPIClientTests {
  private static let baseURLString = "https://generativelanguage.googleapis.com"
  private static let defaultModelResourcePath = "v1beta/models/gemini-3.5-flash-lite"

  private let testID = UUID().uuidString

  private var testBaseURL: URL {
    URL(string: "\(Self.baseURLString)/\(testID)")!
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentSingleChunk() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let ssePayload = """
      data: {"candidates": [{"content": {"parts": [{"text": "Hello world!"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Say hello")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.content?.parts?.first?.data == .text("Hello world!"))
    #expect(candidate.finishReason == .stop)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentSafetyBlockResponse() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let ssePayload = """
      data: {"candidates": [{"content": {}, "finishReason": "SAFETY", "index": 0, "finishMessage": "The model output could not be generated due to safety policy.", "safetyRatings": [{"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "probability": "HIGH"}]}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Safety test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.finishReason == .safety)
    #expect(candidate.finishMessage?.contains("safety policy") == true)
    #expect(candidate.safetyRatings?.first?.category == .dangerousContent)
    #expect(candidate.content?.parts?.first?.data == nil)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentRecitationBlockResponse() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let ssePayload = """
      data: {"candidates": [{"finishReason": "RECITATION", "index": 0}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Recitation test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.finishReason == .recitation)
    #expect(candidate.content?.parts?.first?.data == nil)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMultipleChunks() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let ssePayload = """
      data: {"candidates": [{"content": {"parts": [{"text": "Hello"}], "role": "model"}}]}

      data: {"candidates": [{"content": {"parts": [{"text": " world"}], "role": "model"}}]}

      data: {"candidates": [{"content": {"parts": [{"text": "!"}], "role": "model"}, "finishReason": "STOP"}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Say hello world")
    let stream = try await client.generateContentStream(for: request)
    var collectedText = ""
    for try await chunk in stream {
      if let text = extractText(from: chunk) {
        collectedText += text
      }
    }

    #expect(collectedText == "Hello world!")
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentAPIError() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 400,
      headerFields: ["Content-Type": "application/json"]
    )

    let errorJSON = """
      {
        "error": {
          "code": 400,
          "message": "API key not valid. Please pass a valid API key.",
          "status": "INVALID_ARGUMENT"
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(errorJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Invalid key test")

    await #expect(throws: GeminiAPIError.self) {
      try await client.generateContentStream(for: request)
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentHTTPError() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 500,
      headerFields: nil
    )

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("Internal Server Error".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Internal error test")

    do {
      _ = try await client.generateContentStream(for: request)
      Issue.record("Expected GeminiAPIError.httpError to be thrown")
    } catch let GeminiAPIError.httpError(statusCode, body) {
      #expect(statusCode == 500)
      #expect(body == "Internal Server Error")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentRateLimitError() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 429,
      headerFields: [
        "Content-Type": "application/json",
        "Retry-After": "60",
      ]
    )

    let errorJSON = """
      {
        "error": {
          "code": 429,
          "message": "Resource has been exhausted (e.g. check quota).",
          "status": "RESOURCE_EXHAUSTED"
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(errorJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Rate limit test")

    do {
      _ = try await client.generateContentStream(for: request)
      Issue.record("Expected GeminiAPIError.apiError to be thrown")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 429)
      #expect(apiError.status == .resourceExhausted)
      #expect(apiError.message.contains("Resource has been exhausted"))
      #expect(apiError.retryDelay == .seconds(60))
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentRateLimitWithRetryInfoJSON() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 429,
      headerFields: ["Content-Type": "application/json"]
    )

    let errorJSON = """
      {
        "error": {
          "code": 429,
          "message": "Resource has been exhausted (e.g. check quota).",
          "status": "RESOURCE_EXHAUSTED",
          "details": [
            {
              "@type": "type.googleapis.com/google.rpc.RetryInfo",
              "retryDelay": "45.5s"
            }
          ]
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(errorJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Rate limit test")

    do {
      _ = try await client.generateContentStream(for: request)
      Issue.record("Expected GeminiAPIError.apiError to be thrown")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 429)
      #expect(apiError.status == .resourceExhausted)
      #expect(apiError.retryDelay == .seconds(45.5))
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func headerProviderInjectsHeaders() async throws {
    let client = makeClient(
      headerProvider: {
        [
          "x-goog-api-key": "custom-key",
          "X-AppCheck-Token": "app-check-123",
        ]
      }
    )

    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 200,
      headerFields: nil
    )

    MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
      #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "custom-key")
      #expect(request.value(forHTTPHeaderField: "X-AppCheck-Token") == "app-check-123")
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(
        proto,
        didLoad: Data(
          "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"OK\"}]}}]}\n\n".utf8)
      )
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let stream = try await client.generateContentStream(
      for: makePromptRequest("Header test"))
    var count = 0
    for try await chunk in stream {
      count += 1
      #expect(extractText(from: chunk) == "OK")
    }

    #expect(count == 1)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentClientTimeoutThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didFailWithError: URLError(.timedOut))
    }

    let request = makePromptRequest("Timeout test")

    await #expect(throws: URLError.self) {
      try await client.generateContentStream(for: request)
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentGatewayTimeoutThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 504,
      headerFields: ["Content-Type": "application/json"]
    )

    let errorJSON = """
      {
        "error": {
          "code": 504,
          "message": "Deadline exceeded while waiting for model response.",
          "status": "DEADLINE_EXCEEDED"
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(errorJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Gateway timeout test")

    do {
      _ = try await client.generateContentStream(for: request)
      Issue.record("Expected GeminiAPIError.apiError to be thrown")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 504)
      #expect(apiError.status == .deadlineExceeded)
      #expect(apiError.message.contains("Deadline exceeded"))
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMidStreamErrorThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let payload = """
      data: {"candidates": [{"content": {"parts": [{"text": "First "}]},"finishReason": "STOP","index": 0}]}

      data: {"candidates": [{"content": {"parts": [{"text": "Second "}]},"finishReason": "STOP","index": 0}]}

      {
        "error": {
          "code": 499,
          "message": "The operation was cancelled.",
          "status": "CANCELLED",
          "details": [
            {
              "@type": "type.googleapis.com/google.rpc.DebugInfo",
              "detail": "[ORIGINAL ERROR] generic::cancelled: "
            }
          ]
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Mid-stream error test")
    let stream = try await client.generateContentStream(for: request)
    var collectedText = ""

    do {
      for try await chunk in stream {
        if let text = extractText(from: chunk) {
          collectedText += text
        }
      }
      Issue.record("Expected GeminiAPIError.apiError to be thrown mid-stream")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(collectedText == "First Second ")
      #expect(apiError.code == 499)
      #expect(apiError.status == .cancelled)
      #expect(apiError.message == "The operation was cancelled.")
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentErrorInSSEDataThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let payload = """
      data: {"error": {"code": 500, "message": "Internal error occurred.", "status": "INTERNAL"}}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("SSE error test")
    let stream = try await client.generateContentStream(for: request)

    do {
      for try await _ in stream {}
      Issue.record("Expected GeminiAPIError.apiError to be thrown")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 500)
      #expect(apiError.status == .internalError)
      #expect(apiError.message == "Internal error occurred.")
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMidStreamUnrecognizedTextThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let payload = """
      data: {"candidates": [{"content": {"parts": [{"text": "Hello"}]}}]}

      Unrecognized non-JSON error payload
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Unrecognized payload test")
    let stream = try await client.generateContentStream(for: request)
    var collectedText = ""

    do {
      for try await chunk in stream {
        if let text = extractText(from: chunk) {
          collectedText += text
        }
      }
      Issue.record("Expected GeminiAPIError.httpError to be thrown")
    } catch let GeminiAPIError.httpError(statusCode, body) {
      #expect(collectedText == "Hello")
      #expect(statusCode == 200)
      #expect(body == "Unrecognized non-JSON error payload")
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensSuccess() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL(action: "countTokens", query: nil)
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "application/json"]
    )

    let jsonPayload = """
      {
        "totalTokens": 42,
        "cachedContentTokenCount": 10
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(jsonPayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = CountTokensRequest(
      contents: [Content(parts: [Part(data: .text("Count me"))], role: "user")]
    )
    let response = try await client.countTokens(for: request)

    #expect(response.totalTokens == 42)
    #expect(response.cachedContentTokenCount == 10)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensAPIError() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL(action: "countTokens", query: nil)
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 400,
      headerFields: ["Content-Type": "application/json"]
    )

    let errorJSON = """
      {
        "error": {
          "code": 400,
          "message": "Invalid argument for token count",
          "status": "INVALID_ARGUMENT"
        }
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(errorJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = CountTokensRequest(contents: [])

    do {
      _ = try await client.countTokens(for: request)
      Issue.record("Expected GeminiAPIError.apiError to be thrown")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 400)
      #expect(apiError.status == .invalidArgument)
      #expect(apiError.message == "Invalid argument for token count")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensDecodingErrorThrows() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL(action: "countTokens", query: nil)
    let httpResponse = try makeResponse(
      url: expectedURL,
      statusCode: 200,
      headerFields: ["Content-Type": "application/json"]
    )

    let invalidJSON = "{\"totalTokens\": \"invalid-type-string\"}"

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(invalidJSON.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = CountTokensRequest(contents: [])

    await #expect(throws: DecodingError.self) {
      _ = try await client.countTokens(for: request)
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMultiLineSSEData() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )

    let ssePayload = """
      data: {"candidates": [{"content": {"parts":
      data: [{"text": "Multi-line SSE"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Multi-line test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.content?.parts?.first?.data == .text("Multi-line SSE"))
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithComments() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )
    let ssePayload = """
      : keep-alive ping

      data: {"candidates": [{"content": {"parts": [{"text": "With comments"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

      : end of stream

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Comments test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.content?.parts?.first?.data == .text("With comments"))
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithSSEControlFields() async throws {
    let client = makeClient()
    let expectedURL = try makeExpectedURL()
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )
    let ssePayload = """
      event: message
      id: 101
      retry: 3000
      data: {"candidates": [{"content": {"parts": [{"text": "SSE control fields ignored"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Control fields test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let candidate = try #require(responses.first?.candidates?.first)
    #expect(candidate.content?.parts?.first?.data == .text("SSE control fields ignored"))
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentAgentPlatformResourcePath() async throws {
    let agentPlatformPath =
      "v1beta1/projects/my-project/locations/global/publishers/google/models/gemini-3.5-flash-lite"
    let client = makeClient(modelResourcePath: agentPlatformPath)
    let expectedURL = try makeExpectedURL(modelResourcePath: agentPlatformPath)
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )
    let ssePayload = """
      data: {"candidates": [{"content": {"parts": [{"text": "Agent Platform response"}]}}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Agent Platform test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let response = try #require(responses.first)
    let candidate = try #require(response.candidates?.first)
    let content = try #require(candidate.content)
    let part = try #require(content.parts?.first)
    #expect(part.data == .text("Agent Platform response"))
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentFirebaseProxyResourcePath() async throws {
    let firebaseProxyPath = "v1beta/projects/my-firebase-project/models/gemini-3.5-flash-lite"
    let client = makeClient(modelResourcePath: firebaseProxyPath)
    let expectedURL = try makeExpectedURL(modelResourcePath: firebaseProxyPath)
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "text/event-stream"]
    )
    let ssePayload = """
      data: {"candidates": [{"content": {"parts": [{"text": "Firebase AI Logic response"}]}}]}

      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = makePromptRequest("Firebase AI Logic test")
    let stream = try await client.generateContentStream(for: request)
    var responses: [GenerateContentResponse] = []
    for try await chunk in stream {
      responses.append(chunk)
    }

    #expect(responses.count == 1)
    let response = try #require(responses.first)
    let candidate = try #require(response.candidates?.first)
    let content = try #require(candidate.content)
    let part = try #require(content.parts?.first)
    #expect(part.data == .text("Firebase AI Logic response"))
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensAgentPlatformResourcePath() async throws {
    let agentPlatformPath =
      "v1beta1/projects/my-project/locations/global/publishers/google/models/gemini-3.5-flash-lite"
    let client = makeClient(modelResourcePath: agentPlatformPath)
    let expectedURL = try makeExpectedURL(
      modelResourcePath: agentPlatformPath, action: "countTokens", query: nil
    )
    let httpResponse = try makeResponse(
      url: expectedURL,
      headerFields: ["Content-Type": "application/json"]
    )
    let jsonPayload = """
      {
        "totalTokens": 128
      }
      """

    MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
      proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data(jsonPayload.utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let request = CountTokensRequest(
      contents: [Content(parts: [Part(data: .text("Agent Platform count tokens"))], role: "user")]
    )
    let response = try await client.countTokens(for: request)

    #expect(response.totalTokens == 128)
  }

  // MARK: - Test Helpers

  private func makePromptRequest(_ prompt: String) -> GenerateContentRequest {
    GenerateContentRequest(
      contents: [Content(parts: [Part(data: .text(prompt))], role: "user")]
    )
  }

  private func extractText(from response: GenerateContentResponse?) -> String? {
    guard let parts = response?.candidates?.first?.content?.parts else { return nil }
    let textParts = parts.compactMap { part -> String? in
      if case .text(let text) = part.data { return text }
      return nil
    }
    return textParts.isEmpty ? nil : textParts.joined()
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  private func makeClient(
    modelResourcePath: String = defaultModelResourcePath,
    baseURL: URL? = nil,
    headerProvider: (@Sendable () async throws -> [String: String])? = nil
  ) -> GeminiAPIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockHTTPURLProtocol.self]
    return GeminiAPIClient(
      modelResourcePath: modelResourcePath,
      baseURL: baseURL ?? testBaseURL,
      headerProvider: headerProvider,
      sessionConfiguration: configuration
    )
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  private func makeResponse(
    url: URL,
    statusCode: Int = 200,
    headerFields: [String: String]? = nil
  ) throws -> HTTPURLResponse {
    try HTTPURLResponse.mock(url: url, statusCode: statusCode, headerFields: headerFields)
  }

  private func makeExpectedURL(
    modelResourcePath: String = defaultModelResourcePath,
    action: String = "streamGenerateContent",
    query: String? = "alt=sse"
  ) throws -> URL {
    var urlString = "\(testBaseURL.absoluteString)/\(modelResourcePath):\(action)"
    if let query {
      urlString += "?\(query)"
    }
    return try #require(URL(string: urlString))
  }
}
