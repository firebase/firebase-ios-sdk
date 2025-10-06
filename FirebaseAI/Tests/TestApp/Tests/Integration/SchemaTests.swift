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
import FirebaseStorage
import Testing

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

@testable import struct FirebaseAILogic.BackendError

/// Test the schema fields.
@Suite(.serialized)
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

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContentSchemaItems(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
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

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContentSchemaNumberRange(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2FlashLite,
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: .integer(
          description: "A number",
          minimum: 110,
          maximum: 120
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

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContentSchemaNumberRangeMultiType(_ config: InstanceConfig) async throws {
    struct ProductInfo: Codable {
      let productName: String
      let rating: Int // Will correspond to .integer in schema
      let price: Double // Will correspond to .double in schema
      let salePrice: Float // Will correspond to .float in schema
    }
    let model = FirebaseAI.componentInstance(config).generativeModel(
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

  @Test(arguments: InstanceConfig.allConfigs)
  func generateContentAnyOfSchema(_ config: InstanceConfig) async throws {
    struct MailingAddress: Decodable {
      let streetAddress: String
      let city: String

      // Canadian-specific
      let province: String?
      let postalCode: String?

      // U.S.-specific
      let state: String?
      let zipCode: String?

      var isCanadian: Bool {
        return province != nil && postalCode != nil && state == nil && zipCode == nil
      }

      var isAmerican: Bool {
        return province == nil && postalCode == nil && state != nil && zipCode != nil
      }
    }

    let streetSchema = Schema.string(description:
      "The civic number and street name, for example, '123 Main Street'.")
    let citySchema = Schema.string(description: "The name of the city.")
    let canadianAddressSchema = Schema.object(
      properties: [
        "streetAddress": streetSchema,
        "city": citySchema,
        "province": .string(description:
          "The 2-letter province or territory code, for example, 'ON', 'QC', or 'NU'."),
        "postalCode": .string(description: "The postal code, for example, 'A1A 1A1'."),
      ],
      description: "A Canadian mailing address"
    )
    let americanAddressSchema = Schema.object(
      properties: [
        "streetAddress": streetSchema,
        "city": citySchema,
        "state": .string(description:
          "The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'."),
        "zipCode": .string(description: "The 5-digit ZIP code, for example, '12345'."),
      ],
      description: "A U.S. mailing address"
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2Flash,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        topP: 0.0,
        topK: 1,
        responseMIMEType: "application/json",
        responseSchema: .array(items: .anyOf(
          schemas: [canadianAddressSchema, americanAddressSchema]
        ))
      ),
      safetySettings: safetySettings
    )
    let prompt = """
    What are the mailing addresses for the University of Waterloo, UC Berkeley and Queen's U?
    """
    let response = try await model.generateContent(prompt)
    let text = try #require(response.text)
    let jsonData = try #require(text.data(using: .utf8))
    let decodedAddresses = try JSONDecoder().decode([MailingAddress].self, from: jsonData)
    try #require(decodedAddresses.count == 3, "Expected 3 JSON addresses, got \(text).")
    let waterlooAddress = decodedAddresses[0]
    #expect(
      waterlooAddress.isCanadian,
      "Expected Canadian University of Waterloo address, got \(waterlooAddress)."
    )
    let berkeleyAddress = decodedAddresses[1]
    #expect(
      berkeleyAddress.isAmerican,
      "Expected American UC Berkeley address, got \(berkeleyAddress)."
    )
    let queensAddress = decodedAddresses[2]
    #expect(
      queensAddress.isCanadian,
      "Expected Canadian Queen's University address, got \(queensAddress)."
    )
  }
}
