// Copyright 2026 Google LLC
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

import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore
import Foundation
import Testing

@Suite(
  "FirebaseAILogic Integration Tests",
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["AppCheckDebugToken"] != nil)
)
struct FirebaseAILogicIntegrationTests {
  private static let backends = [Backend.googleAI(), Backend.enterprise()]

  private let modelName = "gemini-3.1-flash-lite"

  init() {
    if FirebaseApp.isDefaultAppConfigured() {
      return
    }
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    FirebaseApp.configure()
  }

  @Test(arguments: backends)
  func generateContent(_ backend: Backend) async throws {
    let ai = FirebaseAI.firebaseAI(backend: backend)
    let model = ai.generativeModel(modelName: modelName)

    let response = try await model.generateContent("Reply with the single word 'HELLO'.")

    let text = try #require(response.text)
    #expect(text.localizedCaseInsensitiveContains("HELLO"))
    let usage = try #require(response.usageMetadata)
    #expect(usage.totalTokenCount > 0)
  }

  @Test(arguments: backends)
  func countTokens(_ backend: Backend) async throws {
    let ai = FirebaseAI.firebaseAI(backend: backend)
    let model = ai.generativeModel(modelName: modelName)

    let response = try await model.countTokens("Why is the sky blue?")

    #expect(response.totalTokens > 0)
    #expect(!response.promptTokensDetails.isEmpty)
  }

  @Test(arguments: backends)
  func chatSendMessage(_ backend: Backend) async throws {
    let ai = FirebaseAI.firebaseAI(backend: backend)
    let model = ai.generativeModel(modelName: modelName)
    let chat = model.startChat()

    _ = try await chat.sendMessage("My favorite color is teal.")
    let response = try await chat.sendMessage(
      "What is my favorite color? Answer in one word."
    )

    let text = try #require(response.text)
    #expect(text.localizedCaseInsensitiveContains("teal"))
    #expect(chat.history.count == 4)
  }
}
