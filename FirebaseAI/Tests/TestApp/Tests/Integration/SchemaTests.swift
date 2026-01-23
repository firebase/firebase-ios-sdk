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
import FirebaseAILogicMacro
import FirebaseAITestApp
import Foundation
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

  @FirebaseGenerable
  struct CityList {
    @FirebaseGuide(description: "A list of city names", .count(3 ... 5))
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

  @FirebaseGenerable
  struct TestNumber {
    @FirebaseGuide(description: "A number", .minimum(110), .maximum(120))
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

  @FirebaseGenerable
  struct ProductInfo {
    @FirebaseGuide(description: "The name of the product")
    let productName: String
    @FirebaseGuide(description: "A rating", .range(1 ... 5))
    let rating: Int
    @FirebaseGuide(description: "A price", .minimum(10.00), .maximum(120.00))
    let price: Double
    @FirebaseGuide(description: "A sale price", .minimum(5.00), .maximum(90.00))
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

  @FirebaseGenerable
  struct MailingAddress {
    enum PostalInfo {
      @FirebaseGenerable
      struct Canada {
        @FirebaseGuide(description: """
        The 2-letter province or territory code, for example, 'ON', 'QC', or 'NU'.
        """)
        let province: String
        @FirebaseGuide(description: "The postal code, for example, 'A1A 1A1'.")
        let postalCode: String
      }

      @FirebaseGenerable
      struct UnitedStates {
        @FirebaseGuide(description: """
        The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'.
        """)
        let state: String
        @FirebaseGuide(description: "The 5-digit ZIP code, for example, '12345'.")
        let zipCode: String
      }

      case canada(province: String, postalCode: String)
      case unitedStates(state: String, zipCode: String)
    }

    @FirebaseGuide(description: "The civic number and street name, for example, '123 Main Street'.")
    let streetAddress: String
    @FirebaseGuide(description: "The name of the city.")
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

  @FirebaseGenerable
  struct FeatureToggle {
    @FirebaseGuide(description: "Whether the experimental feature should be active")
    let isEnabled: Bool
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "isEnabled": .boolean(description: "Whether the experimental feature should be active"),
      ],
      title: "FeatureToggle"
    ),
    jsonSchema: FeatureToggle.jsonSchema
  ))
  func generateContentBoolean(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Should the experimental feature be active? Answer yes."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let featureToggle = try FeatureToggle(modelOutput)
    #expect(featureToggle.isEnabled)
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeBoolean(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Should the experimental feature be active? Answer yes."

    let response = try await model.generate(FeatureToggle.self, from: prompt)

    let featureToggle = response.content
    #expect(featureToggle.isEnabled)
  }

  @FirebaseGenerable
  struct UserProfile {
    let username: String
    @FirebaseGuide(description: "The user's optional middle name")
    let middleName: String?
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "username": .string(),
        "middleName": .string(description: "The user's optional middle name", nullable: true),
      ],
      optionalProperties: ["middleName"],
      title: "UserProfile"
    ),
    jsonSchema: UserProfile.jsonSchema
  ))
  func generateContentOptional(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Create a user profile for 'jdoe' without a middle name."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let userProfile = try UserProfile(modelOutput)
    #expect(userProfile.username == "jdoe")
    #expect(userProfile.middleName == nil)
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeOptional(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Create a user profile for 'jdoe' without a middle name."

    let response = try await model.generate(UserProfile.self, from: prompt)

    let userProfile = response.content
    #expect(userProfile.username == "jdoe")
    #expect(userProfile.middleName == nil)
  }

  @FirebaseGenerable
  struct Task {
    let title: String
    @FirebaseGuide(description: "The priority level", .anyOf(["low", "medium", "high"]))
    let priority: String
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "title": .string(),
        "priority": .enumeration(
          values: ["low", "medium", "high"],
          description: "The priority level"
        ),
      ],
      title: "Task"
    ),
    jsonSchema: Task.jsonSchema
  ))
  func generateContentStringEnum(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Create a high priority task titled 'Fix Bug'."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let task = try Task(modelOutput)
    #expect(task.title == "Fix Bug")
    #expect(task.priority == "high")
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeStringEnum(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Create a high priority task titled 'Fix Bug'."

    let response = try await model.generate(Task.self, from: prompt)

    let task = response.content
    #expect(task.title == "Fix Bug")
    #expect(task.priority == "high")
  }

  @FirebaseGenerable
  struct GradeBook {
    @FirebaseGuide(description: "A list of exam scores", .element(.range(0 ... 100)))
    let scores: [Int]
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "scores": .array(
          items: .integer(minimum: 0, maximum: 100),
          description: "A list of exam scores"
        ),
      ],
      title: "GradeBook"
    ),
    jsonSchema: GradeBook.jsonSchema
  ))
  func generateContentArrayConstraints(_ config: InstanceConfig,
                                       _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Generate a gradebook with scores 95, 80, and 100."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let gradeBook = try GradeBook(modelOutput)
    #expect(gradeBook.scores.count == 3)
    for score in gradeBook.scores {
      #expect(score >= 0 && score <= 100)
    }
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeArrayConstraints(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate a gradebook with scores 95, 80, and 100."

    let response = try await model.generate(GradeBook.self, from: prompt)

    let gradeBook = response.content
    #expect(gradeBook.scores.count == 3)
    for score in gradeBook.scores {
      #expect(score >= 0 && score <= 100)
    }
  }

  @FirebaseGenerable
  struct Catalog {
    let name: String
    let categories: [Category]

    @FirebaseGenerable
    struct Category {
      let title: String
      let items: [Item]

      @FirebaseGenerable
      struct Item {
        let name: String
        let price: Double
      }
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "name": .string(),
        "categories": .array(items: .object(
          properties: [
            "title": .string(),
            "items": .array(items: .object(
              properties: [
                "name": .string(),
                "price": .double(),
              ],
              title: "Item"
            )),
          ],
          title: "Category"
        )),
      ],
      title: "Catalog"
    ),
    jsonSchema: Catalog.jsonSchema
  ))
  func generateContentNesting(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = """
    Create a catalog named 'Tech' with a category 'Computers' containing an item 'Laptop' for 999.99.
    """

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let catalog = try Catalog(modelOutput)
    #expect(catalog.name == "Tech")
    #expect(catalog.categories.count == 1)
    #expect(catalog.categories[0].title == "Computers")
    #expect(catalog.categories[0].items.count == 1)
    #expect(catalog.categories[0].items[0].name == "Laptop")
    #expect(catalog.categories[0].items[0].price == 999.99)
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeNesting(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = """
    Create a catalog named 'Tech' with a category 'Computers' containing an item 'Laptop' for 999.99.
    """

    let response = try await model.generate(Catalog.self, from: prompt)

    let catalog = response.content
    #expect(catalog.name == "Tech")
    #expect(catalog.categories.count == 1)
    #expect(catalog.categories[0].title == "Computers")
    #expect(catalog.categories[0].items.count == 1)
    #expect(catalog.categories[0].items[0].name == "Laptop")
    #expect(catalog.categories[0].items[0].price == 999.99)
  }

  @FirebaseGenerable
  struct Statement {
    @FirebaseGuide(description: "The total balance", .minimum(0.0))
    let balance: Decimal
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "balance": .double(description: "The total balance", minimum: 0.0),
      ],
      title: "Statement"
    ),
    jsonSchema: Statement.jsonSchema
  ))
  func generateContentDecimal(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Generate a statement with balance 123.45."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let statement = try Statement(modelOutput)
    #expect(statement.balance == Decimal(123.45))
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeDecimal(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate a statement with balance 123.45."

    let response = try await model.generate(Statement.self, from: prompt)

    let statement = response.content
    #expect(statement.balance == Decimal(123.45))
  }

  @FirebaseGenerable
  struct Metadata {
    @FirebaseGuide(description: "Optional tags, up to 3", .count(0 ... 3))
    let tags: [String]
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "tags": .array(
          items: .string(),
          description: "Optional tags, up to 3",
          minItems: 0,
          maxItems: 3
        ),
      ],
      title: "Metadata"
    ),
    jsonSchema: Metadata.jsonSchema
  ))
  func generateContentEmptyCollection(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Generate metadata with no tags."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let metadata = try Metadata(modelOutput)
    #expect(metadata.tags.isEmpty)
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeEmptyCollection(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Generate metadata with no tags."

    let response = try await model.generate(Metadata.self, from: prompt)

    let metadata = response.content
    #expect(metadata.tags.isEmpty)
  }

  @FirebaseGenerable
  struct ConstrainedValue {
    @FirebaseGuide(description: "A value between 10 and 20", .minimum(10), .maximum(20))
    let value: Int
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "value": .integer(description: "A value between 10 and 20", minimum: 10, maximum: 20),
      ],
      title: "ConstrainedValue"
    ),
    jsonSchema: ConstrainedValue.jsonSchema
  ))
  func generateContentCombinedGuides(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Give me the value 15."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let modelOutput = try ModelOutput(json: text)
    let constrainedValue = try ConstrainedValue(modelOutput)
    #expect(constrainedValue.value == 15)
  }

  @Test(arguments: InstanceConfig.allConfigs)
  func generateTypeCombinedGuides(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
    let prompt = "Give me the value 15."

    let response = try await model.generate(ConstrainedValue.self, from: prompt)

    let constrainedValue = response.content
    #expect(constrainedValue.value == 15)
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(properties: ["value": .integer()], title: "TestNumber"),
    jsonSchema: TestNumber.jsonSchema
  ))
  func generateContentErrorHandling(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    // Since we are adding integration tests, let's verify that providing a JSON with a property of
    // the wrong type fails to decode.
    let invalidJson = """
    { "value": "not an int" }
    """
    let modelOutput = try ModelOutput(json: invalidJson)
    #expect(throws: Error.self) {
      _ = try TestNumber(modelOutput)
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(properties: ["value": .integer()], title: "TestNumber"),
    jsonSchema: TestNumber.jsonSchema
  ))
  func generateContentMissingFieldFailure(_ config: InstanceConfig,
                                          _ schema: SchemaType) async throws {
    // Verify that providing a JSON that is missing a required field fails.
    let invalidJson = """
    { "otherField": 123 }
    """
    let modelOutput = try ModelOutput(json: invalidJson)
    #expect(throws: Error.self) {
      _ = try TestNumber(modelOutput)
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

// MARK: PostalInfo

// TODO: Replace manual implementation with macro when enums with associated values are supported.

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
