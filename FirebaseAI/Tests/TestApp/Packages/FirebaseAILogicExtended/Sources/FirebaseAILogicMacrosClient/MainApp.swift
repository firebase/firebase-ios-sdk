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

import FirebaseAILogicMacro

@FirebaseGenerable
struct Location {
  @FirebaseGuide(description: "The name of the city.")
  let city: String
}

struct LocationTool: FirebaseTool {
  let description = "Returns the user's current location."

  @FirebaseGenerable
  struct VoidArgs {}

  func call(arguments: VoidArgs) async throws -> Location {
    return Location(city: "Waterloo")
  }
}

struct WeatherTool: FirebaseTool {
  let description = "Returns the current weather conditions."

  @FirebaseGenerable
  struct WeatherConditions {
    @FirebaseGuide(description: "The current temperature in Celsius.")
    let temperature: Double

    @FirebaseGuide(description: "The location of the weather conditions.")
    let location: Location
  }

  func call(arguments: Location) async throws -> WeatherConditions {
    return WeatherConditions(
      temperature: -8.0,
      location: Location(city: arguments.city)
    )
  }
}

@main
struct MainApp {
  static func main() async throws {
    let response = try await GenerativeModel.respond(
      to: "What's the current temperature?",
      tools: [LocationTool(), WeatherTool()]
    )

    print(response)
  }
}
