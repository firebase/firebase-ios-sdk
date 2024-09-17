// Copyright 2024 Google LLC
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

import FirebaseCore
import FirebaseVertexAI
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ControlledGenerationSnippets: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureForSnippets()
  }

  override func tearDown() async throws {
    if let app = FirebaseApp.app() {
      await app.delete()
    }
  }

  func testJSONControlledGeneration() async throws {
    // [START json_controlled_generation]
    let jsonSchema = Schema(
      type: .array,
      description: "List of recipes",
      items: Schema(
        type: .object,
        properties: [
          "recipeName": Schema(type: .string, description: "Name of the recipe", nullable: false),
        ],
        requiredProperties: ["recipeName"]
      )
    )

    let model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: jsonSchema
      )
    )

    let prompt = "List a few popular cookie recipes."
    let response = try await model.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END json_controlled_generation]
  }

  func testJSONNoSchema() async throws {
    // [START json_no_schema]
    let model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      generationConfig: GenerationConfig(responseMIMEType: "application/json")
    )

    let prompt = """
    List a few popular cookie recipes using this JSON schema:

    Recipe = {'recipeName': string}
    Return: Array<Recipe>
    """
    let response = try await model.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END json_no_schema]
  }
}
