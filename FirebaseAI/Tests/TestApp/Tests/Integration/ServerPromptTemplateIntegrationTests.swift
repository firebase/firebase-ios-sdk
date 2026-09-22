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

import CoreLocation

import FirebaseAILogic
import Testing
#if canImport(UIKit)
  import UIKit
#endif

struct ServerPromptTemplateIntegrationTests {
  private static let testConfigs: [InstanceConfig] = [
    .googleAI_v1beta,
    .agentPlatform_v1beta_global,
  ]

  @Test(arguments: testConfigs)
  func generateContentWithText(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let userName = "paul"
    let response = try await model.generateContent(
      templateID: "greeting-5",
      inputs: [
        "name": userName,
        "language": "Spanish",
      ]
    )
    let text = try #require(response.text)
    #expect(text.localizedCaseInsensitiveContains("Paul"))
  }

  @Test(arguments: testConfigs)
  func generateContentStream(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let userName = "paul"
    let stream = try model.generateContentStream(
      templateID: "greeting-5",
      inputs: [
        "name": userName,
        "language": "English",
      ]
    )
    var resultText = ""
    for try await response in stream {
      if let text = response.text {
        resultText += text
      }
    }
    #expect(resultText.localizedCaseInsensitiveContains("Paul"))
  }

  @Test(arguments: [
    InstanceConfig.googleAI_v1beta,
    InstanceConfig.agentPlatform_v1beta,
  ])
  func generateContentWithTemplateMapsGrounding(_ config: InstanceConfig) async throws {
    let toolConfig = TemplateToolConfig(
      retrievalConfig: RetrievalConfig(
        location: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.2822)
      )
    )
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel(toolConfig: toolConfig)
    let userName = "paul"
    let response = try await model.generateContent(
      templateID: "location-via-sdk",
      inputs: [
        "name": userName,
      ]
    )
    let text = try #require(response.text)
    #expect(text.localizedCaseInsensitiveContains("Paul"))
    #expect(text.localizedCaseInsensitiveContains("museum"))
  }

  @Test(arguments: testConfigs)
  func generateContentWithMedia(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    #if canImport(UIKit)
      let image = UIImage(systemName: "photo")!
    #elseif canImport(AppKit)
      let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
    #endif
    let imageBytes = try #require(
      image.jpegData(compressionQuality: 0.8), "Could not get image data."
    )
    let base64Image = imageBytes.base64EncodedString()

    let response = try await model.generateContent(
      templateID: "media",
      inputs: [
        "imageData": [
          "isInline": true,
          "mimeType": "image/jpeg",
          "contents": base64Image,
        ],
      ]
    )
    let text = try #require(response.text)
    #expect(!text.isEmpty)
  }

  @Test(arguments: testConfigs)
  func generateContentStreamWithMedia(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    #if canImport(UIKit)
      let image = UIImage(systemName: "photo")!
    #elseif canImport(AppKit)
      let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
    #endif
    let imageBytes = try #require(
      image.jpegData(compressionQuality: 0.8), "Could not get image data."
    )
    let base64Image = imageBytes.base64EncodedString()

    let stream = try model.generateContentStream(
      templateID: "media",
      inputs: [
        "imageData": [
          "isInline": true,
          "mimeType": "image/jpeg",
          "contents": base64Image,
        ],
      ]
    )
    var resultText = ""
    for try await response in stream {
      if let text = response.text {
        resultText += text
      }
    }
    #expect(!resultText.isEmpty)
  }

  @Test(arguments: testConfigs)
  func chat(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hi, my favourite colour is blue!"),
      ModelContent(role: "model", parts: """
      Hi there! Blue is a fantastic choice—it's the color of the ocean and the open sky.
      """),
    ]
    let userMessage = "What is its complementary colour on the traditional colour wheel?"
    let chatSession = model.startChat(templateID: "chat-history", inputs: ["message": userMessage],
                                      history: initialHistory)

    let response = try await chatSession.sendMessage(userMessage)
    let responseText = try #require(response.text)
    #expect(!responseText.isEmpty)
    #expect(responseText.localizedCaseInsensitiveContains("orange"))
    #expect(chatSession.history.count == 4)
    let promptTextPart = try #require(chatSession.history[2].parts.first as? TextPart)
    #expect(promptTextPart.text == userMessage)
  }

  @Test(arguments: testConfigs)
  func chatStream(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hi, my favourite colour is blue!"),
      ModelContent(role: "model", parts: """
      Hi there! Blue is a fantastic choice—it's the color of the ocean and the open sky.
      """),
    ]
    let userMessage = "What is its complementary colour on the traditional colour wheel?"
    let chatSession = model.startChat(templateID: "chat-history", inputs: ["message": userMessage],
                                      history: initialHistory)

    let stream = try chatSession.sendMessageStream(userMessage)
    var resultText = ""
    for try await response in stream {
      if let text = response.text {
        resultText += text
      }
    }

    #expect(!resultText.isEmpty)
    #expect(resultText.localizedCaseInsensitiveContains("orange"))
    #expect(chatSession.history.count == 4)
    let promptTextPart = try #require(chatSession.history[2].parts.first as? TextPart)
    #expect(promptTextPart.text == userMessage)
  }

  @Test(arguments: testConfigs)
  func chatFunctionCalling(_ config: InstanceConfig) async throws {
    // 1. Configure the model with tools and start a template chat session.
    let weatherFunction = FunctionDeclaration(
      name: "fetchWeather",
      description: "Returns the weather for a given location at a given time",
      parameters: [
        "location": .object(properties: [
          "city": .string(description: "The city of the location."),
          "state": .string(description: "The state of the location."),
        ]),
        "date": .string(description: """
        The date for which to get the weather. Date must be in the format: YYYY-MM-DD.
        """),
        "unit": .enumeration(values: ["CELSIUS", "FAHRENHEIT"]),
      ]
    )
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel(
      tools: [.functionDeclarations([weatherFunction])]
    )
    let chat = model.startChat(
      templateID: "integration-test-function-calling",
      inputs: [
        "city": "Boston",
        "state": "Massachusetts",
        "date": "2024-10-17",
        "unit": "CELSIUS",
      ]
    )

    // 2. Initial turn: Trigger the prompt template by sending an empty message.
    // The template prompt does not require any additional content so we specify `[]`. Prompt:
    //   What was the weather like in {{city}}, {{state}} on {{date}}, formatted in {{unit}}?
    //   {{history}}
    let response = try await chat.sendMessage([])

    // 3. Verify the model requested the fetchWeather function with populated arguments.
    #expect(response.functionCalls.count == 1)
    let functionCall = try #require(response.functionCalls.first)
    #expect(functionCall.name == weatherFunction.name)
    #expect(functionCall.args == [
      "location": .object([
        "city": .string("Boston"),
        "state": .string("Massachusetts"),
      ]),
      "date": .string("2024-10-17"),
      "unit": .string("CELSIUS"),
    ])
    #expect(chat.history.count == 1)
    #expect(chat.history[0].role == "model")
    let historyFunctionCall = try #require(chat.history[0].parts.first as? FunctionCallPart)
    #expect(functionCall == historyFunctionCall)

    // 4. Second turn: Supply the function execution result back to the model.
    let functionResponse = FunctionResponsePart(
      name: functionCall.name,
      response: [
        "condition": .string("Mostly sunny"),
        "summary": .string("Cool, dry, and mostly sunny"),
        "temperature": .object([
          "high": .object([
            "value": .number(13),
            "unit": .string("CELSIUS"),
          ]),
        ]),
        "precipitation": .object([
          "description": .string("none"),
          "value": .number(0),
          "unit": .string("MILLIMETERS"),
        ]),
      ],
      functionId: functionCall.functionId
    )

    let finalResponse = try await chat.sendMessage([functionResponse])

    // 5. Verify the model generated the final text response using the function result.
    #expect(finalResponse.functionCalls.isEmpty)
    let responseText = try #require(finalResponse.text)
    #expect(!responseText.isEmpty)
    #expect(responseText.localizedCaseInsensitiveContains("sunny"))
    #expect(responseText.contains("13"))
    #expect(chat.history.count == 3)
    #expect(chat.history[1].role == "user")
    let promptFunctionResponse = try #require(
      chat.history[1].parts.first as? FunctionResponsePart
    )
    #expect(promptFunctionResponse == functionResponse)
    #expect(chat.history[2].role == "model")
    let responseTextPart = try #require(chat.history[2].parts.first as? TextPart)
    #expect(responseTextPart.text == responseText)
  }
}

#if canImport(AppKit)
  import AppKit

  extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
      guard let tiffRepresentation = tiffRepresentation,
            let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
        return nil
      }
      return bitmapImage.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionQuality]
      )
    }
  }
#endif
