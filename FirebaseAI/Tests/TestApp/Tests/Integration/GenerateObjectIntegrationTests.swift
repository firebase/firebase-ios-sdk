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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct Recipe: FirebaseGenerable, Equatable {
  let name: String
  let ingredients: [String]

  static var jsonSchema: JSONSchema {
    JSONSchema(
      type: Self.self,
      properties: [
        JSONSchema.Property(name: "name", type: String.self),
        JSONSchema.Property(name: "ingredients", type: [String].self),
      ]
    )
  }

  init(_ content: ModelOutput) throws {
    name = try content.value(forProperty: "name")
    ingredients = try content.value(forProperty: "ingredients")
  }

  var modelOutput: ModelOutput {
    let properties: [(String, any ConvertibleToModelOutput)] = [
      ("name", name),
      ("ingredients", ingredients),
    ]
    return ModelOutput(properties: properties, uniquingKeysWith: { _, second in second })
  }
}

@Suite(.serialized)
struct GenerateObjectIntegrationTests {
  // Set temperature to 0 for deterministic output.
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
  ]

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_Flash),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3FlashPreview),
  ])
  func generateObject_recipe(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate a recipe for chocolate chip cookies."

    let response = try await model.generateObject(Recipe.self, parts: prompt)

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
    @Test(arguments: [
      (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_Flash),
      (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
      (InstanceConfig.googleAI_v1beta, ModelNames.gemini3FlashPreview),
    ])
    @available(iOS 26.0, macOS 26.0, *)
    func generateObject_macroRecipe(_ config: InstanceConfig, modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a recipe for brownies."

      // MacroRecipe is defined below
      let response = try await model.generateObject(MacroRecipe.self, parts: prompt)

      let recipe = response.content
      #expect(!recipe.name.isEmpty)
      #expect(!recipe.ingredients.isEmpty)
      #expect(recipe.name.lowercased().contains("brownie"))

      // verify rawContent structure
      let rawContent = response.rawContent
      guard case .structure = rawContent.kind else {
        Issue.record("Raw content should be a structure")
        return
      }
    }
  #endif
}

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct MacroRecipe: Equatable {
    let name: String
    let ingredients: [String]
  }
#endif
