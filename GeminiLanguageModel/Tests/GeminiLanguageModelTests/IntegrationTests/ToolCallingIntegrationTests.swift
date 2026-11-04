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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  import Foundation
  #if FoundationModelsFake
    import FoundationModelsFake
  #else
    import FoundationModels
  #endif
  import GeminiAPIClient
  import GeminiTestUtilities
  import Synchronization
  import Testing

  @testable import GeminiLanguageModel

  /// Integration tests for tool calling using `GeminiLanguageModel`.
  @Suite(
    "Tool Calling Integration Tests",
    .requireFoundationModels,
    .tags(.integration),
    // Fails runaway tool-call loops instead of hanging until the request times out.
    .timeLimit(.minutes(2))
  )
  struct ToolCallingIntegrationTests {
    /// A tool that provides mock weather information for a given city.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct WeatherTool: FoundationModelsTool {
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
        "The current weather in \(arguments.city) is 22°C and sunny."
      }
    }

    /// A tool that provides the current time and takes no arguments.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CurrentTimeTool: FoundationModelsTool {
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

    /// A structured weather summary used to exercise guided generation alongside tool calling.
    @Generable
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CurrentWeather {
      @Generable
      enum Conditions {
        case cloudy
        case rainy
        case sunny
      }

      @Guide(description: "The current temperature in Celsius")
      let temperature: Int

      @Guide(description: "The current weather conditions")
      let conditions: Conditions
    }

    @Test(
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
        || response.content.contains("22")
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
      let hasReasoning = session.transcript.contains { entry in
        if case .reasoning = entry { return true }
        return false
      }
      #expect(hasReasoning, "Expected the tool call's thought signature in a reasoning entry.")
      #expect(response.usage.totalTokenCount > 0)
    }

    @Test(
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
        || secondResponse.content.contains("22")
      #expect(containsMiamiOrTemp)
      let toolCallCount = session.transcript.filter { entry in
        if case .toolCalls = entry { return true }
        return false
      }.count
      #expect(toolCallCount >= 2)
    }

    @Test(
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
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondToolCallAndGuidedGeneration(backend: IntegrationTestingBackend) async throws
    {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(
        model: model,
        tools: [WeatherTool()]
      )

      let response = try await session.respond(
        to: "What is the weather in Paris right now?",
        generating: CurrentWeather.self
      )

      #expect(response.content.temperature == 22)
      #expect(response.content.conditions == .sunny)
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

    /// A weather tool that counts how many times the model calls it.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CountingWeatherTool: FoundationModels.Tool {
      /// The number of calls, shared by all copies of the tool.
      final class CallCount: Sendable {
        let value = Mutex(0)
      }

      let name = "getWeather"
      let description = "Get the current weather for a city."
      let callCount = CallCount()

      @Generable
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      @available(tvOS, unavailable)
      struct Arguments {
        @Guide(description: "The city name to look up weather for")
        var city: String
      }

      func call(arguments: Arguments) async throws -> String {
        callCount.value.withLock { $0 += 1 }
        return "The current weather in \(arguments.city) is 22°C and sunny."
      }
    }

    @Test(
      .requireIntegrationTestingBackend,
      .timeLimit(.minutes(2)),
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondRequiredToolCallingStopsAtToolCallingTurnLimit(
      backend: IntegrationTestingBackend
    ) async throws {
      let maximumTurns = GeminiLanguageModel.Executor.Configuration.defaultMaximumToolCallingTurns
      let model = try await backend.makeModel()
      let tool = CountingWeatherTool()
      let session = LanguageModelSession(model: model, tools: [tool])

      // With `required`, the model calls a tool in every response until the limit is reached.
      do {
        let response = try await session.respond(
          to: "What is the weather in Paris right now?",
          options: GenerationOptions(toolCallingMode: .required)
        )
        #expect(!response.content.isEmpty)
      } catch GeminiLanguageModel.Error.invalidResponse {
        // Gemini sometimes returns a function call after being told not to, which ends the turn
        // with this error instead of a response.
      }

      #expect(tool.callCount.value.withLock { $0 } == maximumTurns)
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
