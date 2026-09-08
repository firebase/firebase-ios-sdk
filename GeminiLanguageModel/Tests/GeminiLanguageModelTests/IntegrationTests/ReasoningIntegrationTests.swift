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
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  /// Integration tests for reasoning and thought summaries using `GeminiLanguageModel`.
  @Suite(
    "Reasoning Integration Tests",
    .requireFoundationModels,
    .tags(.integration),
    .serialized
  )
  struct ReasoningIntegrationTests {
    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithThinkingSummariesAuto(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel(
        thinking: GeminiLanguageModel.Thinking(summaries: .auto)
      )
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: """
          Solve this step-by-step logic puzzle: In a room, there are 3 switches that control 3 \
          light bulbs in another room. You can only enter the room with the bulbs once. How do you \
          determine which switch controls which bulb? Think thoroughly and deduce the answer.
          """,
        contextOptions: ContextOptions(reasoningLevel: .deep)
      )

      #expect(!response.content.isEmpty)
      let thoughtSummary = try #require(response.geminiThoughtSummary)
      #expect(!thoughtSummary.isEmpty)
      #expect(session.transcript.geminiThoughtSummary == thoughtSummary)
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionDynamicProfileWithGeminiThinking(backend: IntegrationTestingBackend)
      async throws
    {
      let model = try await backend.makeModel()

      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful math tutor.")
      }
      .model(model)
      .reasoningLevel(.deep)
      .geminiThinking(summaries: .auto)

      let session = LanguageModelSession(profile: profile)

      let response = try await session.respond(
        to: "What is 17 multiplied by 24? Show your steps and final answer."
      )

      #expect(!response.content.isEmpty)
      let thoughtSummary = try #require(response.geminiThoughtSummary)
      #expect(!thoughtSummary.isEmpty)
      let sessionThoughtSummary = try #require(session.properties.geminiThoughtSummary)
      #expect(!sessionThoughtSummary.isEmpty)
      #expect(sessionThoughtSummary == thoughtSummary)
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithRequestMetadata(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        contextOptions: ContextOptions(reasoningLevel: .deep),
        metadata: .gemini(thinkingSummaries: .auto),
      ) {
        "Which is heavier: a pound of feathers or a pound of gold? Explain your reasoning briefly."
      }

      #expect(!response.content.isEmpty)
      let thoughtSummary = try #require(response.geminiThoughtSummary)
      #expect(!thoughtSummary.isEmpty)
      #expect(session.transcript.geminiThoughtSummary == thoughtSummary)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
