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

// These snippet tests are intentionally skipped in CI jobs; see the README file in this directory
// for instructions on running them manually.

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class StructuredOutputSnippets: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func testStructuredOutputJSONBasic() async throws {
    // Provide a JSON schema object using a standard format.
    // Later, pass this schema object into `responseSchema` in the generation config.
    let jsonSchema = Schema.object(
      properties: [
        "characters": Schema.array(
          items: .object(
            properties: [
              "name": .string(),
              "age": .integer(),
              "species": .string(),
              "accessory": .enumeration(values: ["hat", "belt", "shoes"]),
            ],
            optionalProperties: ["accessory"]
          )
        ),
      ]
    )

    // Initialize the Vertex AI service and the generative model.
    // Use a model that supports `responseSchema`, like one of the Gemini 1.5 models.
    let model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      // In the generation config, set the `responseMimeType` to `application/json`
      // and pass the JSON schema object into `responseSchema`.
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: jsonSchema
      )
    )

    let prompt = "For use in a children's card game, generate 10 animal-based characters."

    let response = try await model.generateContent(prompt)
    print(response.text ?? "No text in response.")
  }

  func testStructuredOutputEnumBasic() async throws {
    // Provide an enum schema object using a standard format.
    // Later, pass this schema object into `responseSchema` in the generation config.
    let enumSchema = Schema.enumeration(values: ["drama", "comedy", "documentary"])

    // Initialize the Vertex AI service and the generative model.
    // Use a model that supports `responseSchema`, like one of the Gemini 1.5 models.
    let model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      // In the generation config, set the `responseMimeType` to `text/x.enum`
      // and pass the enum schema object into `responseSchema`.
      generationConfig: GenerationConfig(
        responseMIMEType: "text/x.enum",
        responseSchema: enumSchema
      )
    )

    let prompt = """
    The film aims to educate and inform viewers about real-life subjects, events, or people.
    It offers a factual record of a particular topic by combining interviews, historical footage,
    and narration. The primary purpose of a film is to present information and provide insights
    into various aspects of reality.
    """

    let response = try await model.generateContent(prompt)
    print(response.text ?? "No text in response.")
  }
}
