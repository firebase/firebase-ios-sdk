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
import GeminiTestUtilities
import Testing

@testable import GeminiAPIClient

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("GeminiAPIClient Integration Tests", .tags(.integration))
struct GeminiAPIClientIntegrationTests {
  @Test(
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentSimplePrompt(backend: IntegrationTestingBackend) async throws {
    let client = try backend.makeClient()
    let request = makePromptRequest("Reply with the single word 'HELLO'.")

    let stream = try await client.generateContentStream(for: request)
    var accumulatedText = ""
    var chunkCount = 0
    for try await chunk in stream {
      chunkCount += 1
      if let text = extractText(from: chunk) {
        accumulatedText += text
      }
    }

    #expect(chunkCount > 0)
    #expect(!accumulatedText.isEmpty)
    #expect(accumulatedText.localizedCaseInsensitiveContains("HELLO"))
  }

  @Test(
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMultiTurn(backend: IntegrationTestingBackend) async throws {
    let client = try backend.makeClient()
    let contents: [Content] = [
      .text("My favorite color is teal.", role: "user"),
      .text("Got it! Your favorite color is teal.", role: "model"),
      .text("What is my favorite color? Answer in one word.", role: "user"),
    ]
    let request = GenerateContentRequest { $0.contents = contents }

    let stream = try await client.generateContentStream(for: request)
    var accumulatedText = ""
    var chunkCount = 0
    for try await chunk in stream {
      chunkCount += 1
      if let text = extractText(from: chunk) {
        accumulatedText += text
      }
    }

    #expect(chunkCount > 0)
    #expect(!accumulatedText.isEmpty)
    #expect(accumulatedText.localizedCaseInsensitiveContains("teal"))
  }

  @Test(
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithSystemInstruction(
    backend: IntegrationTestingBackend
  ) async throws {
    let client = try backend.makeClient()
    let systemInstruction = Content.text("Always speak like a 17th-century pirate.")
    let request = GenerateContentRequest {
      $0.systemInstruction = systemInstruction
      $0.contents = [.text("How is the weather today?", role: "user")]
    }

    let stream = try await client.generateContentStream(for: request)
    var accumulatedText = ""
    var chunkCount = 0
    for try await chunk in stream {
      chunkCount += 1
      if let text = extractText(from: chunk) {
        accumulatedText += text
      }
    }

    #expect(chunkCount > 0)
    #expect(!accumulatedText.isEmpty)
  }

  @Test(
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentInvalidModelNameThrows(
    backend: IntegrationTestingBackend
  ) async throws {
    let client = try backend.makeClient(modelID: "non-existent-model-name-xyz-123")
    let request = makePromptRequest("Hello")

    await #expect(throws: (any Error).self) {
      let stream = try await client.generateContentStream(for: request)
      for try await _ in stream {}
    }
  }

  // test-server v0.2.9 replays a JSON error body on a streaming URL as a server-sent event, so
  // `GeminiAPIClient` reports `.httpError` instead of `.apiError` in replay mode. Remove the
  // `.disabled` trait once test-server records body formats (see Tests/TestServer/README.md).
  @Test(
    .requireIntegrationTestingBackend,
    .disabled(
      if: IntegrationTestEnvironment.process.integrationTestMode == .replay,
      "test-server v0.2.9 replays JSON error bodies on streaming URLs as server-sent events"
    ),
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithoutAuthThrows(backend: IntegrationTestingBackend) async throws {
    let client = try backend.makeClient(authenticated: false)
    let request = makePromptRequest("Hello")

    do {
      let stream = try await client.generateContentStream(for: request)
      for try await _ in stream {}
      Issue.record("Expected request to throw due to missing authentication")
    } catch let GeminiAPIError.apiError(apiError) {
      #expect(apiError.code == 400 || apiError.code == 403 || apiError.code == 401)
    } catch {
      Issue.record("Unexpected error thrown: \(error)")
    }
  }

  @Test(
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensSimplePrompt(backend: IntegrationTestingBackend) async throws {
    let client = try backend.makeClient()
    let request = CountTokensRequest {
      $0.contents = [.text("The quick brown fox jumps over the lazy dog.", role: "user")]
    }

    let response = try await client.countTokens(for: request)

    let totalTokens = try #require(response.totalTokens)
    #expect(totalTokens > 0)
  }

  // MARK: - Test Helpers

  private func extractText(from response: GenerateContentResponse?) -> String? {
    guard let parts = response?.candidates?.first?.content?.parts else { return nil }
    let textParts = parts.compactMap { part -> String? in
      if case .text(let text) = part.data { return text }
      return nil
    }
    return textParts.isEmpty ? nil : textParts.joined()
  }

  /// Returns a request containing a single user turn with `prompt`.
  ///
  /// - Parameter prompt: The text of the user turn.
  /// - Returns: A `GenerateContentRequest` with one user `Content`.
  private func makePromptRequest(_ prompt: String) -> GenerateContentRequest {
    GenerateContentRequest { $0.contents = [.text(prompt, role: "user")] }
  }
}
