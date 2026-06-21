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

import FirebaseAnalytics
import FirebaseRemoteConfig
import SwiftUI

struct Recipe: Decodable {
  var recipeName: String
  var cookTime: Int
  var notes: String
}

struct ContentView: View {
  @RemoteConfigProperty(key: "Color", fallback: nil) var colorValue: String?
  @RemoteConfigProperty(key: "toggleStyleSquare", fallback: false) var toggleStyleSquare: Bool
  @RemoteConfigProperty(key: "fruits", fallback: []) var fruits: [String]
  @RemoteConfigProperty(key: "counter", fallback: 1) var counter: Int
  @RemoteConfigProperty(key: "mobileweek", fallback: ["section 0": "breakfast"]) var sessions:
    [String: String]
  @RemoteConfigProperty(
    key: "recipe", fallback: Recipe(recipeName: "banana bread", cookTime: 40, notes: "yum!")
  )

  var recipe: Recipe
  @State var isChecked = false

  var body: some View {
    VStack {
      Button(action: fetchAndActivate) {
        Text("fetchAndActivate")
      }

      List(fruits, id: \.self) { fruit in
        HStack {
          Button(action: toggle) {
            if toggleStyleSquare {
              Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            } else {
              Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            }
          }
          Text(fruit)
        }
      }
      List {
        ForEach(sessions.sorted(by: >), id: \.key) { key, value in
          Section(header: Text(key)) {
            Text(value)
          }
        }
      }
      List {
        Text(recipe.recipeName)
        Text(recipe.notes)
        Text("cook time: \(recipe.cookTime)")
          .analyticsScreen(name: "recipe")
      }
      // Test non exist key
      if colorValue != nil {
        Text(colorValue!)
          .padding()
      }
    }
  }

  func toggle() {
    isChecked.toggle()
  }

  func fetchAndActivate() {
    RemoteConfig.remoteConfig().fetchAndActivate()
    Analytics.logEvent("activate", parameters: [:])
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
