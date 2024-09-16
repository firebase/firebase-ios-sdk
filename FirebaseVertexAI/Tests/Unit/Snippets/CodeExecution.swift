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
final class CodeExecutionSnippets: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipIf(
      APIKey.default.isEmpty,
      "`\(APIKey.apiKeyEnvVar)` environment variable not set."
    )
  }

  func testCodeExecutionBasic() async throws {
    // [START code_execution_basic]
    let generativeModel =
      GenerativeModel(
        // Specify a Gemini model appropriate for your use case
        name: "gemini-1.5-flash",
        // Access your API key from your on-demand resource .plist file (see
        // "Set up your API key" above)
        apiKey: APIKey.default,
        tools: [Tool(codeExecution: CodeExecution())]
      )

    let prompt = """
    What is the sum of the first 50 prime numbers?
    Generate and run code for the calculation, and make sure you get all 50.
    """
    let response = try await generativeModel.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END code_execution_basic]
  }

  func testCodeExecutionChat() async throws {
    // [START code_execution_chat]
    let generativeModel =
      GenerativeModel(
        // Specify a Gemini model appropriate for your use case
        name: "gemini-1.5-flash",
        // Access your API key from your on-demand resource .plist file (see
        // "Set up your API key" above)
        apiKey: APIKey.default,
        tools: [Tool(codeExecution: CodeExecution())]
      )

    let chat = generativeModel.startChat()

    let prompt = """
    What is the sum of the first 50 prime numbers?
    Generate and run code for the calculation, and make sure you get all 50.
    """
    let response = try await chat.sendMessage(prompt)
    if let text = response.text {
      print(text)
    }
    // [END code_execution_chat]
  }
}
