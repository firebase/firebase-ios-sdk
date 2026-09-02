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

  @Suite("GeminiForFoundationModels Integration Tests")
  struct GeminiForFoundationModelsIntegrationTests {
    private static let defaultModelResource = ModelResource(
      modelID: "gemini-3.5-flash-lite",
      urlResourceName: "models/gemini-3.5-flash-lite",
      payloadResourceName: "models/gemini-3.5-flash-lite"
    )
    private static let defaultEndpointConfiguration = EndpointConfiguration(
      host: "generativelanguage.googleapis.com",
      apiVersion: "v1beta"
    )

    private static func resolveAPIKey() -> String? {
      let env = ProcessInfo.processInfo.environment
      if let googleKey = env["GOOGLE_API_KEY"], !googleKey.isEmpty {
        return googleKey
      }
      if let geminiKey = env["GEMINI_API_KEY"], !geminiKey.isEmpty {
        return geminiKey
      }
      return nil
    }

    private static var hasAPIKey: Bool {
      resolveAPIKey() != nil
    }

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
    private func makeModel(
      modelResource: ModelResource = defaultModelResource,
      endpointConfiguration: EndpointConfiguration = defaultEndpointConfiguration
    ) -> GeminiLanguageModel {
      let headerProvider: (@Sendable () async throws -> [String: String])?
      if let apiKey = Self.resolveAPIKey() {
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

    @Test(
      .enabled(
        if: GeminiForFoundationModelsIntegrationTests.hasAPIKey,
        "Requires GOOGLE_API_KEY or GEMINI_API_KEY environment variable"
      )
    )
    func liveSessionRespond() async throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }

      let model = makeModel()
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(to: "Reply with the single word 'HELLO'.")

      #expect(!response.content.isEmpty)
      #expect(response.content.localizedCaseInsensitiveContains("HELLO"))
    }

    @Test(
      .enabled(
        if: GeminiForFoundationModelsIntegrationTests.hasAPIKey,
        "Requires GOOGLE_API_KEY or GEMINI_API_KEY environment variable"
      )
    )
    func liveSessionMultiTurn() async throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }

      let model = makeModel()
      let session = LanguageModelSession(model: model)

      _ = try await session.respond(to: "My favorite color is teal.")
      let response = try await session.respond(to: "What is my favorite color? Answer in one word.")

      #expect(!response.content.isEmpty)
      #expect(response.content.localizedCaseInsensitiveContains("teal"))
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
