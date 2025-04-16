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

// These snippet tests are intentionally skipped in CI jobs; see the README file in this directory
// for instructions on running them manually.

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ChatSnippets: XCTestCase {
  lazy var model = VertexAI.vertexAI().generativeModel(modelName: "gemini-1.5-flash")

  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func testChatNonStreaming() async throws {
    // Optionally specify existing chat history
    let history = [
      ModelContent(role: "user", parts: "Hello, I have 2 dogs in my house."),
      ModelContent(role: "model", parts: "Great to meet you. What would you like to know?"),
    ]

    // Initialize the chat with optional chat history
    let chat = model.startChat(history: history)

    // To generate text output, call sendMessage and pass in the message
    let response = try await chat.sendMessage("How many paws are in my house?")
    print(response.text ?? "No text in response.")
  }

  func testChatStreaming() async throws {
    // Optionally specify existing chat history
    let history = [
      ModelContent(role: "user", parts: "Hello, I have 2 dogs in my house."),
      ModelContent(role: "model", parts: "Great to meet you. What would you like to know?"),
    ]

    // Initialize the chat with optional chat history
    let chat = model.startChat(history: history)

    // To stream generated text output, call sendMessageStream and pass in the message
    let contentStream = try chat.sendMessageStream("How many paws are in my house?")
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
  }
}
