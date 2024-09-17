// Copyright 2024 Google LLC
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

import FirebaseCore
import FirebaseVertexAI
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CountTokensSnippets: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureForSnippets()
  }

  override func tearDown() async throws {
    if let app = FirebaseApp.app() {
      await app.delete()
    }
  }

  func testCountTokensTextOnly() async throws {
    let model = VertexAI.vertexAI().generativeModel(modelName: "gemini-1.5-flash")

    // [START tokens_text_only]
    let response = try await model.countTokens("Write a story about a magic backpack.")
    print("Total Tokens: \(response.totalTokens)")
    print("Total Billable Characters: \(response.totalBillableCharacters)")
    // [END tokens_text_only]
  }

//  func testCountTokensChat() async throws {
//    // [START tokens_chat]
//    let generativeModel =
//      GenerativeModel(
//        // Specify a Gemini model appropriate for your use case
//        name: "gemini-1.5-flash",
//        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
//        // above)
//        apiKey: APIKey.default
//      )
//
//    // Optionally specify existing chat history
//    let history = [
//      ModelContent(role: "user", parts: "Hello, I have 2 dogs in my house."),
//      ModelContent(role: "model", parts: "Great to meet you. What would you like to know?"),
//    ]
//
//    // Initialize the chat with optional chat history
//    let chat = generativeModel.startChat(history: history)
//
//    let response = try await generativeModel.countTokens(chat.history + [
//      ModelContent(role: "user", parts: "This is the message I intend to send"),
//    ])
//    print("Total Tokens: \(response.totalTokens)")
//    // [END tokens_chat]
//  }

//  #if canImport(UIKit)
//    func testCountTokensMultimodalInline() async throws {
//      // [START tokens_multimodal_image_inline]
//      let generativeModel =
//        GenerativeModel(
//          // Specify a Gemini model appropriate for your use case
//          name: "gemini-1.5-flash",
//          // Access your API key from your on-demand resource .plist file (see "Set up your API
//          /key"
//          // above)
//          apiKey: APIKey.default
//        )
//
//      guard let image1 = UIImage(systemName: "cloud.sun") else { fatalError() }
//      guard let image2 = UIImage(systemName: "cloud.heavyrain") else { fatalError() }
//
//      let prompt = "What's the difference between these pictures?"
//
//      let response = try await generativeModel.countTokens(image1, image2, prompt)
//      print("Total Tokens: \(response.totalTokens)")
//      // [END tokens_multimodal_image_inline]
//    }
//  #endif // canImport(UIKit)

//  func testCountTokensSystemInstruction() async throws {
//    // [START tokens_system_instruction]
//    let generativeModel =
//      GenerativeModel(
//        // Specify a model that supports system instructions, like a Gemini 1.5 model
//        name: "gemini-1.5-flash",
//        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
//        // above)
//        apiKey: APIKey.default,
//        systemInstruction: ModelContent(role: "system", parts: "You are a cat. Your name is Neko.")
//      )
//
//    let prompt = "What is your name?"
//
//    let response = try await generativeModel.countTokens(prompt)
//    print("Total Tokens: \(response.totalTokens)")
//    // [END tokens_system_instruction]
//  }

//  func testCountTokensTools() async throws {
//    // [START tokens_tools]
//    let generativeModel =
//      GenerativeModel(
//        // Specify a model that supports system instructions, like a Gemini 1.5 model
//        name: "gemini-1.5-flash",
//        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
//        // above)
//        apiKey: APIKey.default,
//        tools: [Tool(functionDeclarations: [
//          FunctionDeclaration(
//            name: "controlLight",
//            description: "Set the brightness and color temperature of a room light.",
//            parameters: [
//              "brightness": Schema(
//                type: .number,
//                format: "double",
//                description: "Light level from 0 to 100. Zero is off and 100 is full brightness."
//              ),
//              "colorTemperature": Schema(
//                type: .string,
//                format: "enum",
//                description: "Color temperature of the light fixture.",
//                enumValues: ["daylight", "cool", "warm"]
//              ),
//            ],
//            requiredParameters: ["brightness", "colorTemperature"]
//          ),
//        ])]
//      )
//
//    let prompt = "Dim the lights so the room feels cozy and warm."
//
//    let response = try await generativeModel.countTokens(prompt)
//    print("Total Tokens: \(response.totalTokens)")
//    // [END tokens_tools]
//  }
}
