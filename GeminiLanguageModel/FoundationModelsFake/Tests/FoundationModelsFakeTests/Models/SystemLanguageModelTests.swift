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

#if compiler(>=6.4)
  import Foundation
  import FoundationModelsFake
  import Testing

  // MARK: - Test Support Types

  private struct EchoFallbackModel: LanguageModel {
    struct Executor: LanguageModelExecutor {
      struct Configuration: Hashable, Sendable {}

      init(configuration: Configuration) throws {}

      nonisolated(nonsending) func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: EchoFallbackModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        await channel.send(
          .response(
            entryID: "fallback-response",
            action: .appendText("fallback-ok", tokenCount: 2)
          )
        )
      }
    }

    var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning])
    }

    var executorConfiguration: Executor.Configuration {
      Executor.Configuration()
    }
  }

  private struct TokenCountTestTool: Tool {
    @Generable
    struct Arguments {
      var query: String
    }

    var name: String { "search_docs" }
    var description: String { "Searches local documentation by query string." }

    func call(arguments: Arguments) async throws -> String {
      arguments.query
    }
  }

  private struct TestDynamicInstructions: DynamicInstructions {
    var body: some DynamicInstructions {
      Instructions("Dynamic instructions using default SystemLanguageModel.")
    }
  }

  private struct SystemOrFallbackProfile: LanguageModelSession.DynamicProfile {
    let forceFallback: Bool

    var body: some LanguageModelSession.DynamicProfile {
      if !forceFallback && SystemLanguageModel.default.isAvailable {
        Profile {
          Instructions("Use the on-device system model.")
        }
        .model(SystemLanguageModel.default)
      } else {
        Profile {
          Instructions("Use the cross-platform fallback model.")
        }
        .model(EchoFallbackModel())
      }
    }
  }

  // MARK: - Tests

  @Suite("SystemLanguageModel Tests")
  struct SystemLanguageModelTests {
    @Test
    func defaultModelPropertiesAndCapabilities() {
      let model = SystemLanguageModel.default

      let capabilities = model.capabilities
      let contextSize = model.contextSize
      let variant = model.variant
      let availability = model.availability
      let isAvailable = model.isAvailable
      let supportedLanguages = model.supportedLanguages

      #expect(capabilities.contains(.guidedGeneration))
      #expect(capabilities.contains(.toolCalling))
      #expect(capabilities.contains(.reasoning))
      #expect(!capabilities.contains(.vision))
      #expect(contextSize == 4096)
      #expect(variant == .core3)
      #expect(variant.displayName == "Core 3B")
      #expect(SystemLanguageModel.Variant.coreAdvanced3.displayName == "Core Advanced 3B")
      #expect(availability == .unavailable(.deviceNotEligible))
      #expect(!isAvailable)
      #expect(supportedLanguages.isEmpty)
      #expect(!model.supportsLocale(Locale(identifier: "en_US")))
    }

    @Test
    func useCaseAndGuardrailsConfigurations() {
      let generalDefault = SystemLanguageModel(useCase: .general, guardrails: .default)
      let taggingPermissive = SystemLanguageModel(
        useCase: .contentTagging,
        guardrails: .permissiveContentTransformations
      )

      let configA = generalDefault.executorConfiguration
      let configB = taggingPermissive.executorConfiguration

      #expect(SystemLanguageModel.UseCase.general != .contentTagging)
      #expect(configA != configB)
    }

    @Test
    func availabilityEquatableAndErrorDescriptions() {
      let availabilities: [SystemLanguageModel.Availability] = [
        .available,
        .unavailable(.deviceNotEligible),
        .unavailable(.appleIntelligenceNotEnabled),
        .unavailable(.modelNotReady),
      ]
      let error = SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "Missing"))

      let distinctPairs = availabilities.indices.flatMap { lhs in
        availabilities.indices.filter { $0 != lhs && availabilities[$0] == availabilities[lhs] }
      }

      #expect(distinctPairs.isEmpty)
      #expect(error.errorDescription == "Missing")
      #expect(error.debugDescription == "Missing")
    }

    @Test
    func tokenCountOverloads() async throws {
      let model = SystemLanguageModel.default
      let prompt = Prompt("Count the tokens in this prompt sentence.")
      let instructions = Instructions("You are a concise assistant.")
      let tools: [any Tool] = [TokenCountTestTool()]
      let schema = TokenCountTestTool.Arguments.generationSchema
      let entries: [Transcript.Entry] = [
        .instructions(
          Transcript.Instructions(
            segments: [.text(.init(content: "You are a concise assistant."))],
            toolDefinitions: [Transcript.ToolDefinition(tool: TokenCountTestTool())]
          )
        ),
        .prompt(
          Transcript.Prompt(
            segments: [.text(.init(content: "Count the tokens in this prompt sentence."))]
          )
        ),
      ]

      let promptTokens = try await model.tokenCount(for: prompt)
      let instructionTokens = try await model.tokenCount(for: instructions)
      let toolTokens = try await model.tokenCount(for: tools)
      let schemaTokens = try await model.tokenCount(for: schema)
      let entryTokens = try await model.tokenCount(for: entries)
      let emptyToolTokens = try await model.tokenCount(for: [] as [any Tool])

      #expect(promptTokens > 0)
      #expect(instructionTokens > 0)
      #expect(toolTokens > 0)
      #expect(schemaTokens > 0)
      #expect(entryTokens >= promptTokens + instructionTokens)
      #expect(emptyToolTokens == 0)
    }

    @Test
    func sessionDefaultModelInitializers() {
      let bareSession = LanguageModelSession()
      let stringSession = LanguageModelSession(instructions: "Be helpful.")
      let builderSession = LanguageModelSession {
        "Built instructions."
      }
      let instructionsSession = LanguageModelSession(instructions: Instructions("Explicit."))
      let transcriptSession = LanguageModelSession(transcript: Transcript())
      let dynamicSession = LanguageModelSession(
        dynamicInstructions: TestDynamicInstructions()
      )

      let counts = [
        bareSession.transcript.count,
        stringSession.transcript.count,
        builderSession.transcript.count,
        instructionsSession.transcript.count,
        transcriptSession.transcript.count,
        dynamicSession.transcript.count,
      ]

      #expect(counts == [0, 1, 1, 1, 0, 1])
    }

    @Test
    func dynamicProfileBranchingBetweenSystemAndFallbackModel() async throws {
      let forcedSession = LanguageModelSession(
        profile: SystemOrFallbackProfile(forceFallback: true))
      let unforcedSession = LanguageModelSession(
        profile: SystemOrFallbackProfile(forceFallback: false)
      )

      let forcedResponse = try await forcedSession.respond(to: "Ping")
      let unforcedResponse = try await unforcedSession.respond(to: "Ping")

      #expect(forcedResponse.content == "fallback-ok")
      #expect(forcedSession.transcript.count == 3)
      #expect(unforcedResponse.content == "fallback-ok")
    }

    @Test
    func respondThrowsAssetsUnavailable() async throws {
      let session = LanguageModelSession(
        model: SystemLanguageModel.default,
        tools: [TokenCountTestTool()],
        instructions: "Reply in one short sentence."
      )

      await #expect(throws: SystemLanguageModel.Error.self) {
        _ = try await session.respond(to: "Say hello.")
      }
    }
  }
#endif  // compiler(>=6.4)
