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

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
final class FunctionCallingSnippets: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipIf(
      APIKey.default.isEmpty,
      "`\(APIKey.apiKeyEnvVar)` environment variable not set."
    )
  }

  func testFunctionCalling() async throws {
    // [START function_calling]
    // Calls a hypothetical API to control a light bulb and returns the values that were set.
    func controlLight(brightness: Double, colorTemperature: String) -> JSONObject {
      return ["brightness": .number(brightness), "colorTemperature": .string(colorTemperature)]
    }

    let generativeModel =
      GenerativeModel(
        // Use a model that supports function calling, like a Gemini 1.5 model
        name: "gemini-1.5-flash",
        // Access your API key from your on-demand resource .plist file (see "Set up your API key"
        // above)
        apiKey: APIKey.default,
        tools: [Tool(functionDeclarations: [
          FunctionDeclaration(
            name: "controlLight",
            description: "Set the brightness and color temperature of a room light.",
            parameters: [
              "brightness": Schema(
                type: .number,
                format: "double",
                description: "Light level from 0 to 100. Zero is off and 100 is full brightness."
              ),
              "colorTemperature": Schema(
                type: .string,
                format: "enum",
                description: "Color temperature of the light fixture.",
                enumValues: ["daylight", "cool", "warm"]
              ),
            ],
            requiredParameters: ["brightness", "colorTemperature"]
          ),
        ])]
      )

    let chat = generativeModel.startChat()

    let prompt = "Dim the lights so the room feels cozy and warm."

    // Send the message to the model.
    let response1 = try await chat.sendMessage(prompt)

    // Check if the model responded with a function call.
    // For simplicity, this sample uses the first function call found.
    guard let functionCall = response1.functionCalls.first else {
      fatalError("Model did not respond with a function call.")
    }
    // Print an error if the returned function was not declared
    guard functionCall.name == "controlLight" else {
      fatalError("Unexpected function called: \(functionCall.name)")
    }
    // Verify that the names and types of the parameters match the declaration
    guard case let .number(brightness) = functionCall.args["brightness"] else {
      fatalError("Missing argument: brightness")
    }
    guard case let .string(colorTemperature) = functionCall.args["colorTemperature"] else {
      fatalError("Missing argument: colorTemperature")
    }

    // Call the executable function named in the FunctionCall with the arguments specified in the
    // FunctionCall and let it call the hypothetical API.
    let apiResponse = controlLight(brightness: brightness, colorTemperature: colorTemperature)

    // Send the API response back to the model so it can generate a text response that can be
    // displayed to the user.
    let response2 = try await chat.sendMessage([ModelContent(
      role: "function",
      parts: [.functionResponse(FunctionResponse(name: "controlLight", response: apiResponse))]
    )])

    if let text = response2.text {
      print(text)
    }
    // [END function_calling]
  }
}
