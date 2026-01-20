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
import Testing

@testable import struct FirebaseAILogic.GenerationConfig

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

  struct CityList {
    let cities: [String]
  }

  @Test(
    arguments: testConfigs(
      instanceConfigs: InstanceConfig.allConfigs,
      openAPISchema: .object(
        properties: [
          "cities": .array(
            items: .string(description: "The name of the city"),
            description: "A list of city names",
            minItems: 3,
            maxItems: 5
          ),
        ],
        title: "CityList"
      ),
      jsonSchema: CityList.jsonSchema
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

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let cityList = try CityList(modelOutput)
    #expect(
      cityList.cities.count >= 3,
      "Expected at least 3 cities, but got \(cityList.cities.count)"
    )
    #expect(
      cityList.cities.count <= 5,
      "Expected at most 5 cities, but got \(cityList.cities.count)"
    )
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeWithArray(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "What are the biggest cities in Canada?"

    let response = try await model.generate(CityList.self, from: prompt)

    let cityList = response.content
    #expect(
      cityList.cities.count >= 3,
      "Expected at least 3 cities, but got \(cityList.cities.count)"
    )
    #expect(
      cityList.cities.count <= 5,
      "Expected at most 5 cities, but got \(cityList.cities.count)"
    )
  }

  struct TestNumber {
    let value: Int
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "value": .integer(
          description: "A number",
          minimum: 110,
          maximum: 120
        ),
      ],
      title: "TestNumber"
    ),
    jsonSchema: TestNumber.jsonSchema
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

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let testNumber = try TestNumber(modelOutput)
    #expect(testNumber.value >= 110, "Expected a number >= 110, but got \(testNumber.value)")
    #expect(testNumber.value <= 120, "Expected a number <= 120, but got \(testNumber.value)")
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeWithNumber(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Give me a number"

    let response = try await model.generate(TestNumber.self, from: prompt)

    let testNumber = response.content
    #expect(testNumber.value >= 110, "Expected a number >= 110, but got \(testNumber.value)")
    #expect(testNumber.value <= 120, "Expected a number <= 120, but got \(testNumber.value)")
  }

  struct ProductInfo {
    let productName: String
    let rating: Int
    let price: Double
    let salePrice: Float
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
    jsonSchema: ProductInfo.jsonSchema
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

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let productInfo = try ProductInfo(modelOutput)
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

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeWithMultipleDataTypes(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Describe a premium wireless headphone, including a user rating and price."

    let response = try await model.generate(ProductInfo.self, from: prompt)

    let productInfo = response.content
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

  struct MailingAddress {
    enum PostalInfo {
      struct Canada {
        let province: String
        let postalCode: String
      }

      struct UnitedStates {
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

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .array(items: {
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

      return Schema.object(properties: [
        "streetAddress": streetSchema,
        "city": citySchema,
        "postalInfo": .anyOf(schemas: [canadaPostalInfoSchema, unitedStatesPostalInfoSchema]),
      ])
    }()),
    jsonSchema: [MailingAddress].jsonSchema
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
    let modelOutput = try ModelOutput(json: text)
    let mailingAddresses = try [MailingAddress](modelOutput)
    try #require(mailingAddresses.count == 3, "Expected 3 JSON addresses, got \(text).")
    let waterlooAddress = mailingAddresses[0]
    #expect(waterlooAddress.city == "Waterloo")
    if case let .canada(province, postalCode) = waterlooAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "N2L 3G1")
    } else {
      Issue.record("Expected Canadian University of Waterloo address, got \(waterlooAddress).")
    }
    let berkeleyAddress = mailingAddresses[1]
    #expect(berkeleyAddress.city == "Berkeley")
    if case let .unitedStates(state, zipCode) = berkeleyAddress.postalInfo {
      #expect(state == "CA")
      #expect(zipCode == "94720")
    } else {
      Issue.record("Expected American UC Berkeley address, got \(berkeleyAddress).")
    }
    let queensAddress = mailingAddresses[2]
    #expect(queensAddress.city == "Kingston")
    if case let .canada(province, postalCode) = queensAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "K7L 3N6")
    } else {
      Issue.record("Expected Canadian Queen's University address, got \(queensAddress).")
    }
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeAnyOf(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = """
    What are the mailing addresses for the University of Waterloo, UC Berkeley and Queen's U?
    """

    let response = try await model.generate([MailingAddress].self, from: prompt)

    let mailingAddresses = response.content
    try #require(
      mailingAddresses.count == 3,
      "Expected 3 JSON addresses, got \(mailingAddresses.count)."
    )
    let waterlooAddress = mailingAddresses[0]
    #expect(waterlooAddress.city == "Waterloo")
    if case let .canada(province, postalCode) = waterlooAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "N2L 3G1")
    } else {
      Issue.record("Expected Canadian University of Waterloo address, got \(waterlooAddress).")
    }
    let berkeleyAddress = mailingAddresses[1]
    #expect(berkeleyAddress.city == "Berkeley")
    if case let .unitedStates(state, zipCode) = berkeleyAddress.postalInfo {
      #expect(state == "CA")
      #expect(zipCode == "94720")
    } else {
      Issue.record("Expected American UC Berkeley address, got \(berkeleyAddress).")
    }
    let queensAddress = mailingAddresses[2]
    #expect(queensAddress.city == "Kingston")
    if case let .canada(province, postalCode) = queensAddress.postalInfo {
      #expect(province == "ON")
      #expect(postalCode == "K7L 3N6")
    } else {
      Issue.record("Expected Canadian Queen's University address, got \(queensAddress).")
    }
  }

  enum SchemaType: CustomTestStringConvertible {
    case openAPI(Schema)
    case json(JSONSchema)

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
                                  jsonSchema: JSONSchema) -> [(InstanceConfig, SchemaType)] {
    return instanceConfigs.flatMap { [($0, .openAPI(openAPISchema)), ($0, .json(jsonSchema))] }
  }
}

// MARK: - FirebaseGenerable Conformances

// TODO: Replace manual implementations with `@FirebaseGenerable` macro.

// MARK: CityList

extension SchemaTests.CityList: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(type: Self.self, properties: [
      .init(
        name: "cities",
        description: "A list of city names",
        type: [String].self,
        guides: [.count(3 ... 5)]
      ),
    ])
  }

  init(_ content: ModelOutput) throws {
    cities = try content.value(forProperty: "cities")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "cities", value: cities)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

// MARK: TestNumber

extension SchemaTests.TestNumber: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(
      type: Self.self,
      properties: [
        .init(
          name: "value",
          description: "A number",
          type: Int.self,
          guides: [.minimum(110), .maximum(120)]
        ),
      ]
    )
  }

  init(_ content: ModelOutput) throws {
    value = try content.value(forProperty: "value")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "value", value: value)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

// MARK: ProductInfo

extension SchemaTests.ProductInfo: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(
      type: Self.self,
      properties: [
        .init(
          name: "salePrice",
          description: "A sale price",
          type: Float.self,
          guides: [.minimum(5.00), .maximum(90.00)]
        ),
        .init(name: "rating", description: "A rating", type: Int.self, guides: [.range(1 ... 5)]),
        .init(
          name: "price",
          description: "A price",
          type: Double.self,
          guides: [.minimum(10.00), .maximum(120.00)]
        ),
        .init(name: "productName", description: "The name of the product", type: String.self),
      ]
    )
  }

  init(_ content: ModelOutput) throws {
    productName = try content.value(forProperty: "productName")
    rating = try content.value(forProperty: "rating")
    price = try content.value(forProperty: "price")
    salePrice = try content.value(forProperty: "salePrice")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "productName", value: productName)
    addProperty(name: "rating", value: rating)
    addProperty(name: "price", value: price)
    addProperty(name: "salePrice", value: salePrice)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

// MARK: MailingAddress

extension SchemaTests.MailingAddress.PostalInfo.Canada: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(type: Self.self, properties: [
      .init(
        name: "province",
        description: "The 2-letter province or territory code, for example, 'ON', 'QC', or 'NU'.",
        type: String.self
      ),
      .init(
        name: "postalCode",
        description: "The postal code, for example, 'A1A 1A1'.",
        type: String.self
      ),
    ])
  }

  init(_ content: ModelOutput) throws {
    province = try content.value(forProperty: "province")
    postalCode = try content.value(forProperty: "postalCode")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "province", value: province)
    addProperty(name: "postalCode", value: postalCode)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

extension SchemaTests.MailingAddress.PostalInfo.UnitedStates: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(type: Self.self, properties: [
      .init(
        name: "state",
        description: "The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'.",
        type: String.self
      ),
      .init(
        name: "zipCode",
        description: "The 5-digit ZIP code, for example, '12345'.",
        type: String.self
      ),
    ])
  }

  init(_ content: ModelOutput) throws {
    state = try content.value(forProperty: "state")
    zipCode = try content.value(forProperty: "zipCode")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "state", value: state)
    addProperty(name: "zipCode", value: zipCode)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

extension SchemaTests.MailingAddress.PostalInfo: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(type: Self.self, anyOf: [Canada.self, UnitedStates.self])
  }

  init(_ content: ModelOutput) throws {
    if let province = try content.value(String?.self, forProperty: "province"),
       let postalCode = try content.value(String?.self, forProperty: "postalCode") {
      self = .canada(province: province, postalCode: postalCode)
    } else if let state = try content.value(String?.self, forProperty: "state"),
              let zipCode = try content.value(
                String?.self, forProperty: "zipCode"
              ) {
      self = .unitedStates(state: state, zipCode: zipCode)
    } else {
      throw GenerativeModel.GenerationError.decodingFailure(
        GenerativeModel.GenerationError.Context(
          debugDescription: "Unexpected type \"\(Self.self)\" from: \(content.debugDescription)"
        )
      )
    }
  }

  var modelOutput: ModelOutput {
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }

    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    switch self {
    case let .canada(province, postalCode):
      addProperty(name: "province", value: province)
      addProperty(name: "postalCode", value: postalCode)
    case let .unitedStates(state, zipCode):
      addProperty(name: "state", value: state)
      addProperty(name: "zipCode", value: zipCode)
    }
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
  }
}

extension SchemaTests.MailingAddress: FirebaseGenerable {
  static var jsonSchema: FirebaseAILogic.JSONSchema {
    JSONSchema(type: Self.self, description: "A mailing address", properties: [
      .init(
        name: "streetAddress",
        description: "The civic number and street name, for example, '123 Main Street'.",
        type: String.self
      ),
      .init(name: "city", description: "The name of the city.", type: String.self),
      .init(name: "postalInfo", type: PostalInfo.self),
    ])
  }

  init(_ content: ModelOutput) throws {
    streetAddress = try content.value(forProperty: "streetAddress")
    city = try content.value(forProperty: "city")
    postalInfo = try content.value(forProperty: "postalInfo")
  }

  var modelOutput: ModelOutput {
    var properties = [(name: String, value: any ConvertibleToModelOutput)]()
    addProperty(name: "streetAddress", value: streetAddress)
    addProperty(name: "city", value: city)
    addProperty(name: "postalInfo", value: postalInfo)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}
