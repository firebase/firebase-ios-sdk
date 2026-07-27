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

@testable import FirebaseAILogic
import Foundation
import XCTest
internal import InternalGoogleGenAI

final class PayloadConvertibleTests: XCTestCase {
  // MARK: - Schema and DataType

  func testSchemaConversion() throws {
    let schema = Schema.object(
      properties: [
        "name": .string(),
        "age": .integer(description: "Age in years"),
      ],
      optionalProperties: ["age"],
      description: "Person schema"
    )

    let payload = try schema.toRequestPayload()
    XCTAssertEqual(payload.type, .object)
    XCTAssertEqual(payload.description, "Person schema")
    XCTAssertEqual(payload.properties?["name"]?.type, .string)
    XCTAssertEqual(payload.properties?["age"]?.type, .integer)
    XCTAssertEqual(payload.properties?["age"]?.description, "Age in years")
    XCTAssertEqual(payload.required, ["name"])
  }

  // MARK: - Tool and ToolConfig

  func testToolAndToolConfigConversion() throws {
    let funcDecl = FunctionDeclaration(
      name: "getWeather",
      description: "Get current weather",
      parameters: ["location": .string(description: "City name")]
    )
    let tool = Tool(functionDeclarations: [funcDecl])

    let toolPayload = try tool.toRequestPayload()
    XCTAssertEqual(toolPayload.functionDeclarations?.count, 1)
    XCTAssertEqual(toolPayload.functionDeclarations?.first?.name, "getWeather")
    XCTAssertEqual(toolPayload.functionDeclarations?.first?.description, "Get current weather")

    let toolConfig = ToolConfig(functionCallingConfig: .auto())
    let toolConfigPayload = try toolConfig.toRequestPayload()
    XCTAssertEqual(toolConfigPayload.functionCallingConfig?.mode, .auto)
  }

  // MARK: - GenerationConfig

  func testGenerationConfigConversion() throws {
    let thinkingConfig = ThinkingConfig(thinkingLevel: .high)
    let imageConfig = ImageConfig(aspectRatio: .square1x1, imageSize: .size1K)
    let config = GenerationConfig(
      temperature: 0.7,
      topP: 0.9,
      topK: 40,
      candidateCount: 1,
      maxOutputTokens: 1024,
      stopSequences: ["END"],
      responseMIMEType: "application/json",
      thinkingConfig: thinkingConfig,
      imageConfig: imageConfig
    )

    let payload = try config.toRequestPayload()
    XCTAssertEqual(payload.temperature ?? 0, 0.7, accuracy: 0.0001)
    XCTAssertEqual(payload.topP ?? 0, 0.9, accuracy: 0.0001)
    XCTAssertEqual(payload.topK, 40)
    XCTAssertEqual(payload.candidateCount, 1)
    XCTAssertEqual(payload.maxOutputTokens, 1024)
    XCTAssertEqual(payload.stopSequences, ["END"])
    XCTAssertEqual(payload.responseMimeType, "application/json")
    XCTAssertEqual(payload.thinkingConfig?.thinkingLevel, .high)
    XCTAssertEqual(payload.imageConfig?.aspectRatio, ImageConfig.AspectRatio.square1x1.rawValue)
    XCTAssertEqual(payload.imageConfig?.imageSize, ImageConfig.ImageSize.size1K.rawValue)
  }

  // MARK: - Safety Settings and Ratings

  func testSafetySettingAndRatingConversion() throws {
    let setting = SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove)
    let settingPayload = try setting.toRequestPayload()
    XCTAssertEqual(settingPayload.category, .hateSpeech)
    XCTAssertEqual(settingPayload.threshold, .blockLowAndAbove)

    let ratingPayload = GenAITypes.SafetyRating(
      category: .harassment,
      probability: .medium,
      blocked: true,
      probabilityScore: 0.8,
      severity: .high,
      severityScore: 0.9
    )

    let rating = try SafetyRating(ratingPayload)
    XCTAssertEqual(rating.category, HarmCategory.harassment)
    XCTAssertEqual(rating.probability, SafetyRating.HarmProbability.medium)
    XCTAssertEqual(rating.blocked, true)
    XCTAssertEqual(rating.probabilityScore, 0.8)
    XCTAssertEqual(rating.severity, SafetyRating.HarmSeverity.high)
    XCTAssertEqual(rating.severityScore, 0.9)
  }

  // MARK: - Parts Conversion

  func testPartConversions() throws {
    let textPart = TextPart("Hello")
    let textPayload = try textPart.toRequestPayload()
    if case let .text(text) = textPayload.data {
      XCTAssertEqual(text, "Hello")
    } else {
      XCTFail("Expected .text payload")
    }

    let inlinePart = InlineDataPart(data: Data([0x01, 0x02]), mimeType: "image/png")
    let inlinePayload = try inlinePart.toRequestPayload()
    if case let .inlineData(blob) = inlinePayload.data {
      XCTAssertEqual(blob.data, Data([0x01, 0x02]))
      XCTAssertEqual(blob.mimeType, "image/png")
    } else {
      XCTFail("Expected .inlineData payload")
    }

    let filePart = FileDataPart(uri: "gs://bucket/file.pdf", mimeType: "application/pdf")
    let filePayload = try filePart.toRequestPayload()
    if case let .fileData(fileData) = filePayload.data {
      XCTAssertEqual(fileData.fileUri, "gs://bucket/file.pdf")
      XCTAssertEqual(fileData.mimeType, "application/pdf")
    } else {
      XCTFail("Expected .fileData payload")
    }

    let funcCallPart = FunctionCallPart(name: "testFunc", args: ["key": .string("val")])
    let funcCallPayload = try funcCallPart.toRequestPayload()
    if case let .functionCall(call) = funcCallPayload.data {
      XCTAssertEqual(call.name, "testFunc")
      XCTAssertEqual(call.args?["key"], .string("val"))
    } else {
      XCTFail("Expected .functionCall payload")
    }

    let funcRespPart = FunctionResponsePart(name: "testFunc", response: ["result": .string("ok")])
    let funcRespPayload = try funcRespPart.toRequestPayload()
    if case let .functionResponse(resp) = funcRespPayload.data {
      XCTAssertEqual(resp.name, "testFunc")
      XCTAssertEqual(resp.response?["result"], .string("ok"))
    } else {
      XCTFail("Expected .functionResponse payload")
    }
  }

  // MARK: - ModelContent

  func testModelContentConversion() throws {
    let content = ModelContent(role: "user", parts: [TextPart("Hello world")])
    let payload = try content.toRequestPayload()
    XCTAssertEqual(payload.role, "user")
    XCTAssertEqual(payload.parts?.count, 1)

    let decodedContent = try ModelContent(payload)
    XCTAssertEqual(decodedContent.role, "user")
    XCTAssertEqual(decodedContent.parts.count, 1)
    if let textPart = decodedContent.parts.first as? TextPart {
      XCTAssertEqual(textPart.text, "Hello world")
    } else {
      XCTFail("Expected TextPart in decoded ModelContent")
    }
  }

  // MARK: - GenerateContentRequest

  func testGenerateContentRequestConversion() throws {
    let request = FirebaseAILogic.GenerateContentRequest(
      model: "gemini-1.5-flash",
      contents: [ModelContent(role: "user", parts: [TextPart("Tell me a joke")])],
      generationConfig: GenerationConfig(temperature: 0.5),
      safetySettings: nil,
      tools: nil,
      toolConfig: nil,
      systemInstruction: nil,
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta),
      apiMethod: .generateContent,
      options: RequestOptions()
    )

    let payload = try request.toRequestPayload()
    XCTAssertEqual(payload.contents?.count, 1)
    XCTAssertEqual(payload.contents?.first?.role, "user")
    XCTAssertEqual(payload.generationConfig?.temperature, 0.5)
  }

  // MARK: - GenerateContentResponse

  func testGenerateContentResponseConversion() throws {
    let responsePayload = GenAITypes.GenerateContentResponse(
      candidates: [
        GenAITypes.Candidate(
          content: GenAITypes.Content(
            parts: [GenAITypes.Part(data: .text("Here is a joke"))],
            role: "model"
          ),
          finishReason: .stop,
          safetyRatings: [
            GenAITypes.SafetyRating(
              category: .hateSpeech,
              probability: .negligible
            ),
          ],
          citationMetadata: GenAITypes.CitationMetadata(
            citationSources: [
              GenAITypes.Citation(
                startIndex: 0,
                endIndex: 10,
                uri: "https://example.com"
              ),
            ]
          )
        ),
      ],
      promptFeedback: GenAITypes.PromptFeedback(
        blockReason: .safety,
        blockReasonMessage: "Blocked for safety"
      ),
      usageMetadata: GenAITypes.UsageMetadata(
        promptTokenCount: 10,
        candidatesTokenCount: 20,
        totalTokenCount: 30
      ),
      modelVersion: "gemini-1.5-flash-001",
      responseId: "resp-123"
    )

    let response = try FirebaseAILogic.GenerateContentResponse(responsePayload)
    XCTAssertEqual(response.responseID, "resp-123")
    XCTAssertEqual(response.modelVersion, "gemini-1.5-flash-001")
    XCTAssertEqual(response.candidates.count, 1)
    XCTAssertEqual(response.text, "Here is a joke")
    XCTAssertEqual(response.candidates.first?.finishReason, .stop)
    XCTAssertEqual(response.promptFeedback?.blockReason, .safety)
    XCTAssertEqual(response.usageMetadata?.totalTokenCount, 30)
  }
}
