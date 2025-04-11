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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseVertexAI
import Testing
import VertexAITestApp

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

@testable import struct FirebaseVertexAI.BackendError

@Suite(.serialized)
/// Test the schema fields.
struct SchemaTests {
  // Set temperature, topP and topK to lowest allowed values to make responses more deterministic.
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]
  // Candidates and total token counts may differ slightly between runs due to whitespace tokens.
  let tokenCountAccuracy = 1

  let storage: Storage
  let userID1: String

  init() async throws {
    userID1 = try await TestHelpers.getUserID()
    storage = Storage.storage()
  }

  @Test(arguments: InstanceConfig.allConfigsExceptDeveloperV1)
  func generateContentSchemaItems(_ config: InstanceConfig) async throws {
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema:
            .array(
              items: .string(description: "The name of the city"),
              description: "A list of city names",
              minItems: 3,
              maxItems: 5
            )
      ),
      safetySettings: safetySettings
    )
    let prompt = "What are the biggest cities in Canada?"
    let response = try await model.generateContent(prompt)
    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonData = try #require(text.data(using: .utf8))
    let decodedJSON = try JSONDecoder().decode([String].self, from: jsonData)
    #expect(decodedJSON.count >= 3, "Expected at least 3 cities, but got \(decodedJSON.count)")
    #expect(decodedJSON.count <= 5, "Expected at most 5 cities, but got \(decodedJSON.count)")
  }
}
