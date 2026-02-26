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

// TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
#if compiler(>=6.2) && canImport(FoundationModels)
  import FirebaseAILogic
  import FirebaseAITestApp
  import FoundationModels
  import Testing

  @Suite(.serialized)
  struct GenerativeModelSessionTests {
    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondText(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Why is the sky blue?"

      let response = try await session.respond(to: prompt)

      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.kind == .string(content))
      #expect(response.rawContent.generationID != nil)
      #expect(response.rawResponse.text == content)
    }

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

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGeneratedContent(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Generate a cute rescue cat"

      let response = try await session.respond(to: prompt, schema: CatProfile.generationSchema)

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

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGenerable(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Generate a Ragdoll kitten"

      let response = try await session.respond(to: prompt, generating: CatProfile.self)

      let catProfile = response.content
      #expect(!catProfile.name.isEmpty)
      #expect(catProfile.age >= 1)
      #expect(catProfile.age <= 20)
      #expect(!catProfile.profile.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID != nil)
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

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGenerableRecipe(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Generate a recipe for a pasta dish with meat."

      let response = try await session.respond(to: prompt, generating: Recipe.self)

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

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func respondGenerableRecipeList(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt =
        "Generate three recipes for a full-course vegetarian meal (appetizer, main, dessert)."

      let response = try await session.respond(to: prompt, generating: RecipeList.self)

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

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func streamResponseText(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Why is the sky blue?"

      let stream = session.streamResponse(to: prompt)

      var generationID: FirebaseAI.GenerationID?
      for try await snapshot in stream {
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
      }

      let response = try await stream.collect()
      let content = response.content
      #expect(!content.isEmpty)
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID == generationID)
      #expect(response.rawContent.kind == .string(content))
      if let text = response.rawResponse.text {
        #expect(content.hasSuffix(text))
      }
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func streamResponseGeneratedContent(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Generate a friendly Persian cat"

      let stream = session.streamResponse(
        to: prompt,
        schema: CatProfile.generationSchema
      )

      var generationID: FirebaseAI.GenerationID?
      for try await snapshot in stream {
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
      }

      let response = try await stream.collect()
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID == generationID)
      let catProfile = try CatProfile(response.content)
      #expect(!catProfile.name.isEmpty)
      #expect(catProfile.age >= 1)
      #expect(catProfile.age <= 20)
      #expect(!catProfile.profile.isEmpty)
    }

    @Test(arguments: [InstanceConfig.vertexAI_v1beta_global])
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func streamResponseGenerable(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
      )
      let session = GenerativeModelSession(model: model)
      let prompt = "Generate a Ragdoll kitten"

      let stream = session.streamResponse(
        to: prompt,
        generating: CatProfile.self
      )

      var generationID: FirebaseAI.GenerationID?
      var id: FoundationModels.GenerationID?
      for try await snapshot in stream {
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
      }

      let response = try await stream.collect()
      #expect(response.rawContent.isComplete)
      #expect(response.rawContent.generationID == generationID)
      let catProfile = response.content
      #expect(!catProfile.name.isEmpty)
      #expect(catProfile.age >= 1)
      #expect(catProfile.age <= 20)
      #expect(!catProfile.profile.isEmpty)
    }
  }
#endif // compiler(>=6.2) && canImport(FoundationModels)
