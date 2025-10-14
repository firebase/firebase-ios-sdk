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

import XCTest

import FirebaseAI

final class ServerPromptTemplateIntegrationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testGenerateContentWithText() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI(location: "global")).templateGenerativeModel()
    let userName = "paul"
    let response = try await model.generateContent(
      template: "greeting2",
      variables: [
        "name": userName,
        "language": "Spanish",
      ]
    )
    let text = try XCTUnwrap(response.text)
    XCTAssert(text.contains("Paul"))
  }

  func testGenerateContentStream() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let userName = "paul"
    let stream = try model.generateContentStream(
      template: "greeting.prompt",
      variables: [
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
    XCTAssert(resultText.contains("Paul"))
  }

  func testGenerateImages() async throws {
    let imagenModel = FirebaseAI.firebaseAI(backend: .vertexAI()).templateImagenModel()
    let imagenPrompt = "A cat picture"
    let response = try await imagenModel.generateImages(
      template: "generate_images.prompt",
      variables: [
        "prompt": imagenPrompt,
      ]
    )
    XCTAssertEqual(response.images.count, 3)
  }

  func testGenerateContentWithMedia() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let image = UIImage(systemName: "photo")!
    if let imageBytes = image.jpegData(compressionQuality: 0.8) {
      let base64Image = imageBytes.base64EncodedString()

      let response = try await model.generateContent(
        template: "media.prompt",
        variables: [
          "imageData": [
            "isInline": true,
            "mimeType": "image/jpeg",
            "contents": base64Image,
          ],
        ]
      )
      XCTAssert(response.text?.isEmpty == false)
    } else {
      XCTFail("Could not get image data.")
    }
  }

  func testGenerateContentStreamWithMedia() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let image = UIImage(systemName: "photo")!
    if let imageBytes = image.jpegData(compressionQuality: 0.8) {
      let base64Image = imageBytes.base64EncodedString()

      let stream = try model.generateContentStream(
        template: "media.prompt",
        variables: [
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
      XCTAssert(resultText.isEmpty == false)
    } else {
      XCTFail("Could not get image data.")
    }
  }

  func testChat() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hello!"),
      ModelContent(role: "model", parts: "Hi there! How can I help?"),
    ]
    let chatSession = model.startChat(template: "chat_history.prompt", history: initialHistory)

    let userMessage = "What's the weather like?"

    let response = try await chatSession.sendMessage(
      userMessage,
      variables: ["message": userMessage]
    )
    XCTAssert(response.text?.isEmpty == false)
    XCTAssertEqual(chatSession.history.count, 4)
    XCTAssertEqual((chatSession.history[2].parts.first as? TextPart)?.text, userMessage)
  }

  func testChatStream() async throws {
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hello!"),
      ModelContent(role: "model", parts: "Hi there! How can I help?"),
    ]
    let chatSession = model.startChat(template: "chat_history.prompt", history: initialHistory)

    let userMessage = "What's the weather like?"

    let stream = try chatSession.sendMessageStream(
      userMessage,
      variables: ["message": userMessage]
    )
    var resultText = ""
    for try await response in stream {
      if let text = response.text {
        resultText += text
      }
    }
    XCTAssert(resultText.isEmpty == false)
    XCTAssertEqual(chatSession.history.count, 4)
    XCTAssertEqual((chatSession.history[2].parts.first as? TextPart)?.text, userMessage)
  }
}
