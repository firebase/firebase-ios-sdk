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

@testable import FirebaseAILogic
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
class ModelOutputTests: XCTestCase {
  // MARK: - Type Conversions

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func testModelOutputIsConvertibleToGeneratedContent() throws {
      let expectedName = "John Doe"
      let expectedAge = 40
      let expectedGenerationID = GenerationID()
      let expectedGeneratedContent = GeneratedContent(
        properties: ["name": expectedName, "age": expectedAge], id: expectedGenerationID
      )
      let modelOutput = ModelOutput(
        properties: ["name": expectedName, "age": expectedAge],
        id: ResponseID(generationID: expectedGenerationID)
      )

      let generatedContent = modelOutput.generatedContent

      XCTAssertEqual(generatedContent, expectedGeneratedContent)
      XCTAssertEqual(try generatedContent.value(forProperty: "name"), expectedName)
      XCTAssertEqual(try generatedContent.value(forProperty: "age"), expectedAge)
      XCTAssertEqual(generatedContent.id, expectedGenerationID)
      XCTAssertEqual(generatedContent.kind, expectedGeneratedContent.kind)
      XCTAssertEqual(generatedContent.isComplete, expectedGeneratedContent.isComplete)
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func testGeneratedContentIsConvertibleToModelOutput() throws {
      let expectedName = "Bob Loblaw"
      let expectedAge = 50
      let generationID = GenerationID()
      let expectedResponseID = ResponseID(generationID: generationID)
      let expectedModelOutput = ModelOutput(
        properties: ["name": expectedName, "age": expectedAge], id: expectedResponseID
      )
      let generatedContent = GeneratedContent(
        properties: ["name": expectedName, "age": expectedAge], id: generationID
      )

      let modelOutput = generatedContent.modelOutput

      XCTAssertEqual(modelOutput, expectedModelOutput)
      XCTAssertEqual(try modelOutput.value(forProperty: "name"), expectedName)
      XCTAssertEqual(try modelOutput.value(forProperty: "age"), expectedAge)
      XCTAssertEqual(modelOutput.id, expectedResponseID)
      XCTAssertEqual(modelOutput.kind, expectedModelOutput.kind)
      XCTAssertEqual(modelOutput.isComplete, expectedModelOutput.isComplete)
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func testConvertibleFromGeneratedContentIsConvertibleFromModelOutput() throws {
      struct PersonConvertibleFromGeneratedContent: ConvertibleFromGeneratedContent,
        ConvertibleFromModelOutput {
        let name: String
        let age: Int

        // `ConvertibleFromGeneratedContent` conformance
        init(_ content: FoundationModels.GeneratedContent) throws {
          name = try content.value(forProperty: "name")
          age = try content.value(forProperty: "age")
        }
      }

      let expectedName = "John Doe"
      let expectedAge = 40
      let modelOutput = ModelOutput(properties: ["name": expectedName, "age": expectedAge])

      let person = try PersonConvertibleFromGeneratedContent(modelOutput)

      XCTAssertEqual(person.name, expectedName)
      XCTAssertEqual(person.age, expectedAge)
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func testConvertibleToGeneratedContentIsConvertibleToModelOutput() throws {
      struct PersonConvertibleToGeneratedContent: ConvertibleToGeneratedContent,
        ConvertibleToModelOutput {
        let name: String
        let age: Int

        // `ConvertibleToGeneratedContent` conformance
        var generatedContent: GeneratedContent {
          return GeneratedContent(properties: ["name": name, "age": age])
        }
      }

      let expectedName = "John Doe"
      let expectedAge = 40
      let person = PersonConvertibleToGeneratedContent(name: expectedName, age: expectedAge)

      let modelOutput = person.modelOutput

      XCTAssertEqual(try modelOutput.value(forProperty: "name"), person.name)
      XCTAssertEqual(try modelOutput.value(forProperty: "age"), person.age)
      XCTAssertTrue(modelOutput.isComplete)
    }
  #endif // canImport(FoundationModels)
}
