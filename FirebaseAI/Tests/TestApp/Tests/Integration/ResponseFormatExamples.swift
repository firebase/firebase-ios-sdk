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
import FirebaseCore
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)
import JSONSchemaBuilder
import Testing

@Suite(.serialized)
struct ResponseFormatExamples {
  #if canImport(FoundationModels)
    @Generable
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    struct GenerablePerson {
      let firstName: String
      let middleName: String?
      let lastName: String
      let age: Int
    }

    @Test
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func generatePerson_generationSchema() async throws {
      let model = try FirebaseAI.firebaseAI().generativeModel(
        modelName: ModelNames.gemini2_5_FlashLite,
        generationConfig: GenerationConfig(
          responseFormat: .json(schema: GenerablePerson.generationSchema),
        )
      )
      let prompt = "Generate a person named John Doe who is 30 years old."

      let response = try await model.generateContent(prompt)

      let generatedContent = try GeneratedContent(json: #require(response.text))
      let person = try GenerablePerson(generatedContent)
      #expect(person.firstName == "John")
      #expect(person.lastName == "Doe")
      #expect(person.middleName == nil)
      #expect(person.age == 30)
    }
  #endif // canImport(FoundationModels)

  struct DecodablePerson: Decodable {
    let firstName: String
    let middleName: String?
    let lastName: String
    let age: Int
  }

  @Test
  func generatePerson_manualJSONSchema() async throws {
    // Note: JSONObject would be replaced with a specific public type for JSON Schema
    let schema: FirebaseAILogic.JSONObject = [
      "type": .string("object"),
      "properties": .object([
        "firstName": .object([
          "type": .string("string"),
        ]),
        "middleName": .object([
          "type": .string("string"),
        ]),
        "lastName": .object([
          "type": .string("string"),
        ]),
        "age": .object([
          "type": .string("integer"),
        ]),
      ]),
      "required": .array([
        .string("firstName"), .string("lastName"), .string("age"),
      ]),
    ]
    let model = FirebaseAI.firebaseAI().generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: GenerationConfig(
        responseFormat: .json(schema: schema),
      )
    )
    let prompt = "Generate a person named John Doe who is 30 years old."

    let response = try await model.generateContent(prompt)

    let jsonText = try #require(response.text)
    let jsonData = try #require(jsonText.data(using: .utf8))
    let person = try JSONDecoder().decode(DecodablePerson.self, from: jsonData)
    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.middleName == nil)
    #expect(person.age == 30)
  }

  @Test
  func generatePerson_jsonSchemaString() async throws {
    let schema = """
    {
      "type" : "object",
      "properties" : {
        "firstName" : {
          "type" : "string"
        },
        "middleName" : {
          "type" : "string"
        },
        "lastName" : {
          "type" : "string"
        },
        "age" : {
          "type" : "integer"
        }
      },
      "required" : [
        "firstName",
        "lastName",
        "age"
      ]
    }
    """
    let model = try FirebaseAI.firebaseAI().generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: GenerationConfig(
        responseFormat: .json(schema: schema)
      )
    )
    let prompt = "Generate a person named John Doe who is 30 years old."

    let response = try await model.generateContent(prompt)

    let jsonText = try #require(response.text)
    let jsonData = try #require(jsonText.data(using: .utf8))
    let person = try JSONDecoder().decode(DecodablePerson.self, from: jsonData)
    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.middleName == nil)
    #expect(person.age == 30)
  }

  @Schemable
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  struct SchemablePerson {
    let firstName: String
    let middleName: String?
    let lastName: String
    let age: Int
  }

  @Test
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  func generatePerson_schemable() async throws {
    let model = try FirebaseAI.firebaseAI().generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: GenerationConfig(
        responseFormat: .json(schema: SchemablePerson.schema.schemaValue)
      )
    )
    let prompt = "Generate a person named John Doe who is 30 years old."

    let response = try await model.generateContent(prompt)

    let jsonText = try #require(response.text)
    let person = try SchemablePerson.schema.parseAndValidate(instance: jsonText)
    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.middleName == nil)
    #expect(person.age == 30)
  }

  @Test
  func generateEnum() async throws {
    let model = FirebaseAI.firebaseAI().generativeModel(
      modelName: ModelNames.gemini2_5_FlashLite,
      generationConfig: GenerationConfig(
        responseFormat: .textEnum(anyOf: ["John", "Bill", "Jane", "Alice"])
      )
    )
    let prompt = "Pick a first name for a man that starts with J."

    let response = try await model.generateContent(prompt)

    let jsonText = try #require(response.text)
    #expect(jsonText == "John")
  }
}
