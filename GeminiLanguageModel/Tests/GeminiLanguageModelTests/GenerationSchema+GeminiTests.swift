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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  @Suite("GenerationSchema+Gemini Tests", .requireFoundationModels)
  struct GenerationSchemaGeminiTests {
    @Generable(description: "Basic profile information about a pet")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct PetProfile {
      var name: String
      var age: Int
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsXOrderToPropertyOrdering() throws {
      let stringSchema = DynamicGenerationSchema(type: String.self)
      let intSchema = DynamicGenerationSchema(type: Int.self)
      let rootSchema = DynamicGenerationSchema(
        name: "CatProfile",
        description: "Profile information about a cat",
        properties: [
          DynamicGenerationSchema.Property(name: "name", schema: stringSchema),
          DynamicGenerationSchema.Property(name: "age", schema: intSchema),
        ]
      )
      let schema = try GenerationSchema(root: rootSchema, dependencies: [])

      let jsonSchema = try schema.toGeminiJSONSchema()

      #expect(jsonSchema["x-order"] == nil)
      let propertyOrdering = try #require(jsonSchema["propertyOrdering"])
      #expect(propertyOrdering == .array([.string("name"), .string("age")]))
      #expect(jsonSchema["type"] == .string("object"))
      let properties = try #require(jsonSchema["properties"])
      if case .object(let propDict) = properties {
        #expect(propDict["name"] != nil)
        #expect(propDict["age"] != nil)
      } else {
        Issue.record("Expected properties to be an object.")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsNestedXOrderToPropertyOrdering() throws {
      let stringSchema = DynamicGenerationSchema(type: String.self)
      let addressSchema = DynamicGenerationSchema(
        name: "Address",
        description: "A postal address",
        properties: [
          DynamicGenerationSchema.Property(name: "street", schema: stringSchema),
          DynamicGenerationSchema.Property(name: "city", schema: stringSchema),
        ]
      )
      let personSchema = DynamicGenerationSchema(
        name: "Person",
        description: "A person with an address",
        properties: [
          DynamicGenerationSchema.Property(name: "name", schema: stringSchema),
          DynamicGenerationSchema.Property(name: "address", schema: addressSchema),
        ]
      )
      let schema = try GenerationSchema(root: personSchema, dependencies: [])

      let jsonSchema = try schema.toGeminiJSONSchema()

      #expect(jsonSchema["x-order"] == nil)
      let rootOrdering = try #require(jsonSchema["propertyOrdering"])
      #expect(rootOrdering == .array([.string("name"), .string("address")]))
      let defs = try #require(jsonSchema["$defs"])
      guard case .object(let defsDict) = defs,
        case .object(let addressDef) = try #require(defsDict["Address"])
      else {
        Issue.record("Expected $defs to contain Address.")
        return
      }
      #expect(addressDef["x-order"] == nil)
      let addressOrdering = try #require(addressDef["propertyOrdering"])
      #expect(addressOrdering == .array([.string("street"), .string("city")]))

      let encoder = JSONEncoder()
      let data = try encoder.encode(jsonSchema)
      let jsonString = try #require(String(data: data, encoding: .utf8))
      #expect(!jsonString.contains("x-order"))
      #expect(jsonString.contains("propertyOrdering"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsGenerableTypeSchema() throws {
      let schema = PetProfile.generationSchema

      let jsonSchema = try schema.toGeminiJSONSchema()

      #expect(jsonSchema["x-order"] == nil)
      let propertyOrdering = try #require(jsonSchema["propertyOrdering"])
      #expect(propertyOrdering == .array([.string("name"), .string("age")]))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func toGeminiJSONValueWrapsObject() throws {
      let stringSchema = DynamicGenerationSchema(type: String.self)
      let rootSchema = DynamicGenerationSchema(
        name: "Item",
        description: "A simple item",
        properties: [
          DynamicGenerationSchema.Property(name: "title", schema: stringSchema)
        ]
      )
      let schema = try GenerationSchema(root: rootSchema, dependencies: [])

      let jsonValue = try schema.toGeminiJSONValue()

      guard case .object(let jsonObject) = jsonValue else {
        Issue.record("Expected .object variant from toGeminiJSONValue().")
        return
      }
      #expect(jsonObject["x-order"] == nil)
      #expect(jsonObject["type"] == .string("object"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func integratesWithTextResponseFormat() throws {
      let stringSchema = DynamicGenerationSchema(type: String.self)
      let rootSchema = DynamicGenerationSchema(
        name: "Response",
        description: "A structured response",
        properties: [
          DynamicGenerationSchema.Property(name: "message", schema: stringSchema)
        ]
      )
      let schema = try GenerationSchema(root: rootSchema, dependencies: [])

      let textFormat = TextResponseFormat(
        mimeType: .applicationJson,
        schema: try schema.toGeminiJSONValue()
      )
      let config = ResponseFormatConfig(text: textFormat)
      let data = try JSONEncoder().encode(config)
      let decoded = try JSONDecoder().decode(ResponseFormatConfig.self, from: data)

      #expect(decoded.text?.mimeType == .applicationJson)
      guard case .object(let schemaObject) = decoded.text?.schema else {
        Issue.record("Expected decoded schema to be a JSON object.")
        return
      }
      #expect(schemaObject["x-order"] == nil)
      #expect(schemaObject["propertyOrdering"] == .array([.string("message")]))
    }

    @Generable(description: "A priority level")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    enum Priority: String {
      case low
      case medium
      case high
      case critical
    }

    @Generable(description: "A node in a tree")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct TreeNode {
      var name: String
      var children: [TreeNode]
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsStringEnumSchema() throws {
      let schema = Priority.generationSchema

      let jsonSchema = try schema.toGeminiJSONSchema()

      #expect(jsonSchema["type"] == .string("string"))
      let enumValues = try #require(jsonSchema["enum"])
      #expect(
        enumValues
          == .array([
            .string("low"),
            .string("medium"),
            .string("high"),
            .string("critical"),
          ])
      )
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsRecursiveSchema() throws {
      let schema = TreeNode.generationSchema

      let jsonSchema = try schema.toGeminiJSONSchema()

      #expect(jsonSchema["x-order"] == nil)
      #expect(jsonSchema["propertyOrdering"] != nil)
      let properties = try #require(jsonSchema["properties"])
      guard case .object(let propDict) = properties else {
        Issue.record("Expected properties to be an object.")
        return
      }
      #expect(propDict["name"] != nil)
      #expect(propDict["children"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func convertsArrayLengthAndNumericConstraints() throws {
      let intSchema = DynamicGenerationSchema(
        type: Int.self,
        guides: [.range(1...10)]
      )
      let arraySchema = DynamicGenerationSchema(
        arrayOf: intSchema,
        minimumElements: 1,
        maximumElements: 5
      )
      let rootSchema = DynamicGenerationSchema(
        name: "Rankings",
        description: "Rankings list",
        properties: [
          DynamicGenerationSchema.Property(name: "scores", schema: arraySchema)
        ]
      )
      let schema = try GenerationSchema(root: rootSchema, dependencies: [])

      let jsonSchema = try schema.toGeminiJSONSchema()

      let properties = try #require(jsonSchema["properties"])
      guard case .object(let propDict) = properties,
        case .object(let scoresProp) = try #require(propDict["scores"])
      else {
        Issue.record("Expected properties.scores to be an object.")
        return
      }
      #expect(scoresProp["type"] == .string("array"))
      #expect(scoresProp["minItems"] == .number(1))
      #expect(scoresProp["maxItems"] == .number(5))
    }

    @Generable(description: "A data model with a pattern guide")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct DataModelWithPattern {
      @Guide(description: "A postal code", .pattern(#/^\d{5}$/#))
      var postalCode: String
    }

    @Generable(description: "A data model with a property named pattern")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct DataModelWithPatternProperty {
      var pattern: String
    }

    @Generable(description: "A data model with a property named properties and a pattern guide")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct DataModelWithPropertiesAndPatternGuide {
      @Guide(description: "A postal code", .pattern(#/^\d{5}$/#))
      var properties: String
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func schemaWithPatternGuideThrowsUnsupportedGenerationGuide() throws {
      let schema = DataModelWithPattern.generationSchema

      do {
        _ = try schema.toGeminiJSONSchema()
        Issue.record("Expected unsupportedGenerationGuide error.")
      } catch LanguageModelError.unsupportedGenerationGuide(let error) {
        #expect(error.debugDescription.contains("pattern"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func schemaWithPropertiesPropertyAndPatternGuideThrows() throws {
      let schema = DataModelWithPropertiesAndPatternGuide.generationSchema

      do {
        _ = try schema.toGeminiJSONSchema()
        Issue.record("Expected unsupportedGenerationGuide error.")
      } catch LanguageModelError.unsupportedGenerationGuide(let error) {
        #expect(error.debugDescription.contains("pattern"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func schemaWithPropertyNamedPatternEncodesSuccessfully() throws {
      let schema = DataModelWithPatternProperty.generationSchema

      let jsonSchema = try schema.toGeminiJSONSchema()

      let properties = try #require(jsonSchema["properties"])
      guard case .object(let propDict) = properties else {
        Issue.record("Expected properties to be an object.")
        return
      }
      #expect(propDict["pattern"] != nil)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
