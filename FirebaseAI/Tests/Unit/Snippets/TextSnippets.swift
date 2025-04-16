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
final class TextSnippets: XCTestCase {
  lazy var model = VertexAI.vertexAI().generativeModel(modelName: "gemini-1.5-flash")

  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func testTextOnlyNonStreaming() async throws {
    // Provide a prompt that contains text
    let prompt = "Write a story about a magic backpack."

    // To generate text output, call generateContent with the text input
    let response = try await model.generateContent(prompt)
    print(response.text ?? "No text in response.")
  }

  func testTextOnlyStreaming() async throws {
    // Provide a prompt that contains text
    let prompt = "Write a story about a magic backpack."

    // To stream generated text output, call generateContentStream with the text input
    let contentStream = try model.generateContentStream(prompt)
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
  }
}
