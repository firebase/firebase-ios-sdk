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
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)

  @Test(
    arguments: testConfigs(
      instanceConfigs: InstanceConfig.allConfigs,
      openAPISchema: .array(
        items: .string(description: "The name of the city"),
        description: "A list of city names",
        minItems: 3,
        maxItems: 5
      ),
      jsonSchema: [
        "type": .string("array"),
        "description": .string("A list of city names"),
        "items": .object([
          "type": .string("string"),
          "description": .string("The name of the city"),
        ]),
        "minItems": .number(3),
        "maxItems": .number(5),
      ]
    )
  )
  func generateContentItemsSchema(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
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

  struct CityList: Decodable, SchemaConstraintsProvider {
    let cities: [String]

    static var schemaConstraints: [AnyHashable: SchemaConstraint] {
      [CodingKeys.cities: .array(minItems: 3, maxItems: 5, description: "A list of city names")]
    }
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateObjectItemsSchema(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "What are the biggest cities in Canada?"

    let response = try await model.generateObject(CityList.self, prompt: prompt)
    let cityList = try #require(try response.getObject())

    let cities = cityList.cities
    #expect(cities.count >= 3, "Expected at least 3 cities, but got \(cities.count)")
    #expect(cities.count <= 5, "Expected at most 5 cities, but got \(cities.count)")
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .integer(
      description: "A number",
      minimum: 110,
      maximum: 120
    ),
    jsonSchema: [
      "type": .string("integer"),
      "description": .string("A number"),
      "minimum": .number(110),
      "maximum": .number(120),
    ]
  ))
  func generateContentSchemaNumberRange(_ config: InstanceConfig,
                                        _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
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

  struct ProductInfo: Decodable, SchemaConstraintsProvider {
    let productName: String
    let rating: Int
    let price: Double
    let salePrice: Float

    static var schemaConstraints: [AnyHashable: SchemaConstraint] {
      [
        CodingKeys.productName: .string(description: "The name of the product"),
        CodingKeys.rating: .integer(1 ... 5, description: "A rating"),
        CodingKeys.price: .number(min: 10.00, max: 120.00, description: "A price"),
        CodingKeys.salePrice: .number(min: 5.00, max: 90.00, description: "A sale price"),
      ]
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
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
    jsonSchema: [
      "type": .string("object"),
      "title": .string("ProductInfo"),
      "properties": .object([
        "productName": .object([
          "type": .string("string"),
          "description": .string("The name of the product"),
        ]),
        "price": .object([
          "type": .string("number"),
          "description": .string("A price"),
          "minimum": .number(10.00),
          "maximum": .number(120.00),
        ]),
        "salePrice": .object([
          "type": .string("number"),
          "description": .string("A sale price"),
          "minimum": .number(5.00),
          "maximum": .number(90.00),
        ]),
        "rating": .object([
          "type": .string("integer"),
          "description": .string("A rating"),
          "minimum": .number(1),
          "maximum": .number(5),
        ]),
      ]),
      "required": .array([
        .string("productName"),
        .string("price"),
        .string("salePrice"),
        .string("rating"),
      ]),
      "propertyOrdering": .array([
        .string("salePrice"),
        .string("rating"),
        .string("price"),
        .string("productName"),
      ]),
    ]
  ))
  func generateContentSchemaNumberRangeMultiType(_ config: InstanceConfig,
                                                 _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
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
  func generateObjectSchemaNumberRangeMultiType(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Describe a premium wireless headphone, including a user rating and price."

    let response = try await model.generateObject(ProductInfo.self, prompt: prompt)
    let productInfo = try #require(try response.getObject())

    let price = productInfo.price
    let salePrice = productInfo.salePrice
    let rating = productInfo.rating
    #expect(price >= 10.0, "Expected a price >= 10.00, but got \(price)")
    #expect(price <= 120.0, "Expected a price <= 120.00, but got \(price)")
    #expect(salePrice >= 5.0, "Expected a salePrice >= 5.00, but got \(salePrice)")
    #expect(salePrice <= 90.0, "Expected a salePrice <= 90.00, but got \(salePrice)")
    #expect(rating >= 1, "Expected a rating >= 1, but got \(rating)")
    #expect(rating <= 5, "Expected a rating <= 5, but got \(rating)")
  }

  fileprivate struct MailingAddress {
    enum PostalInfo {
      struct Canada: Decodable {
        let province: String
        let postalCode: String
      }

      struct UnitedStates: Decodable {
        let state: String
        let zipCode: String
      }

      case canada(province: String, postalCode: String)
      case unitedStates(state: String, zipCode: String)
    }

    let streetAddress: String
    let city: String
    let postalInfo: PostalInfo
  }

  private static let generateContentAnyOfOpenAPISchema = {
    let streetSchema = Schema.string(description:
      "The civic number and street name, for example, '123 Main Street'.")
    let citySchema = Schema.string(description: "The name of the city.")
    let canadaPostalInfoSchema = Schema.object(
      properties: [
        "province": .string(description:
          "The 2-letter province or territory code, for example, 'ON', 'QC', or 'NU'."),
        "postalCode": .string(description: "The postal code, for example, 'A1A 1A1'."),
      ]
    )
    let unitedStatesPostalInfoSchema = Schema.object(
      properties: [
        "state": .string(description:
          "The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'."),
        "zipCode": .string(description: "The 5-digit ZIP code, for example, '12345'."),
      ]
    )
    let mailingAddressSchema = Schema.object(properties: [
      "streetAddress": streetSchema,
      "city": citySchema,
      "postalInfo": .anyOf(schemas: [canadaPostalInfoSchema, unitedStatesPostalInfoSchema]),
    ])
    return Schema.array(items: mailingAddressSchema)
  }()

  private static let generateContentAnyOfJSONSchema = {
    let streetSchema: JSONValue = .object([
      "type": .string("string"),
      "description": .string("The civic number and street name, for example, '123 Main Street'."),
    ])
    let citySchema: JSONValue = .object([
      "type": .string("string"),
      "description": .string("The name of the city."),
    ])
    let postalInfoSchema: JSONValue = .object([
      "anyOf": .array([
        .object([
          "type": .string("object"),
          "properties": .object([
            "province": .object([
              "type": .string("string"),
              "description": .string(
                "The 2-letter Canadian province or territory code, for example, 'ON', 'QC', or 'NU'."
              ),
            ]),
            "postalCode": .object([
              "type": .string("string"),
              "description": .string("The Canadian postal code, for example, 'A1A 1A1'."),
            ]),
          ]),
          "required": .array([.string("province"), .string("postalCode")]),
        ]),
        .object([
          "type": .string("object"),
          "properties": .object([
            "state": .object([
              "type": .string("string"),
              "description": .string(
                "The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'."
              ),
            ]),
            "zipCode": .object([
              "type": .string("string"),
              "description": .string("The 5-digit U.S. ZIP code, for example, '12345'."),
            ]),
          ]),
          "required": .array([.string("state"), .string("zipCode")]),
        ]),
      ]),
    ])
    let mailingAddressSchema: JSONObject = [
      "type": .string("object"),
      "description": .string("A mailing address"),
      "properties": .object([
        "streetAddress": streetSchema,
        "city": citySchema,
        "postalInfo": postalInfoSchema,
      ]),
      "required": .array([
        .string("streetAddress"),
        .string("city"),
        .string("postalInfo"),
      ]),
    ]
    return [
      "type": .string("array"),
      "items": .object(mailingAddressSchema),
    ] as JSONObject
  }()

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: generateContentAnyOfOpenAPISchema,
    jsonSchema: generateContentAnyOfJSONSchema
  ))
  func generateContentAnyOfSchema(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      generationConfig: SchemaTests.generationConfig(schema: schema),
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
    #expect(waterlooAddress.city == "Waterloo")
    if case let .canada(province, postalCode) = waterlooAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "N2L 3G1")
    } else {
      Issue.record("Expected Canadian University of Waterloo address, got \(waterlooAddress).")
    }
    let berkeleyAddress = decodedAddresses[1]
    #expect(berkeleyAddress.city == "Berkeley")
    if case let .unitedStates(state, zipCode) = berkeleyAddress.postalInfo {
      #expect(state == "CA")
      #expect(zipCode == "94720")
    } else {
      Issue.record("Expected American UC Berkeley address, got \(berkeleyAddress).")
    }
    let queensAddress = decodedAddresses[2]
    #expect(queensAddress.city == "Kingston")
    if case let .canada(province, postalCode) = queensAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "K7L 3N6")
    } else {
      Issue.record("Expected Canadian Queen's University address, got \(queensAddress).")
    }
  }

  struct Catalog: Decodable {
    let name: String
    let categories: [Category]

    struct Category: Decodable {
      let title: String
      let items: [Item]

      struct Item: Decodable {
        let name: String
        let price: Double
      }
    }
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateObjectSchemaNestedTypes(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = """
    Create a catalog named 'Tech' with a category 'Computers' containing an item 'Laptop' for \
    $999.99.
    """

    let response = try await model.generateObject(Catalog.self, prompt: prompt)
    let catalog = try #require(try response.getObject())

    #expect(catalog.name == "Tech")
    #expect(catalog.categories.count == 1)
    #expect(catalog.categories[0].title == "Computers")
    #expect(catalog.categories[0].items.count == 1)
    #expect(catalog.categories[0].items[0].name == "Laptop")
    #expect(catalog.categories[0].items[0].price == 999.99)
  }

  enum SchemaType: CustomTestStringConvertible {
    case openAPI(Schema)
    case json(JSONObject)

    var testDescription: String {
      switch self {
      case .openAPI:
        return "OpenAPI Schema"
      case .json:
        return "JSON Schema"
      }
    }
  }

  private static func generationConfig(schema: SchemaType) -> GenerationConfig {
    let mimeType = "application/json"
    switch schema {
    case let .openAPI(openAPISchema):
      return GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1, responseMIMEType: mimeType,
                              responseSchema: openAPISchema)
    case let .json(jsonSchema):
      return GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1, responseMIMEType: mimeType,
                              responseJSONSchema: jsonSchema)
    }
  }

  private static func testConfigs(instanceConfigs: [InstanceConfig], openAPISchema: Schema,
                                  jsonSchema: JSONObject) -> [(InstanceConfig, SchemaType)] {
    return instanceConfigs.flatMap { [($0, .openAPI(openAPISchema)), ($0, .json(jsonSchema))] }
  }
}

extension SchemaTests.MailingAddress: Decodable {
  enum CodingKeys: CodingKey {
    case streetAddress
    case city
    case postalInfo
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    streetAddress = try container.decode(String.self, forKey: .streetAddress)
    city = try container.decode(String.self, forKey: .city)
    let canadaPostalInfo = try? container.decode(PostalInfo.Canada.self, forKey: .postalInfo)
    let unitedStatesPostalInfo = try? container.decode(
      PostalInfo.UnitedStates.self, forKey: .postalInfo
    )

    if canadaPostalInfo != nil, unitedStatesPostalInfo != nil {
      throw DecodingError.dataCorruptedError(
        forKey: .postalInfo,
        in: container,
        debugDescription: "Ambiguous postal info: matches both Canadian and U.S. formats."
      )
    }

    if let canadaPostalInfo {
      postalInfo = .canada(
        province: canadaPostalInfo.province, postalCode: canadaPostalInfo.postalCode
      )
    } else if let unitedStatesPostalInfo {
      postalInfo = .unitedStates(
        state: unitedStatesPostalInfo.state, zipCode: unitedStatesPostalInfo.zipCode
      )
    } else {
      throw DecodingError.typeMismatch(
        PostalInfo.self, .init(
          codingPath: container.codingPath,
          debugDescription: "Expected Canadian or U.S. postal info."
        )
      )
    }
  }
}
