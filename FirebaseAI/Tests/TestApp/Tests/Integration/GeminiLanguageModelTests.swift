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

#if compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
  import FirebaseAILogic
  import FirebaseAITestApp
  import FirebaseCore
  import FoundationModels
  import Testing

  @Suite(.serialized)
  struct GeminiLanguageModelTests {
    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testStreamResponse(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse {
        "Tell me a story about a magic backpack."
      }

      var text = ""
      for try await snapshot in stream {
        #expect(snapshot.content.hasPrefix(text))
        text = snapshot.content
      }
      let allText = try await stream.collect().content

      #expect(!text.isEmpty)
      #expect(text == allText)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func intentionallyFailingTest(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse {
        "Hello"
      }
      let response = try await stream.collect().content

      Issue.record("""
      Fake issue - Intentionally failing test to verify that CI is set up correctly. Gemini did \
      respond with "\(response)" but pretending this failed for verification purposes.
      """)
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
