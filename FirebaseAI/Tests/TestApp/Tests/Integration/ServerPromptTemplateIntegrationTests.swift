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

// TODO: remove @testable when Template Chat is restored to the public API.
@testable import FirebaseAILogic
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
    let chatSession = model.startChat(
      templateID: "integration-test-function-calling",
      inputs: [
        "city": "Boston",
        "state": "Massachusetts",
        "date": "2024-10-17",
        "unit": "CELSIUS",
      ]
    )

    // The template prompt does not require any additional content so we specify `[]`. Prompt:
    //   What was the weather like in {{city}}, {{state}} on {{date}}, formatted in {{unit}}?
    //   {{history}}
    let response = try await chatSession.sendMessage([])

    #expect(response.functionCalls.count == 1)
    let functionCall = try #require(response.functionCalls.first)
    #expect(functionCall.name == weatherFunction.name)

    let arguments = functionCall.args
    guard case let .object(location) = arguments["location"] else {
      Issue.record("Missing object value named 'location' in arguments: \(arguments)")
      return
    }
    guard case let .string(city) = location["city"] else {
      Issue.record("Missing string value named 'city' in location: \(location)")
      return
    }
    #expect(city == "Boston")
    guard case let .string(state) = location["state"] else {
      Issue.record("Missing string value named 'state' in location: \(location)")
      return
    }
    #expect(state == "Massachusetts")
    guard case let .string(date) = arguments["date"] else {
      Issue.record("Missing string value named 'date' in arguments: \(arguments)")
      return
    }
    #expect(date == "2024-10-17")
    guard case let .string(unit) = arguments["unit"] else {
      Issue.record("Missing string value named 'unit' in arguments: \(arguments)")
      return
    }
    #expect(unit == "CELSIUS")
    #expect(chatSession.history.count == 1)
    let historyFunctionCall = try #require(chatSession.history[0].parts.first as? FunctionCallPart)
    #expect(functionCall == historyFunctionCall)

    // TODO: Respond with a `FunctionResponse` and include the information "on October 17, 2024, the
    // weather in Boston, Massachusetts was cool, dry, and mostly sunny with a high of 13°C.
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
