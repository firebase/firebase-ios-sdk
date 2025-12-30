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

import FirebaseAILogic
import FirebaseAITestApp
import FirebaseAuth
import FirebaseCore
import Testing

@Suite(.serialized)
struct GenerateObjectStreamIntegrationTests {
  // Set temperature to 0 for deterministic output.
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
  ]

  static let modelConfigurations = [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_Flash),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3FlashPreview),
  ]

  @Test(arguments: modelConfigurations)
  func generateObjectStream_recipe(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate a recipe for chocolate chip cookies."

    let stream = model.generateObjectStream(Recipe.self, parts: prompt)
    var finalResponse: GenerativeModel.Response<Recipe>?

    for try await response in stream {
      finalResponse = response
    }

    let response = try #require(finalResponse)
    let recipe = response.content
    #expect(!recipe.name.isEmpty)
    #expect(!recipe.ingredients.isEmpty)
    #expect(recipe.name.lowercased().contains("cookie"))

    // verify rawContent structure
    let rawContent = response.rawContent
    guard case .structure = rawContent.kind else {
      Issue.record("Raw content should be a structure")
      return
    }
  }

  #if canImport(FoundationModels)
    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObjectStream_macroRecipe(_ config: InstanceConfig,
                                          modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a recipe for brownies."

      // MacroRecipe is defined in GenerateObjectIntegrationTests.swift
      let stream = model.generateObjectStream(MacroRecipe.self, parts: prompt)
      var finalResponse: GenerativeModel.Response<MacroRecipe>?

      for try await response in stream {
        finalResponse = response
      }

      let response = try #require(finalResponse)
      let recipe = response.content
      #expect(!recipe.name.isEmpty)
      #expect(!recipe.ingredients.isEmpty)
      #expect(recipe.name.lowercased().contains("brownie"))
    }

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObjectStream_guidedRecipe(_ config: InstanceConfig,
                                           modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a recipe for a cake."

      // GuidedRecipe is defined in GenerateObjectIntegrationTests.swift
      let stream = model.generateObjectStream(GuidedRecipe.self, parts: prompt)
      var finalResponse: GenerativeModel.Response<GuidedRecipe>?

      for try await response in stream {
        finalResponse = response
      }

      let response = try #require(finalResponse)
      let recipe = response.content
      #expect(!recipe.name.isEmpty)
      #expect(!recipe.ingredients.isEmpty)
      #expect(recipe.ingredients.count <= 5)
    }
  #endif
}
