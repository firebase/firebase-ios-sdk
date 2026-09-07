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

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @Generable(description: "Basic profile information about a cat")
    struct CatProfile {
      var name: String

      @Guide(description: "The age of the cat", .range(0 ... 20))
      var age: Int

      @Guide(description: "A one sentence profile about the cat's personality")
      var profile: String
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGenerateStructuredCat(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "Generate a cute rescue cat",
        generating: CatProfile.self
      )

      let cat = response.content
      #expect(!cat.name.isEmpty)
      #expect(cat.age >= 0 && cat.age <= 20)
      #expect(!cat.profile.isEmpty)
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
