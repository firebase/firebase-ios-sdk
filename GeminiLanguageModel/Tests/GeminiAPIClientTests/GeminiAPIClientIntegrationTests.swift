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
import SharedTestUtilities
import Testing

@testable import GeminiAPIClient

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("GeminiAPIClient Integration Tests")
struct GeminiAPIClientIntegrationTests {
  private static let defaultEndpointConfiguration = EndpointConfiguration(
    host: "generativelanguage.googleapis.com",
    apiVersion: "v1beta"
  )
  private static let defaultModelResource = ModelResource(
    modelID: "gemini-3.5-flash-lite",
    urlResourceName: "models/gemini-3.5-flash-lite",
    payloadResourceName: "models/gemini-3.5-flash-lite"
  )

  @Test(.requireAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentSimplePrompt() async throws {
    let client = makeClient()
    let request = GenerateContentRequest(
      contents: [
        Content(
          parts: [Part(data: .text("Reply with the single word 'HELLO'."))],
          role: "user"
        )
      ]
    )

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

  @Test(.requireAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentMultiTurn() async throws {
    let client = makeClient()
    let contents = [
      Content(parts: [Part(data: .text("My favorite color is teal."))], role: "user"),
      Content(parts: [Part(data: .text("Got it! Your favorite color is teal."))], role: "model"),
      Content(
        parts: [Part(data: .text("What is my favorite color? Answer in one word."))],
        role: "user"
      ),
    ]
    let request = GenerateContentRequest(contents: contents)

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

  @Test(.requireAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithSystemInstruction() async throws {
    let client = makeClient()
    let systemInstruction = Content(
      parts: [Part(data: .text("Always speak like a 17th-century pirate."))]
    )
    let request = GenerateContentRequest(
      model: nil,
      systemInstruction: systemInstruction,
      contents: [
        Content(
          parts: [Part(data: .text("How is the weather today?"))],
          role: "user"
        )
      ]
    )

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

  @Test(.requireAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentInvalidModelNameThrows() async throws {
    let invalidResource = ModelResource(
      modelID: "non-existent-model-name-xyz-123",
      urlResourceName: "models/non-existent-model-name-xyz-123",
      payloadResourceName: "models/non-existent-model-name-xyz-123"
    )
    let client = makeClient(modelResource: invalidResource)
    let request = GenerateContentRequest(
      contents: [
        Content(
          parts: [Part(data: .text("Hello"))],
          role: "user"
        )
      ]
    )

    await #expect(throws: (any Error).self) {
      let stream = try await client.generateContentStream(for: request)
      for try await _ in stream {}
    }
  }

  @Test(.requireNoAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentWithoutAuthThrows() async throws {
    let client = GeminiAPIClient(
      modelResource: Self.defaultModelResource,
      endpointConfiguration: Self.defaultEndpointConfiguration
    )
    let request = GenerateContentRequest(
      contents: [
        Content(
          parts: [Part(data: .text("Hello"))],
          role: "user"
        )
      ]
    )

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

  @Test(.requireAPIKey)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func countTokensSimplePrompt() async throws {
    let client = makeClient()
    let request = CountTokensRequest(
      contents: [
        Content(
          parts: [Part(data: .text("The quick brown fox jumps over the lazy dog."))],
          role: "user"
        )
      ]
    )

    let response = try await client.countTokens(for: request)

    let totalTokens = try #require(response.totalTokens)
    #expect(totalTokens > 0)
  }

  @Test(.requireFirebaseAILogic)
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamGenerateContentFirebaseAILogicDeveloperAPI() async throws {
    let projectID = try #require(firebaseProjectID)
    let appID = try #require(firebaseAppID)
    let apiKey = try #require(firebaseAPIKey)
    let debugToken = try #require(appCheckDebugToken)
    let appCheckClient = AppCheckDebugClient(
      projectID: projectID,
      appID: appID,
      apiKey: apiKey,
      debugToken: debugToken
    )
    let appCheckToken = try await appCheckClient.exchangeDebugToken()
    let modelResource = ModelResource(
      modelID: "gemini-3.5-flash-lite",
      urlResourceName: "projects/\(projectID)/models/gemini-3.5-flash-lite",
      payloadResourceName: "models/gemini-3.5-flash-lite"
    )
    let endpointConfiguration = EndpointConfiguration(
      host: "firebasevertexai.googleapis.com",
      apiVersion: "v1beta"
    )
    let client = GeminiAPIClient(
      modelResource: modelResource,
      endpointConfiguration: endpointConfiguration,
      headerProvider: HeaderProvider {
        [
          "x-goog-api-key": apiKey,
          "x-firebase-appcheck": appCheckToken,
        ]
      }
    )
    let request = GenerateContentRequest(
      contents: [
        Content(
          parts: [Part(data: .text("Reply with the single word 'HELLO'."))],
          role: "user"
        )
      ]
    )

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

  // MARK: - Test Helpers

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
    modelResource: ModelResource = defaultModelResource,
    endpointConfiguration: EndpointConfiguration = defaultEndpointConfiguration,
    configuration: URLSessionConfiguration = .ephemeral
  ) -> GeminiAPIClient {
    let headerProvider: (@Sendable () async throws -> [String: String])?
    if let apiKey = geminiAPIKey {
      headerProvider = { @Sendable in
        ["x-goog-api-key": apiKey]
      }
    } else {
      headerProvider = nil
    }

    return GeminiAPIClient(
      modelResource: modelResource,
      endpointConfiguration: endpointConfiguration,
      headerProvider: headerProvider.map { HeaderProvider($0) },
      sessionConfiguration: configuration
    )
  }
}
