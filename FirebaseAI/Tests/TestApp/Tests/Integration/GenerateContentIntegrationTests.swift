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
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2FlashLite),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2FlashLite),
    (InstanceConfig.vertexAI_v1beta_global_appCheckLimitedUse, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta_appCheckLimitedUse, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemma3_4B),
    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemma3_4B),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemma3_4B),
    // (InstanceConfig.vertexAI_v1beta_staging, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemma3_4B),
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
    #expect(usageMetadata.thoughtsTokenCount == 0)
    // The fields `candidatesTokenCount` and `candidatesTokensDetails` are not included when using
    // Gemma models.
    if modelName.hasPrefix("gemma") {
      #expect(usageMetadata.candidatesTokenCount == 0)
      #expect(usageMetadata.candidatesTokensDetails.isEmpty)
    } else {
      #expect(usageMetadata.candidatesTokenCount.isEqual(to: 3, accuracy: tokenCountAccuracy))
      #expect(usageMetadata.candidatesTokensDetails.count == 1)
      let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
      #expect(candidatesTokensDetails.modality == .text)
      #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
    }
    #expect(usageMetadata.totalTokenCount > 0)
    #expect(usageMetadata.totalTokenCount ==
      (usageMetadata.promptTokenCount + usageMetadata.candidatesTokenCount))
  }

  @Test(
    "Generate an enum and provide a system instruction",
    arguments: InstanceConfig.allConfigs
  )
  func generateContentEnum(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
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
    #expect(usageMetadata.promptTokenCount.isEqual(to: 15, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 1, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.thoughtsTokenCount == 0)
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
      (.googleAI_v1beta_freeTier, ModelNames.gemini2_5_Flash, ThinkingConfig(thinkingBudget: 0)),
      (
        .googleAI_v1beta_freeTier,
        ModelNames.gemini2_5_Flash,
        ThinkingConfig(thinkingBudget: 24576)
      ),
      (.googleAI_v1beta_freeTier, ModelNames.gemini2_5_Flash, ThinkingConfig(
        thinkingBudget: 24576, includeThoughts: true
      )),
      // Note: The following configs are commented out for easy one-off manual testing.
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
    #expect(thoughtParts.isEmpty != (thinkingConfig.includeThoughts ?? false))

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount.isEqual(to: 13, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    if let thinkingBudget = thinkingConfig.thinkingBudget, thinkingBudget > 0 {
      #expect(usageMetadata.thoughtsTokenCount > 0)
      #expect(usageMetadata.thoughtsTokenCount <= thinkingBudget)
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
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImagePreview),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImagePreview),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2FlashPreviewImageGeneration)
    // (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2FlashPreviewImageGeneration),
    // (
    //  InstanceConfig.googleAI_v1beta_freeTier_bypassProxy,
    //  ModelNames.gemini2FlashPreviewImageGeneration
    // ),
  ])
  func generateImage(_ config: InstanceConfig, modelName: String) async throws {
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.text, .image]
    )
    let safetySettings = safetySettings.filter {
      // HARM_CATEGORY_CIVIC_INTEGRITY is deprecated in Vertex AI but only rejected when using the
      // 'gemini-2.0-flash-preview-image-generation' model.
      $0.harmCategory != .civicIntegrity
    }
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
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
    let inlineDataPartsViaAccessor = response.inlineDataParts
    #expect(inlineDataPartsViaAccessor.count == 1)
    let inlineDataPartViaAccessor = try #require(inlineDataPartsViaAccessor.first)
    #expect(inlineDataPart == inlineDataPartViaAccessor)
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

  @Test(
    "generateContent with Google Search returns grounding metadata",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withGoogleSearch_succeeds(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2Flash,
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

    // TODO(#15385): Remove `withKnownIssue` when the URL Context tool works consistently using the
    // Gemini Developer API.
    try await withKnownIssue(isIntermittent: true) {
      let response = try await model.generateContent(prompt)

      let candidate = try #require(response.candidates.first)
      let urlContextMetadata = try #require(candidate.urlContextMetadata)
      #expect(urlContextMetadata.urlMetadata.count == 1)
      let urlMetadata = try #require(urlContextMetadata.urlMetadata.first)
      let retrievedURL = try #require(urlMetadata.retrievedURL)
      #expect(retrievedURL == URL(string: url))
      #expect(urlMetadata.retrievalStatus == .success)
    } when: {
      // This issue only impacts the Gemini Developer API (Google AI), Vertex AI is unaffected.
      if case .googleAI = config.apiConfig.service {
        return true
      }
      return false
    }
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
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2FlashLite),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2FlashLite),
    (InstanceConfig.vertexAI_v1beta_global_appCheckLimitedUse, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta_appCheckLimitedUse, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemma3_4B),
    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2FlashLite),
    (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemma3_4B),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.vertexAI_v1beta_staging, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemma3_4B),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemini2FlashLite),
    // (InstanceConfig.googleAI_v1beta_freeTier_bypassProxy, ModelNames.gemma3_4B),
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
      } else {
        Issue.record("Expected a candidate with a `TextPart` or a `finishReason`; got \(value).")
      }
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
    let modelJSONData = try #require(modelTextPart.text.data(using: .utf8))
    let response = try JSONDecoder().decode([String].self, from: modelJSONData)
    #expect(response == expectedResponse)
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.vertexAI_v1beta_global, ModelNames.gemini2_5_FlashImagePreview),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2FlashPreviewImageGeneration),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashImagePreview),
    // Note: The following configs are commented out for easy one-off manual testing.
    // (InstanceConfig.googleAI_v1beta_staging, ModelNames.gemini2FlashPreviewImageGeneration)
    // (InstanceConfig.googleAI_v1beta_freeTier, ModelNames.gemini2FlashPreviewImageGeneration),
    // (
    //  InstanceConfig.googleAI_v1beta_freeTier_bypassProxy,
    //  ModelNames.gemini2FlashPreviewImageGeneration
    // ),
  ])
  func generateImageStreaming(_ config: InstanceConfig, modelName: String) async throws {
    let generationConfig = GenerationConfig(
      temperature: 0.0,
      topP: 0.0,
      topK: 1,
      responseModalities: [.text, .image]
    )
    let safetySettings = safetySettings.filter {
      // HARM_CATEGORY_CIVIC_INTEGRITY is deprecated in Vertex AI but only rejected when using the
      // 'gemini-2.0-flash-preview-image-generation' model.
      $0.harmCategory != .civicIntegrity
    }
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

  // MARK: - App Check Tests

  @Test(arguments: InstanceConfig.appCheckNotConfiguredConfigs)
  func generateContent_appCheckNotConfigured_shouldFail(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
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
