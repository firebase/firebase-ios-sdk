
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
    let model = FirebaseAI.firebaseAI(backend: .vertexAI()).templateGenerativeModel()
    let userName = "paul"
    do {
      let response = try await model.generateContent(
        template: "greeting",
        variables: [
          "name": userName,
          "language": "English",
        ]
      )
      let text = try XCTUnwrap(response.text)
      print(text)
      XCTAssert(text.contains("Paul"))
    } catch {
      XCTFail("An error occurred: \(error)")
    }
  }

  func testGenerateImages() async throws {
    let imagenModel = FirebaseAI.firebaseAI(backend: .vertexAI()).templateImagenModel()
    let imagenPrompt = "A cat picture"
    do {
      let response = try await imagenModel.generateImages(
        template: "generate_images",
        variables: [
          "prompt": imagenPrompt,
        ]
      )
      XCTAssertEqual(response.images.count, 3)
    } catch {
      XCTFail("An error occurred: \(error)")
    }
  }

  func testGenerateContentWithMedia() async throws {
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).templateGenerativeModel()
    let image = UIImage(systemName: "photo")!
    if let imageBytes = image.jpegData(compressionQuality: 0.8) {
      let base64Image = imageBytes.base64EncodedString()

      do {
        let response = try await model.generateContent(
          template: "media",
          variables: [
            "imageData": [
              "isInline": true,
              "mimeType": "image/jpeg",
              "contents": base64Image,
            ],
          ]
        )
        XCTAssert(response.text?.isEmpty == false)
      } catch {
        XCTFail("An error occurred: \(error)")
      }
    } else {
      XCTFail("Could not get image data.")
    }
  }

  func testChat() async throws {
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).templateGenerativeModel()
    let initialHistory = [
      ModelContent(role: "user", parts: "Hello!"),
      ModelContent(role: "model", parts: "Hi there! How can I help?"),
    ]
    let chatSession = model.startChat(template: "chat_history", history: initialHistory)

    let userMessage = "What's the weather like?"

    do {
      let response = try await chatSession.sendMessage(
        userMessage,
        variables: ["message": userMessage]
      )
      XCTAssert(response.text?.isEmpty == false)
      XCTAssertEqual(chatSession.history.count, 3)
    } catch {
      XCTFail("An error occurred: \(error)")
    }
  }
}
