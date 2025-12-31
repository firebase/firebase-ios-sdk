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

  static let modelConfigurations = [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_Flash),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3FlashPreview),
  ]

  @Test(arguments: modelConfigurations)
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
    @Test(arguments: modelConfigurations)
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

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObject_complexGuidedObject(_ config: InstanceConfig,
                                            modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a user profile."

      let response = try await model.generateObject(ComplexGuidedObject.self, parts: prompt)

      let object = response.content
      #expect(object.username.count >= 3 && object.username.count <= 20)
      #expect(object.tags.count >= 1 && object.tags.count <= 3)
    }

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObject_searchSuggestions(_ config: InstanceConfig,
                                          modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Suggest some search terms for 'summer vacation'."

      let response = try await model.generateObject(
        IntegrationSearchSuggestions.self,
        parts: prompt
      )

      let suggestions = response.content
      #expect(suggestions.searchTerms.count == 4)
      for term in suggestions.searchTerms {
        #expect(!term.searchTerm.isEmpty)
      }
    }

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObject_catAge(_ config: InstanceConfig, modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a cat profile."

      let response = try await model.generateObject(GuidedOldCat.self, parts: prompt)

      let cat = response.content
      #expect(cat.age >= 40 && cat.age <= 43)
    }

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func generateObject_complexParams(_ config: InstanceConfig, modelName: String) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt =
        "Generate a product with status 'active', count 10, score 4.5, and no description."

      let response = try await model.generateObject(ComplexParamsObject.self, parts: prompt)

      let object = response.content
      #expect(object.status == .active)
      #expect(object.count == 10)
      #expect(object.score == 4.5)
      #expect(object.optionalDescription == nil)
    }
  #endif
}

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct ComplexParamsObject: Equatable {
    @Generable
    enum Status: String, CaseIterable, Codable {
      case active, inactive, pending
    }

    let status: Status
    let count: Int
    let score: Float
    let optionalDescription: String?
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct MacroRecipe: Equatable {
    let name: String
    let ingredients: [String]
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct GuidedRecipe: Equatable {
    @Guide(description: "A funny name for the recipe.")
    let name: String
    @Guide(description: "List of ingredients.", .count(5))
    let ingredients: [String]
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct ComplexGuidedObject: Equatable {
    // Assuming FoundationModels supports these constraints
    // If exact syntax differs, this might need adjustment based on real API.
    // Assuming .minLength, .maxLength, .count(Range) exist.
    @Guide(description: "Username between 3 and 20 chars") // Placeholder if constraints strictly
    // checked
    let username: String

    @Guide(description: "1 to 3 tags", .count(1 ... 3))
    let tags: [String]
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct IntegrationSearchSuggestions: Equatable {
    @Guide(description: "A list of suggested search terms", .count(4))
    var searchTerms: [IntegrationSearchTerm]

    @Generable
    struct IntegrationSearchTerm: Equatable {
      // Assuming GenerationID is available in FoundationModels
      // var id: GenerationID

      @Guide(description: "A 2 or 3 word search term, like 'Beautiful sunsets'")
      var searchTerm: String
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Generable
  struct GuidedOldCat: Equatable {
    @Guide(description: "The name of the cat")
    let name: String

    // Assuming .range(ClosedRange<Int>) works
    @Guide(description: "The age of the cat", .range(40 ... 43))
    let age: Int
  }
#endif
