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

import FirebaseAI
import Testing
#if canImport(UIKit)
  import UIKit
#endif

struct ServerPromptTemplateIntegrationTests {
  private static let testConfigs: [InstanceConfig] = [
    .vertexAI_v1beta,
    .vertexAI_v1beta_global,
  ]
  private static let imageGenerationTestConfigs: [InstanceConfig] = [.vertexAI_v1beta]

  @Test(arguments: [
    // The "greeting2" template is only available in the `global` location.
    InstanceConfig.vertexAI_v1beta_global,
  ])
  func generateContentWithText(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let userName = "paul"
    let response = try await model.generateContent(
      templateID: "greeting4",
      inputs: [
        "name": userName,
        "language": "Spanish",
      ]
    )
    let text = try #require(response.text)
    #expect(text.contains("Paul"))
  }

  @Test(arguments: [
    // The "greeting2" template is only available in the `global` location.
    InstanceConfig.vertexAI_v1beta_global,
  ])
  func generateContentStream(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let userName = "paul"
    let stream = try model.generateContentStream(
      templateID: "greeting2",
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
    #expect(resultText.contains("Paul"))
  }

  @Test(arguments: [
    // templatePredict is only currently supported on Developer API.
    InstanceConfig.googleAI_v1beta,
  ])
  func generateImages(_ config: InstanceConfig) async throws {
    let imagenModel = FirebaseAI.componentInstance(config).templateImagenModel()
    let imagenPrompt = "A cat picture"
    let response = try await imagenModel.generateImages(
      templateID: "generate-images2",
      variables: [
        "prompt": imagenPrompt,
      ]
    )
    #expect(response.images.count == 3)
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
      templateID: "media.prompt",
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

  @Test(arguments: [
    // The "greeting2" template is only available in the `global` location.
    InstanceConfig.vertexAI_v1beta_global,
  ])
  func chat(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hello!"),
      ModelContent(role: "model", parts: "Hi there! How can I help?"),
    ]
    let chatSession = model.startChat(templateID: "chat-history", history: initialHistory)

    let userMessage = "What's the weather like?"

    let response = try await chatSession.sendMessage(
      userMessage,
      variables: ["message": userMessage]
    )
    let text = try #require(response.text)
    #expect(!text.isEmpty)
    #expect(chatSession.history.count == 4)
    let textPart = try #require(chatSession.history[2].parts.first as? TextPart)
    #expect(textPart.text == userMessage)
  }

  @Test(arguments: testConfigs)
  func chatStream(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hello!"),
      ModelContent(role: "model", parts: "Hi there! How can I help?"),
    ]
    let chatSession = model.startChat(templateID: "chat_history.prompt", history: initialHistory)

    let userMessage = "What's the weather like?"

    let stream = try chatSession.sendMessageStream(
      userMessage,
      inputs: ["message": userMessage]
    )
    var resultText = ""
    for try await response in stream {
      if let text = response.text {
        resultText += text
      }
    }
    #expect(!resultText.isEmpty)
    #expect(chatSession.history.count == 4)
    let textPart = try #require(chatSession.history[2].parts.first as? TextPart)
    #expect(textPart.text == userMessage)
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
