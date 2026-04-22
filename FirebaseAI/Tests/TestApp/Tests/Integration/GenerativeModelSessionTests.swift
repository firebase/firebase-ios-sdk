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
  struct GenerativeModelSessionTests {
    let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
    func respondText(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
      let prompt = "Why is the sky blue?"

      let response = try await session.respond(to: prompt, options: .default)

      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete)
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          #expect(response.rawContent.kind == .string(content))
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.text == content)
    }

    #if canImport(FoundationModels)
      @Generable(description: "Basic profile information about a cat")
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      struct CatProfile {
        // A guide isn't necessary for basic fields.
        var name: String

        @Guide(description: "The age of the cat", .range(1 ... 20))
        var age: Int

        @Guide(description: "A one sentence profile about the cat's personality")
        var profile: String
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func respondGeneratedContent(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt = "Generate a cute rescue cat"

        let response = try await session.respond(
          to: prompt,
          schema: CatProfile.generationSchema,
          options: .gemini(generationConfig)
        )

        let content = response.content
        #expect(content.isComplete)
        let name: String = try content.value(forProperty: "name")
        #expect(!name.isEmpty)
        let age: Int = try content.value(forProperty: "age")
        #expect(age >= 1)
        #expect(age <= 20)
        let profile: String = try content.value(forProperty: "profile")
        #expect(!profile.isEmpty)
        #expect(response.rawContent.isComplete)
        #expect(response.rawContent.generationID != nil)
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func respondGenerable(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt = "Generate a Ragdoll kitten"
        let config = GenerationConfig(
          thinkingConfig: ThinkingConfig(thinkingBudget: -1, includeThoughts: true)
        )

        let response = try await session.respond(
          to: prompt,
          generating: CatProfile.self,
          options: config
        )

        let catProfile = response.content
        #expect(!catProfile.name.isEmpty)
        #expect(catProfile.age >= 1)
        #expect(catProfile.age <= 20)
        #expect(!catProfile.profile.isEmpty)
        #expect(response.rawContent.isComplete)
        #expect(response.rawContent.generationID != nil)
        let thoughtSummary = try #require(
          response.rawResponse.thoughtSummary, "No thought summary was generated."
        )
        #expect(!thoughtSummary.isEmpty)
      }

      @Generable
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      enum Difficulty {
        case easy
        case medium
        case hard
      }

      @Generable
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      enum SuggestedCourse {
        case appetizer
        case main
        case dessert
      }

      @Generable(description: "A recipe for a delicious dish")
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      struct Recipe {
        @Guide(description: "The name of the dish")
        var name: String

        @Guide(description: "The time it takes to prepare the dish in minutes", .range(5 ... 120))
        var preparationTime: Int

        @Guide(description: "Whether the dish is vegetarian")
        var isVegetarian: Bool

        @Guide(description: "The rating of the dish from 1.0 to 5.0", .range(1.0 ... 5.0))
        var rating: Double

        @Guide(description: "A list of ingredients")
        var ingredients: [String]

        @Guide(description: "The difficulty of the recipe")
        var difficulty: Difficulty

        @Guide(description: "The course of the dish, such as appetizer, main, or dessert.")
        var course: SuggestedCourse
      }

      @Generable(description: "A list of recipes")
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      struct RecipeList {
        @Guide(description: "A list of recipes for a three-course meal.", .count(3))
        var recipes: [Recipe]
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func respondGenerableRecipe(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt = "Generate a recipe for a pasta dish with meat."

        let response = try await session.respond(
          to: prompt,
          generating: Recipe.self,
          options: generationConfig
        )

        let recipe = response.content
        #expect(!recipe.name.isEmpty)
        #expect(recipe.preparationTime >= 5)
        #expect(recipe.preparationTime <= 120)
        #expect(!recipe.isVegetarian)
        #expect(recipe.rating >= 1.0)
        #expect(recipe.rating <= 5.0)
        #expect(!recipe.ingredients.isEmpty)
        #expect([.appetizer, .main, .dessert].contains(recipe.course))
        #expect(response.rawContent.isComplete)
        #expect(response.rawContent.generationID != nil)
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func respondGenerableRecipeList(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt =
          "Generate three recipes for a full-course vegetarian meal (appetizer, main, dessert)."

        let response = try await session.respond(
          to: prompt,
          generating: RecipeList.self,
          options: .gemini(generationConfig)
        )

        let recipeList = response.content
        #expect(recipeList.recipes.count == 3)
        var courses = Set<SuggestedCourse>()
        for recipe in recipeList.recipes {
          #expect(!recipe.name.isEmpty)
          #expect(recipe.preparationTime >= 5)
          #expect(recipe.preparationTime <= 120)
          #expect(recipe.isVegetarian)
          #expect(recipe.rating >= 1.0)
          #expect(recipe.rating <= 5.0)
          #expect(!recipe.ingredients.isEmpty)
          courses.insert(recipe.course)
        }

        let allCourses: Set<SuggestedCourse> = [.appetizer, .main, .dessert]
        #expect(courses == allCourses)
        #expect(response.rawContent.isComplete)
        #expect(response.rawContent.generationID != nil)
      }
    #endif // canImport(FoundationModels)

    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    struct GetTemperature: FoundationModels.Tool {
      let description = "Returns the current temperature for the specified location."

      @Generable
      struct Location {
        let city: String
        @Guide(description: "The province or state.")
        let region: String
        let country: String
      }

      @Generable
      struct Temperature {
        @Generable enum Units { case celsius, fahrenheit, kelvin }

        let temperature: Double
        let units: Units
      }

      let testTemperature = Temperature(temperature: 25.0, units: .celsius)

      func call(arguments: Location) async throws -> Temperature {
        return testTemperature
      }
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondTextWithAutomaticFunctionCalling(_ config: InstanceConfig) async throws {
      let temperatureTool = GetTemperature()
      let session = FirebaseAI.componentInstance(config).generativeModelSession(
        model: ModelNames.gemini3_1_FlashLitePreview,
        tools: [temperatureTool],
        instructions: """
        You are a weather bot that specializes in reporting outdoor temperatures in Celsius.

        Always use the `GetTemperature` function to determine the current temperature in a location.

        Always respond in the format:
        - Location: City, Province/State, Country
        - Temperature: #C
        """
      )
      let prompt = "What is the current temperature in Waterloo, Ontario, Canada?"

      let response = try await session.respond(to: prompt, options: generationConfig)

      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.content.contains("Waterloo"))
      #expect(response.content.contains("25"))
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.kind == .string(content))
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.text == content)
      #expect(response.rawResponse.functionCalls.isEmpty)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGenerableWithAutomaticFunctionCalling(_ config: InstanceConfig) async throws {
      let temperatureTool = GetTemperature()
      let session = FirebaseAI.componentInstance(config).generativeModelSession(
        model: ModelNames.gemini3_1_FlashLitePreview,
        tools: [temperatureTool],
        instructions: """
        You are a weather bot that specializes in reporting outdoor temperatures in Celsius.

        Always use the `GetTemperature` function to determine the current temperature in a location.

        Return the final response as JSON.
        """
      )
      let prompt = "What is the current temperature in Waterloo, Ontario, Canada?"

      let response = try await session.respond(
        to: prompt,
        generating: GetTemperature.Temperature.self,
        options: .gemini(generationConfig)
      )

      let content = response.content
      #expect(content.temperature == 25)
      #expect(content.units == .celsius)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.functionCalls.isEmpty)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
    func respondTextWithURLContext(_ config: InstanceConfig) async throws {
      let session = FirebaseAI.componentInstance(config).generativeModelSession(
        model: ModelNames.gemini2_5_Flash,
        tools: [.urlContext()]
      )
      let url = "https://blog.google/innovation-and-ai/technology/developers-tools/functiongemma/"
      let prompt = "What was the name of the model announced in: \(url)"

      let response = try await session.respond(to: prompt, options: generationConfig)

      #expect(response.content.contains("FunctionGemma"))
      let candidate = try #require(response.rawResponse.candidates.first)
      let urlContextMetadata = try #require(candidate.urlContextMetadata)
      #expect(urlContextMetadata.urlMetadata.count == 1)
      let urlMetadata = try #require(urlContextMetadata.urlMetadata.first)
      #expect(urlMetadata.retrievalStatus == .success)
      let retrievedURL = try #require(urlMetadata.retrievedURL)
      #expect(retrievedURL == URL(string: url))
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
    func streamResponseText(_ config: InstanceConfig) async throws {
      let firebaseAI = FirebaseAI.componentInstance(config)
      let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
      let prompt = "Why is the sky blue?"

      let stream = session.streamResponse(to: prompt, options: .gemini(generationConfig))

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
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          #expect(response.rawContent.kind == .string(content))
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      if let text = response.rawResponse.text {
        #expect(content.hasSuffix(text))
      }
    }

    #if canImport(FoundationModels)
      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func streamResponseGeneratedContent(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt = "Generate a friendly Persian cat"

        let stream = session.streamResponse(
          to: prompt,
          schema: CatProfile.generationSchema,
          options: generationConfig
        )

        var generationID: FirebaseAI.GenerationID?
        var isComplete = false
        for try await snapshot in stream {
          #expect(!isComplete, "Stream yielded more elements after a snapshot was marked complete.")
          let partial = try CatProfile.PartiallyGenerated(snapshot.rawContent)
          if let name = partial.name {
            #expect(!name.isEmpty)
          }
          if let age = partial.age {
            #expect(age >= 1)
            #expect(age <= 20)
          }
          if let profile = partial.profile {
            #expect(!profile.isEmpty)
          }
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
        #expect(
          isComplete, "The stream finished, but the final snapshot was not marked as complete."
        )

        let response = try await stream.collect()
        #expect(response.rawContent.isComplete, "The final response was not marked as complete.")
        #expect(response.rawContent.generationID == generationID)
        let catProfile = try CatProfile(response.content)
        #expect(!catProfile.name.isEmpty)
        #expect(catProfile.age >= 1)
        #expect(catProfile.age <= 20)
        #expect(!catProfile.profile.isEmpty)
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func streamResponseGenerable(_ config: InstanceConfig) async throws {
        let firebaseAI = FirebaseAI.componentInstance(config)
        let session = firebaseAI.generativeModelSession(model: ModelNames.gemini2_5_FlashLite)
        let prompt = "Generate a Ragdoll kitten"
        let config = GenerationConfig(
          thinkingConfig: ThinkingConfig(thinkingBudget: -1, includeThoughts: true)
        )

        let stream = session.streamResponse(
          to: prompt,
          generating: CatProfile.self,
          options: config
        )

        var generationID: FirebaseAI.GenerationID?
        var id: FoundationModels.GenerationID?
        var isComplete = false
        var thoughtSummary = ""
        for try await snapshot in stream {
          #expect(!isComplete, "Stream yielded more elements after a snapshot was marked complete.")
          let partial = snapshot.content
          if let name = partial.name {
            #expect(!name.isEmpty)
          }
          if let age = partial.age {
            #expect(age >= 1)
            #expect(age <= 20)
          }
          if let profile = partial.profile {
            #expect(!profile.isEmpty)
          }
          if let generationID {
            #expect(
              generationID == snapshot.rawContent.generationID,
              "The generation ID was not stable for the duration of the response."
            )
          } else {
            #expect(snapshot.rawContent.generationID != nil)
            generationID = snapshot.rawContent.generationID
          }
          if let id {
            #expect(
              id == snapshot.content.id,
              "The generation ID was not stable for the duration of the response."
            )
          } else {
            id = snapshot.content.id
          }
          if let partialThoughtSummary = snapshot.rawResponse.thoughtSummary {
            thoughtSummary += partialThoughtSummary
          }
          isComplete = snapshot.rawContent.isComplete
        }
        #expect(
          isComplete, "The stream finished, but the final snapshot was not marked as complete."
        )
        #expect(
          !thoughtSummary.isEmpty, "The stream finished, but no thought summary was generated."
        )

        let response = try await stream.collect()
        #expect(response.rawContent.isComplete, "The final response was not marked as complete.")
        #expect(response.rawContent.generationID == generationID)
        let catProfile = response.content
        #expect(!catProfile.name.isEmpty)
        #expect(catProfile.age >= 1)
        #expect(catProfile.age <= 20)
        #expect(!catProfile.profile.isEmpty)
      }

      @Test(arguments: [InstanceConfig.vertexAI_v1beta_global, InstanceConfig.googleAI_v1beta])
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func streamResponseTextWithAutomaticFunctionCalling(_ config: InstanceConfig) async throws {
        let temperatureTool = GetTemperature()
        let session = FirebaseAI.componentInstance(config).generativeModelSession(
          model: ModelNames.gemini3_1_FlashLitePreview,
          tools: [temperatureTool],
          instructions: """
          You are a weather bot that specializes in reporting outdoor temperatures in Celsius.

          Always use the `GetTemperature` function to determine the location's current temperature.

          Always respond in the format:
          - Location: City, Province/State, Country
          - Temperature: #C
          """
        )
        let prompt = "What is the current temperature in Waterloo, Ontario, Canada?"

        let stream = session.streamResponse(to: prompt, options: .gemini(generationConfig))

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
        #expect(
          isComplete, "The stream finished, but the final snapshot was not marked as complete."
        )

        let response = try await stream.collect()
        let content = response.content
        #expect(!content.isEmpty)
        #expect(response.content.contains("Waterloo"))
        #expect(response.content.contains("25"))
        #expect(response.rawContent.isComplete, "The final response was not marked as complete.")
        #expect(response.rawContent.kind == .string(content))
        #expect(response.rawContent.generationID == generationID)
        #expect(response.rawResponse.functionCalls.isEmpty)
      }
    #endif // canImport(FoundationModels)
  }
#endif // compiler(>=6.2.3)
