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

import FirebaseAILogic
import FirebaseAITestApp
import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import Testing

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

@testable import struct FirebaseAILogic.BackendError

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

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.vertexAI_v1beta_global_appCheckLimitedUse, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3_1_FlashLitePreview),
    (InstanceConfig.googleAI_v1beta_appCheckLimitedUse, ModelNames.gemini3_1_FlashLitePreview),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemma4_31B),
    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemma4_31B),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemma4_31B),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemma4_31B),
  ])
  func generateContent(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
    )
    let prompt = "Where is Google headquarters located? Answer with the city name only."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Mountain View")

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount.isEqual(to: 13, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    // No thoughts in Flash Lite.
    if !modelName.contains("flash-lite") {
      #expect(usageMetadata.thoughtsTokenCount > 0)
    }
    // The `candidatesTokensDetails` field is not included when using Gemini 3 or Gemma models.
    if modelName.hasPrefix("gemini-3") || modelName.hasPrefix("gemma") {
      #expect(usageMetadata.candidatesTokenCount == 2)
      #expect(usageMetadata.candidatesTokensDetails.isEmpty)
    } else {
      #expect(usageMetadata.candidatesTokenCount.isEqual(to: 3, accuracy: tokenCountAccuracy))
      #expect(usageMetadata.candidatesTokensDetails.count == 1)
      let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
      #expect(candidatesTokensDetails.modality == .text)
      #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
    }
    #expect(usageMetadata.cachedContentTokenCount == 0)
    #expect(usageMetadata.cacheTokensDetails.isEmpty)
    #expect(usageMetadata.totalTokenCount == (usageMetadata.promptTokenCount +
        usageMetadata.candidatesTokenCount +
        usageMetadata.thoughtsTokenCount))
  }

  @Test(
    "Generate an enum and provide a system instruction",
    arguments: InstanceConfig.allConfigs
  )
  func generateContentEnum(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "text/x.enum",
        responseSchema: .enumeration(values: ["Red", "Green", "Blue"])
      ),
      safetySettings: safetySettings,
      tools: [],
      toolConfig: .init(functionCallingConfig: .none()),
      systemInstruction: ModelContent(role: "system", parts: "Always pick blue.")
    )
    let prompt = "What is your favourite colour?"

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Blue")

    let usageMetadata = try #require(response.usageMetadata)
    if case .googleAI = config.apiConfig.service {
      #expect(usageMetadata.promptTokenCount.isEqual(to: 11, accuracy: tokenCountAccuracy))
      #expect(usageMetadata.candidatesTokensDetails.count == 0)
    } else {
      #expect(usageMetadata.promptTokenCount.isEqual(to: 15, accuracy: tokenCountAccuracy))
      #expect(usageMetadata.candidatesTokensDetails.count == 1)
      let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
      #expect(candidatesTokensDetails.modality == .text)
      #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
    }
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 1, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.thoughtsTokenCount == 0)
    #expect(usageMetadata.totalTokenCount
      == usageMetadata.promptTokenCount + usageMetadata.candidatesTokenCount)
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
  }

  @Test(
    arguments: [
      (.vertexAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 0)),
      (.vertexAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 24576)),
      (.vertexAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(
        thinkingBudget: 24576, includeThoughts: true
      )),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: 128)),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: 32768)),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Pro, ThinkingConfig(
        thinkingBudget: 32768, includeThoughts: true
      )),
      (.googleAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 0)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 24576)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(
        thinkingBudget: 24576, includeThoughts: true
      )),
      (.googleAI_v1beta, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: 128)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: 32768)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Pro, ThinkingConfig(
        thinkingBudget: 32768, includeThoughts: true
      )),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingLevel: .minimal)
      ),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingLevel: .low)
      ),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingLevel: .medium)
      ),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingLevel: .high)
      ),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingBudget: 0)
      ),
      (
        .googleAI_v1beta,
        ModelNames.gemini3_1_FlashLitePreview,
        ThinkingConfig(thinkingBudget: 32768)
      ),
      (.googleAI_v1beta, ModelNames.gemini3_1_FlashLitePreview, ThinkingConfig(
        thinkingBudget: 32768, includeThoughts: true
      )),
      // Note: The following configs are commented out for easy one-off manual testing.
//      (.googleAI_v1beta_freeTier, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 0)),
//      (
//        .googleAI_v1beta_freeTier,
//        ModelNames.gemini2_5_Flash,
//        ThinkingConfig(thinkingBudget: 24576)
//      ),
//      (.googleAI_v1beta_freeTier, ModelNames.gemini2_5_Flash, ThinkingConfig(
//        thinkingBudget: 24576, includeThoughts: true
//      )),
      // (.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2_5_Flash, ThinkingConfig(
      //   thinkingBudget: 0
      // )),
      // (.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2_5_Flash, ThinkingConfig(
      //   thinkingBudget: 24576
      // )),
      // (.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2_5_Flash, ThinkingConfig(
      //   thinkingBudget: 24576, includeThoughts: true
      // )),
    ] as [(InstanceConfig, String, ThinkingConfig)]
  )
  func generateContentThinking(_ config: InstanceConfig, modelName: String,
                               thinkingConfig: ThinkingConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        topP: 0.0,
        topK: 1,
        thinkingConfig: thinkingConfig
      ),
      safetySettings: safetySettings
    )
    let chat = model.startChat()
    let prompt = "Where is Google headquarters located? Answer with the city name only."

    let response = try await chat.sendMessage(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Mountain View")

    let candidate = try #require(response.candidates.first)
    let thoughtParts = candidate.content.parts.compactMap { $0.isThought ? $0 : nil }
    let thoughtSignature = candidate.content.internalParts.first?.thoughtSignature
    #expect(thoughtSignature != nil || thoughtParts
      .isEmpty != (thinkingConfig.includeThoughts ?? false))

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount.isEqual(to: 13, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    if let thinkingBudget = thinkingConfig.thinkingBudget, thinkingBudget > 0 {
      #expect(usageMetadata.thoughtsTokenCount > 0)
      #expect(usageMetadata.thoughtsTokenCount <= thinkingBudget)
    } else if let thinkingLevel = thinkingConfig.thinkingLevel {
      // For gemini3FlashPreview, repeated runs show that for any of the four
      // levels, 64 or 68 may be returned.
      let minThoughtTokens = 64
      switch thinkingLevel {
      case .minimal:
        #expect(usageMetadata.thoughtsTokenCount == 0)
      case .low, .medium, .high:
        #expect(usageMetadata.thoughtsTokenCount >= minThoughtTokens)
      default:
        Issue.record("Unhandled ThinkingLevel: \(thinkingLevel)")
      }
    } else {
      #expect(usageMetadata.thoughtsTokenCount == 0)
    }
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 3, accuracy: tokenCountAccuracy))
    // The `candidatesTokensDetails` field is erroneously omitted when using the Google AI (Gemini
    // Developer API) backend.
    if case .googleAI = config.apiConfig.service {
      #expect(usageMetadata.candidatesTokensDetails.isEmpty)
    } else {
      #expect(usageMetadata.candidatesTokensDetails.count == 1)
      let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
      #expect(candidatesTokensDetails.modality == .text)
      #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
    }
    #expect(usageMetadata.cachedContentTokenCount == 0)
    #expect(usageMetadata.cacheTokensDetails.isEmpty)
    #expect(usageMetadata.totalTokenCount > 0)
    #expect(usageMetadata.totalTokenCount == (
      usageMetadata.promptTokenCount
        + usageMetadata.thoughtsTokenCount
        + usageMetadata.candidatesTokenCount
    ))
  }

  @Test(
    arguments: [
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: -1)),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Flash, ThinkingConfig(
        thinkingBudget: -1, includeThoughts: true
      )),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: -1)),
      (.vertexAI_v1beta_global, ModelNames.gemini2_5_Pro, ThinkingConfig(
        thinkingBudget: -1, includeThoughts: true
      )),
      (.googleAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: -1)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Flash, ThinkingConfig(
        thinkingBudget: -1, includeThoughts: true
      )),
      (.googleAI_v1beta, ModelNames.gemini2_5_Pro, ThinkingConfig(thinkingBudget: -1)),
      (.googleAI_v1beta, ModelNames.gemini2_5_Pro, ThinkingConfig(
        thinkingBudget: -1, includeThoughts: true
      )),
      (.googleAI_v1beta, ModelNames.gemini3_1_FlashLitePreview, ThinkingConfig(thinkingBudget: -1)),
      (.googleAI_v1beta, ModelNames.gemini3_1_FlashLitePreview, ThinkingConfig(
        thinkingBudget: -1, includeThoughts: true
      )),
    ] as [(InstanceConfig, String, ThinkingConfig)]
  )
  func generateContentThinkingFunctionCalling(_ config: InstanceConfig, modelName: String,
                                              thinkingConfig: ThinkingConfig) async throws {
    let getTemperatureDeclaration = FunctionDeclaration(
      name: "getTemperature",
      description: "Returns the current temperature in Celsius for the specified location",
      parameters: [
        "city": .string(),
        "region": .string(description: "The province or state"),
        "country": .string(),
      ]
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        topP: 0.0,
        topK: 1,
        thinkingConfig: thinkingConfig
      ),
      safetySettings: safetySettings,
      tools: [.functionDeclarations([getTemperatureDeclaration])],
      systemInstruction: ModelContent(parts: """
      You are a weather bot that specializes in reporting outdoor temperatures in Celsius.

      Always use the `getTemperature` function to determine the current temperature in a location.

      Always respond in the format:
      - Location: City, Province/State, Country
      - Temperature: #C
      """)
    )
    let chat = model.startChat()
    let prompt = "What is the current temperature in Waterloo, Ontario, Canada?"

    let response = try await chat.sendMessage(prompt)

    #expect(response.functionCalls.count == 1)
    let temperatureFunctionCall = try #require(response.functionCalls.first)
    try #require(temperatureFunctionCall.name == getTemperatureDeclaration.name)
    #expect(temperatureFunctionCall.args == [
      "city": .string("Waterloo"),
      "region": .string("Ontario"),
      "country": .string("Canada"),
    ])
    #expect(temperatureFunctionCall.isThought == false)
    let thoughtSignature = try #require(temperatureFunctionCall.thoughtSignature)
    #expect(!thoughtSignature.isEmpty)

    let temperatureFunctionResponse = FunctionResponsePart(
      name: temperatureFunctionCall.name,
      response: [
        "temperature": .number(25),
        "units": .string("Celsius"),
      ]
    )

    let response2 = try await chat.sendMessage(temperatureFunctionResponse)

    #expect(response2.functionCalls.isEmpty)
    let finalText = try #require(response2.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(finalText.contains("Waterloo"))
    #expect(finalText.contains("25"))
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3_1_FlashImagePreview),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini3_1_FlashImagePreview),
  ])
  func generateImageWithAspectRatio(_ config: InstanceConfig, modelName: String) async throws {
    let imageConfig = ImageConfig(aspectRatio: .landscape16x9)
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.image],
      imageConfig: imageConfig
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate an image of a cute cartoon kitten playing with a ball of yarn."

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let inlineDataPart = try #require(candidate.content.parts
      .first { $0 is InlineDataPart } as? InlineDataPart)
    let inlineDataPartsViaAccessor = response.inlineDataParts
    #expect(inlineDataPartsViaAccessor.count == 1)
    let inlineDataPartViaAccessor = try #require(inlineDataPartsViaAccessor.first)
    #expect(inlineDataPart == inlineDataPartViaAccessor)
    #expect(inlineDataPart.mimeType.starts(with: "image/"))
    #expect(inlineDataPart.data.count > 0)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: inlineDataPart.data))
      // Note: Images are not exactly 16:9 but align with the documented sizes
      // (https://ai.google.dev/gemini-api/docs/image-generation#aspect_ratios_and_image_size)
      #expect(uiImage.size.width >= 1344) // Gemini 2.5 produces images slightly narrower than 16:9
      #expect(uiImage.size.width <= 1376) // Gemini 3 produces images slightly wider than 16:9
      #expect(uiImage.size.height == 768)
    #endif // canImport(UIKit)
  }

  @Test(arguments: [
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3_1_FlashImagePreview),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini3_1_FlashImagePreview),
  ])
  func generateImageWithCustomSize(_ config: InstanceConfig, modelName: String) async throws {
    let imageConfig = ImageConfig(
      // Specifying aspectRatio explicitly to ensure consistent results, as the
      // default behavior seems to be random aspect ratio despite documentation
      // stating 1:1 is the default.
      aspectRatio: .square1x1,
      imageSize: .size2K
    )
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.image],
      imageConfig: imageConfig
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate an image of a cute cartoon puppy catching a ball in the air."

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let inlineDataPart = try #require(candidate.content.parts
      .first { $0 is InlineDataPart } as? InlineDataPart)
    let inlineDataPartsViaAccessor = response.inlineDataParts
    #expect(inlineDataPartsViaAccessor.count == 1)
    let inlineDataPartViaAccessor = try #require(inlineDataPartsViaAccessor.first)
    #expect(inlineDataPart == inlineDataPartViaAccessor)
    #expect(inlineDataPart.mimeType.starts(with: "image/"))
    #expect(inlineDataPart.data.count > 0)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: inlineDataPart.data))
      #expect(uiImage.size.width == 2048)
      #expect(uiImage.size.height == 2048)
    #endif // canImport(UIKit)
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3_1_FlashImagePreview),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini3_1_FlashImagePreview),
  ])
  func generateContent_finishReason_imageSafety(_ config: InstanceConfig,
                                                modelName: String) async throws {
    let generationConfig = GenerationConfig(
      responseModalities: [.image]
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
    )
    let prompt = "A graphic image of violence" // This prompt should trigger safety violation

    do {
      let response = try await model.generateContent(prompt)

      // vertexAI gemini3_1_FlashImagePreview doesn't throw.
      let candidate = try #require(response.candidates.first)
      #expect(candidate.finishReason == .stop)
    } catch {
      guard let error = error as? GenerateContentError else {
        Issue.record("Expected a \(GenerateContentError.self); got \(error.self).")
        throw error
      }
      guard case let .responseStoppedEarly(reason, response) = error else {
        Issue.record("Expected a GenerateContentError.responseStoppedEarly; got \(error.self).")
        throw error
      }
      #expect(reason == .imageSafety || reason == .noImage)
      #expect(response.candidates.first?.content.parts.isEmpty == true) // Ensure no content
    }
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImage),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2_5_FlashImage)
  ])
  func generateImage(_ config: InstanceConfig, modelName: String) async throws {
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.text, .image]
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate an image of a cute cartoon kitten playing with a ball of yarn."

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let inlineDataPart = try #require(candidate.content.parts
      .first { $0 is InlineDataPart } as? InlineDataPart)
    let inlineDataPartsViaAccessor = response.inlineDataParts
    #expect(inlineDataPartsViaAccessor.count == 1)
    let inlineDataPartViaAccessor = try #require(inlineDataPartsViaAccessor.first)
    #expect(inlineDataPart == inlineDataPartViaAccessor)
    #expect(inlineDataPart.mimeType.starts(with: "image/"))
    #expect(inlineDataPart.data.count > 0)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: inlineDataPart.data))
      #expect(uiImage.size.width > 0)
      #expect(uiImage.size.height > 0)
    #endif // canImport(UIKit)
  }

  @Test(
    "generateContent with Google Search returns grounding metadata",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withGoogleSearch_succeeds(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      tools: [.googleSearch()]
    )
    let prompt = "What is the weather in Toronto today?"

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let groundingMetadata = try #require(candidate.groundingMetadata)
    let searchEntrypoint = try #require(groundingMetadata.searchEntryPoint)

    #expect(!groundingMetadata.webSearchQueries.isEmpty)
    #expect(!searchEntrypoint.renderedContent.isEmpty)
    #expect(!groundingMetadata.groundingChunks.isEmpty)
    #expect(!groundingMetadata.groundingSupports.isEmpty)

    for chunk in groundingMetadata.groundingChunks {
      #expect(chunk.web != nil)
    }

    for support in groundingMetadata.groundingSupports {
      let segment = support.segment
      #expect(segment.endIndex > segment.startIndex)
      #expect(!segment.text.isEmpty)
      #expect(!support.groundingChunkIndices.isEmpty)

      // Ensure indices point to valid chunks
      for index in support.groundingChunkIndices {
        #expect(index < groundingMetadata.groundingChunks.count)
      }
    }
  }

  @Test(
    "generateContent with URL Context",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withURLContext_succeeds(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      tools: [.urlContext()]
    )
    let url = "https://developers.googleblog.com/en/introducing-gemma-3-270m/"
    let prompt = "Write a one paragraph summary of this blog post: \(url)"
    let response = try await model.generateContent(prompt)
    let candidate = try #require(response.candidates.first)
    let urlContextMetadata = try #require(candidate.urlContextMetadata)
    #expect(urlContextMetadata.urlMetadata.count == 1)
    let urlMetadata = try #require(urlContextMetadata.urlMetadata.first)
    #expect(urlMetadata.retrievalStatus == .success)
    let retrievedURL = try #require(urlMetadata.retrievedURL)
    #expect(retrievedURL == URL(string: url))
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContent_codeExecution_succeeds(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      tools: [.codeExecution()]
    )
    let prompt = """
    What is the sum of the first 5 prime numbers? Generate and run code for the calculation.
    """

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let executableCodeParts = candidate.content.parts.compactMap { $0 as? ExecutableCodePart }
    #expect(executableCodeParts.count == 1)
    let executableCodePart = try #require(executableCodeParts.first)
    #expect(executableCodePart.language == .python)
    #expect(executableCodePart.code.contains("sum"))
    let codeExecutionResults = candidate.content.parts.compactMap { $0 as? CodeExecutionResultPart }
    #expect(codeExecutionResults.count == 1)
    let codeExecutionResultPart = try #require(codeExecutionResults.first)
    #expect(codeExecutionResultPart.outcome == .ok)
    let output = try #require(codeExecutionResultPart.output)
    #expect(output.contains("28")) // 2 + 3 + 5 + 7 + 11 = 28
    let text = try #require(response.text)
    #expect(text.contains("28"))
  }

  // MARK: Streaming Tests

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini3_1_FlashLitePreview),
    (
      InstanceConfig.vertexAI_v1beta_global_appCheckLimitedUse,
      ModelNames.gemini3_1_FlashLitePreview
    ),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta_appCheckLimitedUse, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemma4_31B),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.vertexAI_v1beta_staging, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemma4_31B),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2_5_FlashLite),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemma4_31B),
//    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2_5_FlashLite),
//    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemma4_31B),
  ])
  func generateContentStream(_ config: InstanceConfig, modelName: String) async throws {
    let expectedResponse = [
      "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune",
    ]
    let prompt = """
    Generate a JSON array of strings. The array must contain the names of the planets in Earth's \
    solar system, ordered from closest to furthest from the Sun.

    Constraints:
    - Output MUST be only the JSON array.
    - Do NOT include any introductory or explanatory text.
    - Do NOT wrap the JSON in Markdown code blocks (e.g., ```json ... ``` or ``` ... ```).
    - The response must start with '[' and end with ']'.
    """
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let chat = model.startChat()

    let stream = try chat.sendMessageStream(prompt)
    var textValues = [String]()
    for try await value in stream {
      if let text = value.text {
        textValues.append(text)
      } else if let finishReason = value.candidates.first?.finishReason {
        #expect(finishReason == .stop)
      } else if let thoughtSummary = value.thoughtSummary {
        #expect(!thoughtSummary.isEmpty)
      } else {
        Issue.record("Expected a candidate with a `TextPart` or a `finishReason`; got \(value).")
      }
    }

    // Tests the text derived from streaming directly
    let modelJSONData = try #require(textValues.joined().data(using: .utf8))
    let response = try JSONDecoder().decode([String].self, from: modelJSONData)
    #expect(response == expectedResponse)

    let userHistory = try #require(chat.history.first)
    #expect(userHistory.role == "user")
    #expect(userHistory.parts.count == 1)
    let promptTextPart = try #require(userHistory.parts.first as? TextPart)
    #expect(promptTextPart.text == prompt)
    let modelHistory = try #require(chat.history.last)
    #expect(modelHistory.role == "model")
    let textParts = modelHistory.parts.compactMap { $0 as? TextPart }.filter {
      !$0.isThoughtOrRelated()
    }
    if textParts.count > 1 {
      Issue.record("Found multiple text parts: \(textParts)")
    }
    #expect(
      textParts.count == 1,
      "The model should reply with exactly one (non thought) text response."
    )

    // Tests the text derived from the chat history
    let historyTextPart = try #require(textParts.first)
    let historyModelJSONData = try #require(historyTextPart.text.data(using: .utf8))
    let historyResponse = try JSONDecoder().decode([String].self, from: historyModelJSONData)
    #expect(historyResponse == expectedResponse)
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImage),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImage),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2_5_FlashImage)
  ])
  func generateImageStreaming(_ config: InstanceConfig, modelName: String) async throws {
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.text, .image]
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate an image of a cute cartoon kitten playing with a ball of yarn"

    let stream = try model.generateContentStream(prompt)

    var inlineDataParts = [InlineDataPart]()
    for try await response in stream {
      let candidate = try #require(response.candidates.first)
      let inlineDataPart = candidate.content.parts.first { $0 is InlineDataPart } as? InlineDataPart
      if let inlineDataPart {
        inlineDataParts.append(inlineDataPart)
        let inlineDataPartsViaAccessor = response.inlineDataParts
        #expect(inlineDataPartsViaAccessor.count == 1)
        #expect(inlineDataPartsViaAccessor == response.inlineDataParts)
      }
      let textPart = candidate.content.parts.first { $0 is TextPart } as? TextPart
      #expect(
        inlineDataPart != nil || textPart != nil || candidate.finishReason == .stop,
        "No text or image found in the candidate"
      )
    }

    #expect(inlineDataParts.count == 1)
    let inlineDataPart = try #require(inlineDataParts.first)
    #expect(inlineDataPart.mimeType.starts(with: "image/"))
    #expect(inlineDataPart.data.count > 0)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: inlineDataPart.data))
      #expect(uiImage.size.width > 0)
      #expect(uiImage.size.height > 0)
    #endif // canImport(UIKit)
  }

  // MARK: - App Check Tests

  @Test(arguments: InstanceConfig.appCheckNotConfiguredConfigs)
  func generateContent_appCheckNotConfigured_shouldFail(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash
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

extension TextPart {
  /// Whether this text part is a thought or thought related text part.
  ///
  /// In such cases, it can be ignored for display and testing purposes.
  ///
  /// We use this over just a standard `isThought` check so that we can
  /// catch cases where the gemini model sends a text part with empty text that just
  /// acts as the last thought of the model.
  func isThoughtOrRelated() -> Bool {
    return isThought || (thoughtSignature != nil && text.isEmpty)
  }
}
