//
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
//

import FirebaseCrashlytics
import Foundation
import SwiftUI

struct CrashButtonView: View {
  var body: some View {
    var counter = 0

    NavigationView {
      VStack(
        alignment: .leading,
        spacing: 10
      ) {
        Button(action: {
          Crashlytics.crashlytics().setUserID("ThisIsABot")
        }) {
          Text("Set User Id")
        }

        Button(action: {
          assertionFailure("Throw a Crash")
        }) {
          Text("Crash")
        }

        Button(action: {
          Crashlytics.crashlytics().record(error: NSError(
            domain: "This is a test non-fatal",
            code: 400
          ))
        }) {
          Text("Record Non-fatal event")
        }

        Button(action: {
          Crashlytics.crashlytics().setCustomValue(counter, forKey: "counter " + String(counter))
          let i = counter
          counter = i + 1
        }) {
          Text("Set custom key")
        }
      }
      .navigationTitle("Crashlytics Example")
    }
  }
}
