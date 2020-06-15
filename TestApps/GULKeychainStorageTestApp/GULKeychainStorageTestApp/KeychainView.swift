/*
 * Copyright 2020 Google LLC
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
import GoogleUtilities
import Promises

struct KeychainView: View {
  @ObservedObject var viewModel: KeychainViewModel

  var body: some View {
    HStack(alignment: .top) {
      VStack(alignment: .center, spacing: 10.0) {
        Button(action: {
          self.viewModel.readButtonPressed()
        }) {
          Text("Read from keychain")
            .padding(.vertical)
        }
        Button(action: {
          self.viewModel.generateAndSaveButtonPressed()
        }) {
          Text("Generate and store a random value")
            .padding(.vertical)
        }

        // Logs
        Text("Logs:")
          .multilineTextAlignment(.leading)

        GeometryReader { geometry in
          ScrollView {
            Text(self.viewModel.log)
              .font(.caption)
              .multilineTextAlignment(.leading)
              .frame(width: geometry.size.width)
          }
        }
      }
    }
  }

//  private func readStoredValue() {
//    storage.getValue()
//      .then { value in
//        self.log(message: "Get value: \(value ?? "nil")")
//        self.storedValue = value
//      }.catch { error in
//        self.storedValue = "Error: \(error)"
//        self.log(message: "Get value error: \(error)")
//      }
//  }
//
//  private func generateAndStoreRandomValue() {
//    storage.generateRandom()
//      .then { random -> Promise<Void> in
//        self.log(message: "Saved value: \(random)")
//        return self.storage.set(value: random)
//      }
//      .catch { error in
//        self.log(message: "Save value error: \(error)")
//      }
//  }
//
//  private func log(message: String) {
//    log = "\(message)\n\(log)"
//    print(message)
//  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    KeychainView(viewModel: KeychainViewModel())
  }
}
