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

  /// Integration tests for tool calling using `GeminiLanguageModel`.
  @Suite("Tool Calling Integration Tests", .requireFoundationModels)
  struct ToolCallingIntegrationTests {
    /// A tool that provides mock weather information for a given city.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct WeatherTool: FoundationModels.Tool {
      let name = "getWeather"
      let description = "Get the current weather for a city."

      @Generable
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      @available(tvOS, unavailable)
      struct Arguments {
        @Guide(description: "The city name to look up weather for")
        var city: String
      }

      func call(arguments: Arguments) async throws -> String {
        "The current weather in \(arguments.city) is 72°F and sunny."
      }
    }

    /// A tool that provides the current time and takes no arguments.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CurrentTimeTool: FoundationModels.Tool {
      let name = "getCurrentTime"
      let description = "Get the current time."

      @Generable
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      @available(tvOS, unavailable)
      struct Arguments {}

      func call(arguments: Arguments) async throws -> String {
        "12:00 PM UTC"
      }
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondSingleToolCall(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      let response = try await session.respond(
        to: "What is the weather in Paris right now?"
      )

      #expect(!response.content.isEmpty)
      let containsExpected =
        response.content.localizedCaseInsensitiveContains("Paris")
        || response.content.contains("72")
      #expect(containsExpected)
      let hasToolCalls = session.transcript.contains { entry in
        if case .toolCalls = entry { return true }
        return false
      }
      #expect(hasToolCalls)
      let hasToolOutput = session.transcript.contains { entry in
        if case .toolOutput = entry { return true }
        return false
      }
      #expect(hasToolOutput)
      #expect(response.usage.totalTokenCount > 0)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondToolWithEmptyArguments(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [CurrentTimeTool()]
      )

      let response = try await session.respond(to: "What time is it right now?")

      #expect(!response.content.isEmpty)
      let containsExpected =
        response.content.localizedCaseInsensitiveContains("12:00")
        || response.content.localizedCaseInsensitiveContains("PM")
      #expect(containsExpected)
      let hasToolCalls = session.transcript.contains { entry in
        if case .toolCalls = entry { return true }
        return false
      }
      #expect(hasToolCalls)
      let hasToolOutput = session.transcript.contains { entry in
        if case .toolOutput = entry { return true }
        return false
      }
      #expect(hasToolOutput)
      #expect(response.usage.totalTokenCount > 0)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondSequentialToolCalls(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      _ = try await session.respond(to: "What is the weather in Seattle?")

      let secondResponse = try await session.respond(to: "What about in Miami?")

      #expect(!secondResponse.content.isEmpty)
      let containsMiamiOrTemp =
        secondResponse.content.localizedCaseInsensitiveContains("Miami")
        || secondResponse.content.contains("72")
      #expect(containsMiamiOrTemp)
      let toolCallCount = session.transcript.filter { entry in
        if case .toolCalls = entry { return true }
        return false
      }.count
      #expect(toolCallCount >= 2)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondParallelToolCalls(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      let response = try await session.respond(
        to: "What is the weather in Tokyo and in London right now? Compare both."
      )

      #expect(!response.content.isEmpty)
      #expect(response.content.localizedCaseInsensitiveContains("Tokyo"))
      #expect(response.content.localizedCaseInsensitiveContains("London"))
      let hasToolCalls = session.transcript.contains { entry in
        if case .toolCalls = entry { return true }
        return false
      }
      #expect(hasToolCalls)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondToolCallingModeDisallowed(
      backend: IntegrationTestingBackend
    ) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      let response = try await session.respond(
        to: "What is the weather in Boston?",
        options: GenerationOptions(toolCallingMode: .disallowed)
      )

      #expect(!response.content.isEmpty)
      let hasToolCalls = session.transcript.contains { entry in
        if case .toolCalls = entry { return true }
        return false
      }
      #expect(!hasToolCalls)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithReasoningAndToolCalls(
      backend: IntegrationTestingBackend
    ) async throws {
      let model = try await backend.makeModel(modelID: ModelResource.gemini38FlashID)
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      let response = try await session.respond(
        to: "What is the weather in Chicago?"
      )

      #expect(!response.content.isEmpty)
      let containsChicagoOrTemp =
        response.content.localizedCaseInsensitiveContains("Chicago")
        || response.content.contains("72")
      #expect(containsChicagoOrTemp)
      let hasToolCalls = session.transcript.contains { entry in
        if case .toolCalls = entry { return true }
        return false
      }
      #expect(hasToolCalls)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
