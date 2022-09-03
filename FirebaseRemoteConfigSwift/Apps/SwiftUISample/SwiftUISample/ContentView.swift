/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift
import SwiftUI

struct Recipe: Decodable {
  var recipe_name: String
  var cook_time: Int
  var notes: String
}

struct ContentView: View {
  @RemoteConfigProperty(key: "Color", fallback: "blue") var colorValue: String
  @RemoteConfigProperty(key: "Food", fallback: nil) var foodValue: String?
  @RemoteConfigProperty(key: "Toggle", fallback: false) var toggleValue: Bool
  @RemoteConfigProperty(key: "fruits", fallback: []) var fruits: [String]
  @RemoteConfigProperty(key: "counter", fallback: 1) var counter: Int
  @RemoteConfigProperty(key: "mobileweek", fallback: ["section 0": "breakfast"]) var sessions:
    [String: String]
  @RemoteConfigProperty(
    key: "recipe", fallback: Recipe(recipe_name: "banana bread", cook_time: 40, notes: "yum!"))
  var recipe: Recipe

  @State private var realtimeSwitch = false
  var realtimeToggle: Bool

  var body: some View {
    VStack {
      Button(action: fetchAndActivate) {
        Text("fetchAndActivate")
      }

      List(fruits, id: \.self) { fruit in
        Text(fruit)
      }
      List {
        ForEach(sessions.sorted(by: >), id: \.key) { key, value in
          Section(header: Text(key)) {
            Text(value)
          }
        }
      }
      List {
        Text(recipe.recipe_name)
        Text(recipe.notes)
        Text("cook time: \(recipe.cook_time)")
      }
      ForEach(0...counter, id: \.self) { i in
        Text(colorValue)
          .padding()
          .foregroundStyle(toggleValue ? .primary : .secondary)
        if (foodValue) != nil {
          Text(foodValue!)
            .padding()
            .foregroundStyle(toggleValue ? .primary : .secondary)
        }
      }
    }
  }
  func fetchAndActivate() {
    RemoteConfig.remoteConfig().fetchAndActivate()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(realtimeToggle: false)
  }
}
