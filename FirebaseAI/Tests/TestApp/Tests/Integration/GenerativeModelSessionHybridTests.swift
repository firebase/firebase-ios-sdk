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

// TODO: Remove the `#if compiler(>=6.2.3)` when Xcode 26.2 is the minimum supported version.
#if compiler(>=6.2.3)
  @testable import FirebaseAILogic
  import FirebaseAITestApp
  import Foundation
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)
  import Testing

  @Suite(.serialized)
  struct GenerativeModelSessionHybridTests {
    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    func respondText_fallbackOnGeminiModelError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let invalidModel1 = firebaseAI.geminiModel(name: "invalid-model-name-1")
      let invalidModel2 = firebaseAI.geminiModel(name: "invalid-model-name-2")
      let validModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: .hybridModel(
          primary: invalidModel1,
          secondary: .hybridModel( // Nested hybrid model
            primary: invalidModel2,
            secondary: validModel
          )
        )
      )
      let prompt = "Why is the sky blue?"

      let response = try await session.respond(to: prompt)

      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete)
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          #expect(response.rawContent.kind == .string(content))
        }
      #endif // canImport(FoundationModels)
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.text == content)
      #expect(response.rawResponse.modelVersion == validModel._modelName)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondText_fallbackOnFoundationModelsError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let systemModel = FirebaseAI.SystemLanguageModel.default
      let geminiModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: HybridModel(primary: systemModel, secondary: geminiModel)
      )
      let prompt = "In one sentence, why is the sky blue?"

      let response = try await session.respond(to: prompt)

      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.kind == .string(content))
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.text == content)
      // Check for the on-device model name when running on Apple Intelligence supported devices; in
      // this case, no fallback occurs. When running on devices that do not support Apple
      // Intelligence, including GitHub Runner Images, check for the cloud (Gemini) model name.
      if await foundationModelsIsAvailable() {
        #expect(response.rawResponse.modelVersion == systemModel._modelName)
      } else {
        #expect(response.rawResponse.modelVersion == geminiModel._modelName)
      }
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGenerable_fallbackOnGeminiModelError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let invalidModel = firebaseAI.geminiModel(name: "invalid-model-name-1")
      let validModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: HybridModel(primary: invalidModel, secondary: validModel)
      )
      let prompt = "Generate a cute rescue cat"

      let response = try await session.respond(
        to: prompt,
        generating: GenerativeModelSessionTests.CatProfile.self
      )

      let catProfile = response.content
      #expect(!catProfile.name.isEmpty)
      #expect(catProfile.age >= 1)
      #expect(catProfile.age <= 20)
      #expect(!catProfile.profile.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.modelVersion == validModel._modelName)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    func streamResponseText_fallbackOnGeminiModelError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let invalidModel = firebaseAI.geminiModel(name: "invalid-model-name")
      let validModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: HybridModel(primary: invalidModel, secondary: validModel)
      )
      let prompt = "In one sentence, why is the sky blue?"

      let stream = session.streamResponse(to: prompt)

      var generationID: FirebaseAI.GenerationID?
      var isComplete = false
      for try await snapshot in stream {
        #expect(!isComplete, "Stream yielded more elements after a snapshot was marked complete.")
        let partial = snapshot.content
        #expect(!partial.isEmpty)
        if let generationID {
          #expect(
            generationID == snapshot.rawContent.generationID,
            "The generation ID was not stable for the duration of the response."
          )
        } else {
          #expect(snapshot.rawContent.generationID != nil)
          generationID = snapshot.rawContent.generationID
        }
        isComplete = snapshot.rawContent.isComplete
      }
      #expect(isComplete, "The stream finished, but the final snapshot was not marked as complete.")

      let response = try await stream.collect()
      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete, "The final response was not marked as complete.")
      #expect(response.rawContent.generationID == generationID)
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          #expect(response.rawContent.kind == .string(content))
        }
      #endif // canImport(FoundationModels)
      if let text = response.rawResponse.text {
        #expect(content.hasSuffix(text))
      }
      #expect(response.rawResponse.modelVersion == validModel._modelName)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func streamResponseGenerable_fallbackOnGeminiModelError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let invalidModel = firebaseAI.geminiModel(name: "invalid-model-name")
      let validModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: .hybridModel(primary: invalidModel, secondary: validModel)
      )
      let prompt = "Generate a cute rescue cat"

      let stream = session.streamResponse(
        to: prompt,
        generating: GenerativeModelSessionTests.CatProfile.self
      )

      var generationID: FirebaseAI.GenerationID?
      var isComplete = false
      for try await snapshot in stream {
        #expect(!isComplete, "Stream yielded more elements after a snapshot was marked complete.")
        if let generationID {
          #expect(
            generationID == snapshot.rawContent.generationID,
            "The generation ID was not stable for the duration of the response."
          )
        } else {
          #expect(snapshot.rawContent.generationID != nil)
          generationID = snapshot.rawContent.generationID
        }
        isComplete = snapshot.rawContent.isComplete
      }
      #expect(isComplete, "The stream finished, but the final snapshot was not marked as complete.")

      let response = try await stream.collect()
      let catProfile = response.content
      #expect(!catProfile.name.isEmpty)
      #expect(catProfile.age >= 1)
      #expect(catProfile.age <= 20)
      #expect(!catProfile.profile.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.modelVersion == validModel._modelName)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func streamResponseText_fallbackOnFoundationModelsError(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let systemModel = FirebaseAI.SystemLanguageModel.default
      let geminiModel = firebaseAI.geminiModel(name: ModelNames.gemini2_5_FlashLite)
      let session = firebaseAI.generativeModelSession(
        model: HybridModel(primary: systemModel, secondary: geminiModel)
      )
      let prompt = "In one sentence, why is the sky blue?"

      let stream = session.streamResponse(to: prompt)

      var receivedTexts = [String]()
      var isComplete = false
      for try await snapshot in stream {
        let partial = snapshot.content
        receivedTexts.append(partial)
        isComplete = snapshot.rawContent.isComplete
      }
      #expect(isComplete)

      let response = try await stream.collect()
      let content = response.content
      #expect(!content.isEmpty)

      if await foundationModelsIsAvailable() {
        #expect(response.rawResponse.modelVersion == systemModel._modelName)
      } else {
        #expect(response.rawResponse.modelVersion == geminiModel._modelName)
      }
    }

    /// Returns `true` if `FoundationModels.SystemLanguageModel` is available.
    ///
    /// This is a workaround for `SystemLanguageModel.isAvailable`, which returns `true` if *any*
    /// version of the model is available. However, calls to `LanguageModelSession().respond(to:)`
    /// throw a `ModelManagerError` if the simulator's model version does not match the host macOS
    /// version. A new version of the model was introduced in Xcode/macOS/iOS 26.4.
    func foundationModelsIsAvailable() async -> Bool {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          let model = SystemLanguageModel.default
          guard model.isAvailable else {
            return false
          }

          let session = LanguageModelSession(model: model)
          do {
            _ = try await session.respond(
              to: "Hello",
              options: GenerationOptions(sampling: .greedy, temperature: 0)
            )

            return true
          } catch {
            return false
          }
        }
      #endif // canImport(FoundationModels)

      return false
    }
  }
#endif // compiler(>=6.2.3)
