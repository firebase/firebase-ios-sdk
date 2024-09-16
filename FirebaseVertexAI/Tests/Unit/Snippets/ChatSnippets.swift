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

import GoogleGenerativeAI
import XCTest

// Set up your API Key
// ====================
// To use the Gemini API, you'll need an API key. To learn more, see the "Set up your API Key"
// section in the Gemini API quickstart:
// https://ai.google.dev/gemini-api/docs/quickstart?lang=swift#set-up-api-key

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
final class ChatSnippets: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipIf(
      APIKey.default.isEmpty,
      "`\(APIKey.apiKeyEnvVar)` environment variable not set."
    )
  }

  func testChat() async throws {
    // [START chat]
    let generativeModel =
      GenerativeModel(
        // Specify a Gemini model appropriate for your use case
        name: "gemini-1.5-flash",
        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
        // above)
        apiKey: APIKey.default
      )

    // Optionally specify existing chat history
    let history = [
      ModelContent(role: "user", parts: "Hello, I have 2 dogs in my house."),
      ModelContent(role: "model", parts: "Great to meet you. What would you like to know?"),
    ]

    // Initialize the chat with optional chat history
    let chat = generativeModel.startChat(history: history)

    // To generate text output, call sendMessage and pass in the message
    let response = try await chat.sendMessage("How many paws are in my house?")
    if let text = response.text {
      print(text)
    }
    // [END chat]
  }

  func testChatStreaming() async throws {
    // [START chat_streaming]
    let generativeModel =
      GenerativeModel(
        // Specify a Gemini model appropriate for your use case
        name: "gemini-1.5-flash",
        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
        // above)
        apiKey: APIKey.default
      )

    // Optionally specify existing chat history
    let history = [
      ModelContent(role: "user", parts: "Hello, I have 2 dogs in my house."),
      ModelContent(role: "model", parts: "Great to meet you. What would you like to know?"),
    ]

    // Initialize the chat with optional chat history
    let chat = generativeModel.startChat(history: history)

    // To stream generated text output, call sendMessageStream and pass in the message
    let contentStream = chat.sendMessageStream("How many paws are in my house?")
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
    // [END chat_streaming]
  }

  #if canImport(UIKit)
    func testChatStreamingWithImages() async throws {
      // [START chat_streaming_with_images]
      let generativeModel =
        GenerativeModel(
          // Specify a Gemini model appropriate for your use case
          name: "gemini-1.5-flash",
          // Access your API key from your on-demand resource .plist file (see "Set up your API key"
          // above)
          apiKey: APIKey.default
        )

      // Optionally specify existing chat history
      let history = [
        ModelContent(role: "user", parts: "I'm trying to remember a fable about two animals."),
        ModelContent(role: "model", parts: "Do you remember what kind of animals were they?"),
      ]

      guard let image1 = UIImage(systemName: "tortoise") else { fatalError() }
      guard let image2 = UIImage(systemName: "hare") else { fatalError() }

      // Initialize the chat with optional chat history
      let chat = generativeModel.startChat(history: history)

      // To stream generated text output, call sendMessageStream and pass in the message
      let contentStream = chat.sendMessageStream("The animals from these pictures.", image1, image2)
      for try await chunk in contentStream {
        if let text = chunk.text {
          print(text)
        }
      }
      // [END chat_streaming_with_images]
    }
  #endif // canImport(UIKit)
}
