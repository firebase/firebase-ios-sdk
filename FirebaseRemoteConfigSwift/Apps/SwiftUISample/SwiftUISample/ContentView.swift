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

import SwiftUI
import FirebaseRemoteConfigSwift

struct Recipe : Decodable {
  var recipe_name : String
  var cook_time: Int
  var notes : String
}

struct ContentView: View {
  @RemoteConfigProperty(key: "Color") var configValue : String?
  @RemoteConfigProperty(key: "Toggle") var toggleValue : Bool?
  @RemoteConfigProperty(key: "fruits") var fruits : [String]?
  @RemoteConfigProperty(key: "counter") var counter : Int?
  @RemoteConfigProperty(key: "mobileweek") var sessions : [String: String]?
  @RemoteConfigProperty(key: "recipe") var recipe : Recipe?

  var body: some View {
    VStack {
      if let c = counter {
        if c > 1 {
          ForEach(1 ... c, id: \.self) { i in
            Text(configValue ?? "")
              .padding()
            .foregroundStyle((toggleValue ?? false) ? .primary : .secondary)}
        }
      } else {
        Text((configValue ?? ""))
          .padding()
          .foregroundStyle(toggleValue != nil ? .primary : .secondary)
      }
      if let myFruits = fruits {
        List(myFruits, id: \.self) { fruit in
          Text(fruit)
        }
      }
      List {
          ForEach(sessions!.sorted(by: >), id: \.key) { key, value in
            Section(header: Text(key)) {
              Text(value)
            }
          }
        }
      if let recipe {
        List {
          Text(recipe.recipe_name)
          Text(recipe.notes)
          Text("cook time: \(recipe.cook_time)")
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
