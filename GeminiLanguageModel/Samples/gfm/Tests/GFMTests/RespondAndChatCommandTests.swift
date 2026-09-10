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

import ArgumentParser
import Foundation
import Testing

@testable import GFMCore

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels
  import GeminiLanguageModel

  @Suite("RespondAndChatCommand Tests")
  struct RespondAndChatCommandTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func respondCommandDefaults() throws {
      let cmd = try RespondCommand.parse(["What is Swift?"])

      #expect(cmd.prompt == "What is Swift?")
      #expect(cmd.model == .gemini)
      #expect(cmd.geminiModel == "gemini-3.5-flash-lite")
      #expect(cmd.apiVariant == .generateContent)
      #expect(cmd.stream == true)
      #expect(cmd.greedy == false)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func respondCommandOptionsParsing() throws {
      let cmd = try RespondCommand.parse([
        "--model", "system",
        "-i", "Be concise",
        "--tool", "current-time",
        "--greedy",
        "Hello",
      ])

      #expect(cmd.prompt == "Hello")
      #expect(cmd.model == .system)
      #expect(cmd.instructions == "Be concise")
      #expect(cmd.tool == ["current-time"])
      #expect(cmd.greedy == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func respondCommandAPIVariantParsing() throws {
      let longFlagCmd = try RespondCommand.parse(["--api-variant", "interactions", "Hello"])
      let shortAliasCmd = try RespondCommand.parse(["--api", "interactions", "Hello"])
      let generateCmd = try RespondCommand.parse(["--api-variant", "generate-content", "Hello"])

      #expect(longFlagCmd.apiVariant == .interactions)
      #expect(shortAliasCmd.apiVariant == .interactions)
      #expect(generateCmd.apiVariant == .generateContent)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func chatCommandDefaults() throws {
      let cmd = try ChatCommand.parse([])

      #expect(cmd.model == .gemini)
      #expect(cmd.geminiModel == "gemini-3.5-flash-lite")
      #expect(cmd.apiVariant == .generateContent)
      #expect(cmd.continue == false)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func chatCommandOptionsParsing() throws {
      let cmd = try ChatCommand.parse([
        "--model", "system",
        "-r", "saved-session",
        "--tool", "current-time",
      ])

      #expect(cmd.model == .system)
      #expect(cmd.resume == "saved-session")
      #expect(cmd.tool == ["current-time"])
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func chatCommandAPIVariantParsing() throws {
      let longFlagCmd = try ChatCommand.parse(["--api-variant", "interactions"])
      let shortAliasCmd = try ChatCommand.parse(["--api", "interactions"])

      #expect(longFlagCmd.apiVariant == .interactions)
      #expect(shortAliasCmd.apiVariant == .interactions)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func apiVariantArgumentParsing() {
      let generateContentCases = [
        APIVariantChoice(argument: "generate-content"),
        APIVariantChoice(argument: "generatecontent"),
        APIVariantChoice(argument: "generate_content"),
      ]
      let interactionsCases = [
        APIVariantChoice(argument: "interactions"),
        APIVariantChoice(argument: "interaction"),
      ]
      let invalid = APIVariantChoice(argument: "unknown")

      for parsed in generateContentCases {
        #expect(parsed == .generateContent)
        #expect(parsed?.apiVariant == .generateContent)
      }
      for parsed in interactionsCases {
        #expect(parsed == .interactions)
        #expect(parsed?.apiVariant == .interactions)
      }
      #expect(invalid == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func modelResolverConfiguresAPIVariant() throws {
      let interactionsResolver = ModelResolver(
        apiVariant: .interactions,
        explicitAPIKey: "fake-key"
      )
      let interactionsModel = try interactionsResolver.makeModel()
      let glmInteractions = try #require(interactionsModel as? GeminiLanguageModel)

      #expect(glmInteractions.apiVariant == .interactions)

      let generateContentResolver = ModelResolver(
        apiVariant: .generateContent,
        explicitAPIKey: "fake-key"
      )
      let generateContentModel = try generateContentResolver.makeModel()
      let glmGenerateContent = try #require(generateContentModel as? GeminiLanguageModel)

      #expect(glmGenerateContent.apiVariant == .generateContent)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func resolvePromptWithArgumentOnly() throws {
      let cmd = try RespondCommand.parse(["What is Swift?"])

      let prompt = try cmd.resolvePrompt(stdinReader: { nil })

      #expect(prompt == "What is Swift?")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func resolvePromptWithStdinOnly() throws {
      let cmd = try RespondCommand.parse([])

      let prompt = try cmd.resolvePrompt(stdinReader: { "Piped document text." })

      #expect(prompt == "Piped document text.")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func resolvePromptWithStdinAndArgumentCombined() throws {
      let cmd = try RespondCommand.parse(["What are the main takeaways?"])

      let prompt = try cmd.resolvePrompt(stdinReader: { "Article contents here." })

      #expect(prompt == "Article contents here.\n\nWhat are the main takeaways?")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func resolvePromptWithNeitherThrows() throws {
      let cmd = try RespondCommand.parse([])

      #expect(throws: ValidationError.self) {
        try cmd.resolvePrompt(stdinReader: { nil })
      }
    }
  }
#endif
