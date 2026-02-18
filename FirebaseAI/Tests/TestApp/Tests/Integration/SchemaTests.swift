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

  @Generable
  struct CityList {
    @Guide(description: "A list of city names", .count(3 ... 5))
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
      firebaseGenerationSchema: CityList.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let cityList = try CityList(firebaseGeneratedContent)
    #expect(
      cityList.cities.count >= 3,
      "Expected at least 3 cities, but got \(cityList.cities.count)"
    )
    #expect(
      cityList.cities.count <= 5,
      "Expected at most 5 cities, but got \(cityList.cities.count)"
    )
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithArray(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "What are the biggest cities in Canada?"

      let response = try await model.respond(to: prompt, generating: CityList.self)

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
  #endif // compiler(>=6.2)

  @Generable
  struct TestNumber {
    @Guide(description: "A number", .minimum(110), .maximum(120))
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
    firebaseGenerationSchema: TestNumber.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let testNumber = try TestNumber(firebaseGeneratedContent)
    #expect(testNumber.value >= 110, "Expected a number >= 110, but got \(testNumber.value)")
    #expect(testNumber.value <= 120, "Expected a number <= 120, but got \(testNumber.value)")
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithNumber(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Give me a number"

      let response = try await model.respond(to: prompt, generating: TestNumber.self)

      let testNumber = response.content
      #expect(testNumber.value >= 110, "Expected a number >= 110, but got \(testNumber.value)")
      #expect(testNumber.value <= 120, "Expected a number <= 120, but got \(testNumber.value)")
    }
  #endif // compiler(>=6.2)

  @Generable
  struct ProductInfo {
    @Guide(description: "The name of the product")
    let productName: String
    @Guide(description: "A rating", .range(1 ... 5))
    let rating: Int
    @Guide(description: "A price", .minimum(10.00), .maximum(120.00))
    let price: Double
    @Guide(description: "A sale price", .minimum(5.00), .maximum(90.00))
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
    firebaseGenerationSchema: ProductInfo.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let productInfo = try ProductInfo(firebaseGeneratedContent)
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

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithMultipleDataTypes(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Describe a premium wireless headphone, including a user rating and price."

      let response = try await model.respond(to: prompt, generating: ProductInfo.self)

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
  #endif // compiler(>=6.2)

  @Generable
  struct MailingAddress {
    enum PostalInfo {
      @Generable
      struct Canada {
        @Guide(description: """
        The 2-letter province or territory code, for example, 'ON', 'QC', or 'NU'.
        """)
        let province: String
        @Guide(description: "The postal code, for example, 'A1A 1A1'.")
        let postalCode: String
      }

      @Generable
      struct UnitedStates {
        @Guide(description: """
        The 2-letter U.S. state or territory code, for example, 'CA', 'NY', or 'TX'.
        """)
        let state: String
        @Guide(description: "The 5-digit ZIP code, for example, '12345'.")
        let zipCode: String
      }

      case canada(province: String, postalCode: String)
      case unitedStates(state: String, zipCode: String)
    }

    @Guide(description: "The civic number and street name, for example, '123 Main Street'.")
    let streetAddress: String
    @Guide(description: "The name of the city.")
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
    firebaseGenerationSchema: [MailingAddress].firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let mailingAddresses = try [MailingAddress](firebaseGeneratedContent)
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

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithAnyOfArray(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_Flash,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = """
      What are the mailing addresses for the University of Waterloo, UC Berkeley and Queen's U?
      """

      let response = try await model.respond(to: prompt, generating: [MailingAddress].self)

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
  #endif // compiler(>=6.2)

  @Generable
  struct FeatureToggle {
    @Guide(description: "Whether the experimental feature should be active")
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
    firebaseGenerationSchema: FeatureToggle.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let featureToggle = try FeatureToggle(firebaseGeneratedContent)
    #expect(featureToggle.isEnabled)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithBoolean(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Should the experimental feature be active? Answer yes."

      let response = try await model.respond(to: prompt, generating: FeatureToggle.self)

      let featureToggle = response.content
      #expect(featureToggle.isEnabled)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct UserProfile {
    let username: String
    @Guide(description: "The user's optional middle name")
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
    firebaseGenerationSchema: UserProfile.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let userProfile = try UserProfile(firebaseGeneratedContent)
    #expect(userProfile.username == "jdoe")
    #expect(userProfile.middleName == nil)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithUserProfile(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Create a user profile for 'jdoe' without a middle name."

      let response = try await model.respond(to: prompt, generating: UserProfile.self)

      let userProfile = response.content
      #expect(userProfile.username == "jdoe")
      #expect(userProfile.middleName == nil)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct Pet {
    let name: String
    let species: Species

    @Generable(description: "Animal species types")
    enum Species {
      case cat, dog
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "name": .string(),
        "species": .enumeration(
          values: ["cat", "dog"],
          description: "Animal species types"
        ),
      ],
      title: "Pet"
    ),
    firebaseGenerationSchema: Pet.firebaseGenerationSchema
  ))
  func generateContentSimpleStringEnum(_ config: InstanceConfig,
                                       _ schema: SchemaType) async throws {
    print(Pet.firebaseGenerationSchema.debugDescription)
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Create a pet cat named 'Fluffy'."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let pet = try Pet(firebaseGeneratedContent)
    #expect(pet.name == "Fluffy")
    #expect(pet.species == .cat)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithSimpleStringEnum(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Create a pet dog named 'Buddy'."

      let response = try await model.respond(to: prompt, generating: Pet.self)

      let pet = response.content
      #expect(pet.name == "Buddy")
      #expect(pet.species == .dog)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct Task {
    let title: String

    @Guide(description: "The priority level")
    let priority: Priority

    @Generable
    enum Priority: String {
      case low
      case medium = "med"
      case high
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(
      properties: [
        "title": .string(),
        "priority": .enumeration(
          values: ["low", "med", "high"],
          description: "The priority level"
        ),
      ],
      title: "Task"
    ),
    firebaseGenerationSchema: Task.firebaseGenerationSchema
  ))
  func generateContentStringRawValueEnum(_ config: InstanceConfig,
                                         _ schema: SchemaType) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: SchemaTests.generationConfig(schema: schema),
      safetySettings: safetySettings
    )
    let prompt = "Create a medium priority task titled 'Feature Request'."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text)
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let task = try Task(firebaseGeneratedContent)
    #expect(task.title == "Feature Request")
    #expect(task.priority == .medium)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithStringRawValueEnum(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Create a high priority task titled 'Fix Bug'."

      let response = try await model.respond(to: prompt, generating: Task.self)

      let task = response.content
      #expect(task.title == "Fix Bug")
      #expect(task.priority == .high)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct GradeBook {
    @Guide(description: "A list of exam scores", .element(.range(0 ... 100)))
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
    firebaseGenerationSchema: GradeBook.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let gradeBook = try GradeBook(firebaseGeneratedContent)
    #expect(gradeBook.scores.count == 3)
    for score in gradeBook.scores {
      #expect(score >= 0 && score <= 100)
    }
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithConstrainedArray(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a gradebook with scores 95, 80, and 100."

      let response = try await model.respond(to: prompt, generating: GradeBook.self)

      let gradeBook = response.content
      #expect(gradeBook.scores.count == 3)
      for score in gradeBook.scores {
        #expect(score >= 0 && score <= 100)
      }
    }
  #endif // compiler(>=6.2)

  @Generable
  struct Catalog {
    let name: String
    let categories: [Category]

    @Generable
    struct Category {
      let title: String
      let items: [Item]

      @Generable
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
    firebaseGenerationSchema: Catalog.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let catalog = try Catalog(firebaseGeneratedContent)
    #expect(catalog.name == "Tech")
    #expect(catalog.categories.count == 1)
    #expect(catalog.categories[0].title == "Computers")
    #expect(catalog.categories[0].items.count == 1)
    #expect(catalog.categories[0].items[0].name == "Laptop")
    #expect(catalog.categories[0].items[0].price == 999.99)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithNestedType(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = """
      Create a catalog named 'Tech' with a category 'Computers' containing an item 'Laptop' for 999.99.
      """

      let response = try await model.respond(to: prompt, generating: Catalog.self)

      let catalog = response.content
      #expect(catalog.name == "Tech")
      #expect(catalog.categories.count == 1)
      #expect(catalog.categories[0].title == "Computers")
      #expect(catalog.categories[0].items.count == 1)
      #expect(catalog.categories[0].items[0].name == "Laptop")
      #expect(catalog.categories[0].items[0].price == 999.99)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct Statement {
    @Guide(description: "The total balance", .minimum(0.0))
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
    firebaseGenerationSchema: Statement.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let statement = try Statement(firebaseGeneratedContent)
    #expect(statement.balance == Decimal(string: "123.45")!)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithDecimalType(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate a statement with balance 123.45."

      let response = try await model.respond(to: prompt, generating: Statement.self)

      let statement = response.content
      #expect(statement.balance == Decimal(string: "123.45")!)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct Metadata {
    @Guide(description: "Optional tags, up to 3", .count(0 ... 3))
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
    firebaseGenerationSchema: Metadata.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let metadata = try Metadata(firebaseGeneratedContent)
    #expect(metadata.tags.isEmpty)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithEmptyCollection(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Generate metadata with no tags."

      let response = try await model.respond(to: prompt, generating: Metadata.self)

      let metadata = response.content
      #expect(metadata.tags.isEmpty)
    }
  #endif // compiler(>=6.2)

  @Generable
  struct ConstrainedValue {
    @Guide(description: "A value between 10 and 20", .minimum(10), .maximum(20))
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
    firebaseGenerationSchema: ConstrainedValue.firebaseGenerationSchema
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
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: text)
    let constrainedValue = try ConstrainedValue(firebaseGeneratedContent)
    #expect(constrainedValue.value == 15)
  }

  // TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
  #if compiler(>=6.2)
    @Test(arguments: InstanceConfig.allConfigs)
    func respondWithTypeCombinedGuides(_ config: InstanceConfig) async throws {
      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
      let prompt = "Give me the value 15."

      let response = try await model.respond(to: prompt, generating: ConstrainedValue.self)

      let constrainedValue = response.content
      #expect(constrainedValue.value == 15)
    }
  #endif // compiler(>=6.2)

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(properties: ["value": .integer()], title: "TestNumber"),
    firebaseGenerationSchema: TestNumber.firebaseGenerationSchema
  ))
  func generateContentErrorHandling(_ config: InstanceConfig, _ schema: SchemaType) async throws {
    // Since we are adding integration tests, let's verify that providing a JSON with a property of
    // the wrong type fails to decode.
    let invalidJson = """
    { "value": "not an int" }
    """
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: invalidJson)
    #expect(throws: Error.self) {
      _ = try TestNumber(firebaseGeneratedContent)
    }
  }

  @Test(arguments: testConfigs(
    instanceConfigs: InstanceConfig.allConfigs,
    openAPISchema: .object(properties: ["value": .integer()], title: "TestNumber"),
    firebaseGenerationSchema: TestNumber.firebaseGenerationSchema
  ))
  func generateContentMissingFieldFailure(_ config: InstanceConfig,
                                          _ schema: SchemaType) async throws {
    // Verify that providing a JSON that is missing a required field fails.
    let invalidJson = """
    { "otherField": 123 }
    """
    let firebaseGeneratedContent = try FirebaseGeneratedContent(json: invalidJson)
    #expect(throws: Error.self) {
      _ = try TestNumber(firebaseGeneratedContent)
    }
  }

  enum SchemaType: CustomTestStringConvertible {
    case openAPI(Schema)
    case json(FirebaseGenerationSchema)

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
    case let .json(firebaseGenerationSchema):
      return GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1, responseMIMEType: mimeType,
                              responseFirebaseGenerationSchema: firebaseGenerationSchema)
    }
  }

  private static func testConfigs(instanceConfigs: [InstanceConfig], openAPISchema: Schema,
                                  firebaseGenerationSchema: FirebaseGenerationSchema) -> [(
    InstanceConfig,
    SchemaType
  )] {
    return instanceConfigs.flatMap { [
      ($0, .openAPI(openAPISchema)),
      ($0, .json(firebaseGenerationSchema)),
    ] }
  }
}

// MARK: - FirebaseGenerable Conformances

// MARK: PostalInfo

// TODO: Replace manual implementation with macro when enums with associated values are supported.

extension SchemaTests.MailingAddress.PostalInfo: FirebaseGenerable {
  static var firebaseGenerationSchema: FirebaseAILogic.FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Self.self, anyOf: [Canada.self, UnitedStates.self])
  }

  init(_ content: FirebaseGeneratedContent) throws {
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

  var firebaseGeneratedContent: FirebaseGeneratedContent {
    func addProperty(name: String, value: some FirebaseGenerable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseGenerable)?) {
      if let value {
        properties.append((name, value))
      }
    }

    var properties = [(name: String, value: any ConvertibleToFirebaseGeneratedContent)]()
    switch self {
    case let .canada(province, postalCode):
      addProperty(name: "province", value: province)
      addProperty(name: "postalCode", value: postalCode)
    case let .unitedStates(state, zipCode):
      addProperty(name: "state", value: state)
      addProperty(name: "zipCode", value: zipCode)
    }
    return FirebaseGeneratedContent(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
  }
}
