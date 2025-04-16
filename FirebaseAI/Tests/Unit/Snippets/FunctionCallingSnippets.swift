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
final class FunctionCallingSnippets: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func testFunctionCalling() async throws {
    // This function calls a hypothetical external API that returns
    // a collection of weather information for a given location on a given date.
    func fetchWeather(city: String, state: String, date: String) -> JSONObject {
      // TODO(developer): Write a standard function that would call an external weather API.

      // For demo purposes, this hypothetical response is hardcoded here in the expected format.
      return [
        "temperature": .number(38),
        "chancePrecipitation": .string("56%"),
        "cloudConditions": .string("partlyCloudy"),
      ]
    }

    let fetchWeatherTool = FunctionDeclaration(
      name: "fetchWeather",
      description: "Get the weather conditions for a specific city on a specific date.",
      parameters: [
        "location": .object(
          properties: [
            "city": .string(description: "The city of the location."),
            "state": .string(description: "The US state of the location."),
          ],
          description: """
          The name of the city and its state for which to get the weather. Only cities in the
          USA are supported.
          """
        ),
        "date": .string(
          description: """
          The date for which to get the weather. Date must be in the format: YYYY-MM-DD.
          """
        ),
      ]
    )

    // Initialize the Vertex AI service and the generative model.
    // Use a model that supports function calling, like a Gemini 1.5 model.
    let model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      // Provide the function declaration to the model.
      tools: [.functionDeclarations([fetchWeatherTool])]
    )

    let chat = model.startChat()
    let prompt = "What was the weather in Boston on October 17, 2024?"

    // Send the user's question (the prompt) to the model using multi-turn chat.
    let response = try await chat.sendMessage(prompt)

    var functionResponses = [FunctionResponsePart]()

    // When the model responds with one or more function calls, invoke the function(s).
    for functionCall in response.functionCalls {
      if functionCall.name == "fetchWeather" {
        // TODO(developer): Handle invalid arguments.
        guard case let .object(location) = functionCall.args["location"] else { fatalError() }
        guard case let .string(city) = location["city"] else { fatalError() }
        guard case let .string(state) = location["state"] else { fatalError() }
        guard case let .string(date) = functionCall.args["date"] else { fatalError() }

        functionResponses.append(FunctionResponsePart(
          name: functionCall.name,
          response: fetchWeather(city: city, state: state, date: date)
        ))
      }
      // TODO(developer): Handle other potential function calls, if any.
    }

    // Send the response(s) from the function back to the model so that the model can use it
    // to generate its final response.
    let finalResponse = try await chat.sendMessage(
      [ModelContent(role: "function", parts: functionResponses)]
    )

    // Log the text response.
    print(finalResponse.text ?? "No text in response.")
  }
}
