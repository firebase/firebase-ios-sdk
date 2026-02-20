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
    #expect(response.rawContent.kind == .string(content))
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
    let name: String = try content.value(forProperty: "name")
    #expect(!name.isEmpty)
    let age: Int = try content.value(forProperty: "age")
    #expect(age >= 1)
    #expect(age <= 20)
    let profile: String = try content.value(forProperty: "profile")
    #expect(!profile.isEmpty)
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
  }
}
