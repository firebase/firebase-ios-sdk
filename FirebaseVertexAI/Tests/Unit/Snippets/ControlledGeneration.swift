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

import GoogleGenerativeAI
import XCTest

// Set up your API Key
// ====================
// To use the Gemini API, you'll need an API key. To learn more, see the "Set up your API Key"
// section in the Gemini API quickstart:
// https://ai.google.dev/gemini-api/docs/quickstart?lang=swift#set-up-api-key

@available(iOS 15.0, macCatalyst 15.0, *)
final class ControlledGenerationSnippets: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipIf(
      APIKey.default.isEmpty,
      "`\(APIKey.apiKeyEnvVar)` environment variable not set."
    )
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

    let generativeModel = GenerativeModel(
      // Specify a model that supports controlled generation like Gemini 1.5 Pro
      name: "gemini-1.5-pro",
      // Access your API key from your on-demand resource .plist file (see "Set up your API key"
      // above)
      apiKey: APIKey.default,
      generationConfig: GenerationConfig(
        responseMIMEType: "application/json",
        responseSchema: jsonSchema
      )
    )

    let prompt = "List a few popular cookie recipes."
    let response = try await generativeModel.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END json_controlled_generation]
  }

  func testJSONNoSchema() async throws {
    // [START json_no_schema]
    let generativeModel = GenerativeModel(
      name: "gemini-1.5-flash",
      // Access your API key from your on-demand resource .plist file (see "Set up your API key"
      // above)
      apiKey: APIKey.default,
      generationConfig: GenerationConfig(responseMIMEType: "application/json")
    )

    let prompt = """
    List a few popular cookie recipes using this JSON schema:

    Recipe = {'recipeName': string}
    Return: Array<Recipe>
    """
    let response = try await generativeModel.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END json_no_schema]
  }
}
