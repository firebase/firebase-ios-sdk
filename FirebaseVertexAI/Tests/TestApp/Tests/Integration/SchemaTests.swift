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

  @Test(arguments: InstanceConfig.allConfigsExceptDeveloperV1)
  func generateContentSchemaNumberRange(_ config: InstanceConfig) async throws {
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: .double(
          description: "A number",
          minimum: 110.0,
          maximum: 120.0
        )
      ),
      safetySettings: safetySettings
    )
    let prompt = "Give me a number"
    let response = try await model.generateContent(prompt)
    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonData = try #require(text.data(using: .utf8))
    let decodedNumber = try JSONDecoder().decode(Double.self, from: jsonData)
    #expect(decodedNumber >= 110.0, "Expected a number >= 110, but got \(decodedNumber)")
    #expect(decodedNumber <= 120.0, "Expected a number <= 120, but got \(decodedNumber)")
  }

  @Test(arguments: InstanceConfig.allConfigsExceptDeveloperV1)
  func generateContentSchemaNumberRangeMultiType(_ config: InstanceConfig) async throws {
    struct ProductInfo: Codable {
      let productName: String
      let rating: Int // Will correspond to .integer in schema
      let price: Double // Will correspond to .double in schema
      let salePrice: Float // Will correspond to .float in schema
    }
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: .object(
          properties: [
            "productName": .string(description: "The name of the product"),
            "price": .double(
              description: "A price",
              minimum: 10.00,
              maximum: 120.00
            ),
            "salePrice": .float(
              description: "A sale price",
              minimum: 5.00,
              maximum: 90.00
            ),
            "rating": .integer(
              description: "A rating",
              minimum: 1,
              maximum: 5
            ),
          ],
          propertyOrdering: ["salePrice", "rating", "price", "productName"],
          title: "ProductInfo"
        ),
      ),
      safetySettings: safetySettings
    )
    let prompt = "Describe a premium wireless headphone, including a user rating and price."
    let response = try await model.generateContent(prompt)
    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonData = try #require(text.data(using: .utf8))
    let decodedProduct = try JSONDecoder().decode(ProductInfo.self, from: jsonData)
    let price = decodedProduct.price
    let salePrice = decodedProduct.salePrice
    let rating = decodedProduct.rating
    #expect(price >= 10.0, "Expected a price >= 10.00, but got \(price)")
    #expect(price <= 120.0, "Expected a price <= 120.00, but got \(price)")
    #expect(salePrice >= 5.0, "Expected a salePrice >= 5.00, but got \(salePrice)")
    #expect(salePrice <= 90.0, "Expected a salePrice <= 90.00, but got \(salePrice)")
    #expect(rating >= 1, "Expected a rating >= 1, but got \(rating)")
    #expect(rating <= 5, "Expected a rating <= 5, but got \(rating)")
  }
}
