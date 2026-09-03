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
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import SharedTestUtilities
  import Testing

  @testable import GeminiForFoundationModels

  @Suite("GeminiForFoundationModels Integration Tests", .requireFoundationModels)
  struct GeminiForFoundationModelsIntegrationTests {
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private func makeModel(
      modelResource: ModelResource = .gemini35FlashLite,
      endpointConfiguration: EndpointConfiguration = .geminiDeveloperAPI
    ) -> GeminiLanguageModel {
      let headerProvider: (@Sendable () async throws -> [String: String])?
      if let apiKey = geminiAPIKey {
        headerProvider = { @Sendable in
          ["x-goog-api-key": apiKey]
        }
      } else {
        headerProvider = nil
      }

      return GeminiLanguageModel(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider
      )
    }

    @Test(.requireAPIKey)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespond() async throws {
      let model = makeModel()
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(to: "Reply with the single word 'HELLO'.")

      #expect(!response.content.isEmpty)
      #expect(response.content.localizedCaseInsensitiveContains("HELLO"))
    }

    @Test(.requireAPIKey)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondMultiTurn() async throws {
      let model = makeModel()
      let session = LanguageModelSession(model: model)

      _ = try await session.respond(to: "My favorite color is teal.")
      let response = try await session.respond(
        to: "What is my favorite color? Answer in one word."
      )

      #expect(!response.content.isEmpty)
      #expect(response.content.localizedCaseInsensitiveContains("teal"))
    }

    @Test(.requireAPIKey)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponse() async throws {
      let model = makeModel()
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse(
        to: "List the numbers 1 through 5, one per line."
      )
      var finalContent = ""
      var snapshotCount = 0
      for try await snapshot in stream {
        finalContent = snapshot.content
        snapshotCount += 1
      }

      #expect(snapshotCount > 1)
      #expect(!finalContent.isEmpty)
      #expect(finalContent.contains("1"))
      #expect(finalContent.contains("5"))
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
