// Copyright 2025 Google LLC
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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseVertexAI
import Testing
import VertexAITestApp

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

@testable import struct FirebaseVertexAI.BackendError

@Suite(.serialized)
struct GenerateContentIntegrationTests {
  // Set temperature, topP and topK to lowest allowed values to make responses more deterministic.
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]
  // Candidates and total token counts may differ slightly between runs due to whitespace tokens.
  let tokenCountAccuracy = 1

  let storage: Storage
  let userID1: String

  init() async throws {
    userID1 = try await TestHelpers.getUserID()
    storage = Storage.storage()
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContent(_ config: InstanceConfig) async throws {
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Where is Google headquarters located? Answer with the city name only."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Mountain View")

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount == 13)
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 3, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.totalTokenCount.isEqual(to: 16, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    #expect(usageMetadata.candidatesTokensDetails.count == 1)
    let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
    #expect(candidatesTokensDetails.modality == .text)
    #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
  }

  @Test(
    "Generate an enum and provide a system instruction",
    arguments: [
      InstanceConfig.vertexV1,
      InstanceConfig.vertexV1Staging,
      InstanceConfig.vertexV1Beta,
      InstanceConfig.vertexV1BetaStaging,
      /* System instructions are not supported on the v1 Developer API. */
      InstanceConfig.developerV1Beta,
    ]
  )
  func generateContentEnum(_ config: InstanceConfig) async throws {
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "text/x.enum", // Not supported on the v1 Developer API
        responseSchema: .enumeration(values: ["Red", "Green", "Blue"])
      ),
      safetySettings: safetySettings,
      tools: [], // Not supported on the v1 Developer API
      toolConfig: .init(functionCallingConfig: .none()), // Not supported on the v1 Developer API
      systemInstruction: ModelContent(role: "system", parts: "Always pick blue.")
    )
    let prompt = "What is your favourite colour?"

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Blue")

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount.isEqual(to: 15, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 1, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.totalTokenCount
      == usageMetadata.promptTokenCount + usageMetadata.candidatesTokenCount)
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    #expect(usageMetadata.candidatesTokensDetails.count == 1)
    let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
    #expect(candidatesTokensDetails.modality == .text)
    #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
  }

  @Test(arguments: [
    InstanceConfig.vertexV1Beta,
    InstanceConfig.developerV1Beta,
  ])
  func generateImage(_ config: InstanceConfig) async throws {
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.text, .image]
    )
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashExperimental,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate an image of a cute cartoon kitten playing with a ball of yarn."

    var response: GenerateContentResponse?
    try await withKnownIssue(
      "Backend may fail with a 503 - Service Unavailable error when overloaded",
      isIntermittent: true
    ) {
      response = try await model.generateContent(prompt)
    } matching: { issue in
      (issue.error as? BackendError).map { $0.httpResponseCode == 503 } ?? false
    }

    guard let response else { return }
    let candidate = try #require(response.candidates.first)
    let inlineDataPart = try #require(candidate.content.parts
      .first { $0 is InlineDataPart } as? InlineDataPart)
    #expect(inlineDataPart.mimeType == "image/png")
    #expect(inlineDataPart.data.count > 0)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: inlineDataPart.data))
      // Gemini 2.0 Flash Experimental returns images sized to fit within a 1024x1024 pixel box but
      // dimensions may vary depending on the aspect ratio.
      #expect(uiImage.size.width <= 1024)
      #expect(uiImage.size.width >= 500)
      #expect(uiImage.size.height <= 1024)
      #expect(uiImage.size.height >= 500)
    #endif // canImport(UIKit)
  }

  // MARK: Streaming Tests

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContentStream(_ config: InstanceConfig) async throws {
    let expectedText = """
    1. Mercury
    2. Venus
    3. Earth
    4. Mars
    5. Jupiter
    6. Saturn
    7. Uranus
    8. Neptune
    """
    let prompt = """
    What are the names of the planets in the solar system, ordered from closest to furthest from
    the sun? Answer with a Markdown numbered list of the names and no other text.
    """
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let chat = model.startChat()

    let stream = try chat.sendMessageStream(prompt)
    var textValues = [String]()
    for try await value in stream {
      try textValues.append(#require(value.text))
    }

    let userHistory = try #require(chat.history.first)
    #expect(userHistory.role == "user")
    #expect(userHistory.parts.count == 1)
    let promptTextPart = try #require(userHistory.parts.first as? TextPart)
    #expect(promptTextPart.text == prompt)
    let modelHistory = try #require(chat.history.last)
    #expect(modelHistory.role == "model")
    #expect(modelHistory.parts.count == 1)
    let modelTextPart = try #require(modelHistory.parts.first as? TextPart)
    let modelText = modelTextPart.text.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(modelText == expectedText)
    #expect(textValues.count > 1)
    let text = textValues.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == expectedText)
  }

  // MARK: - App Check Tests

  @Test(arguments: [
    InstanceConfig.vertexV1AppCheckNotConfigured,
    InstanceConfig.vertexV1BetaAppCheckNotConfigured,
    // App Check is not supported on the Generative Language Developer API endpoint since it
    // bypasses the Vertex AI in Firebase proxy.
  ])
  func generateContent_appCheckNotConfigured_shouldFail(_ config: InstanceConfig) async throws {
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2Flash
    )
    let prompt = "Where is Google headquarters located? Answer with the city name only."

    try await #require {
      _ = try await model.generateContent(prompt)
    } throws: {
      guard let error = $0 as? GenerateContentError else {
        Issue.record("Expected a \(GenerateContentError.self); got \($0.self).")
        return false
      }
      guard case let .internalError(underlyingError) = error else {
        Issue.record("Expected a GenerateContentError.internalError(...); got \(error.self).")
        return false
      }

      return String(describing: underlyingError).contains("Firebase App Check token is invalid")
    }
  }
}
