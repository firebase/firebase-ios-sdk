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

struct ContentView: View {
  @RemoteConfigProperty(forKey: "Color") var configValue : String
  @RemoteConfigProperty(forKey: "Toggle") var toggleValue : Bool
  @RemoteConfigProperty(forKey: "fruits") var fruits: [String]
  @RemoteConfigProperty(forKey: "counter") var counter: Int
  @RemoteConfigProperty(forKey: "mobileweek") var sessions: [String: String]

  var body: some View {
    VStack {
      if (counter > 1) {
        ForEach(1...counter, id: \.self) { i in
          Text(configValue)
            .padding()
            .foregroundStyle(toggleValue ? .primary : .secondary)
        }
      } else {
        Text(configValue)
          .padding()
          .foregroundStyle(toggleValue ? .primary : .secondary)
      }
      if (fruits.count > 0) {
        List(fruits, id: \.self) { fruit in
          Text(fruit)
        }
      }
      if (sessions.count > 0) {
        List {
          ForEach(sessions.sorted(by: >), id: \.key) { key, value in
            Section(header: Text(key)) {
              Text(value)
            }
          }
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
