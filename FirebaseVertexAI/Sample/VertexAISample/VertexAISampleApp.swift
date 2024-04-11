// Copyright 2023 Google LLC
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
import SwiftUI

@main
struct VertexAISampleApp: App {
  init() {
    FirebaseApp.configure()

    if let firebaseApp = FirebaseApp.app(), firebaseApp.options.projectID == "mockproject-1234" {
      guard let bundleID = Bundle.main.bundleIdentifier else { fatalError() }
      fatalError("You must create and/or download a valid `GoogleService-Info.plist` file for"
        + " \(bundleID) from https://console.firebase.google.com to run this sample. Replace the"
        + " existing `GoogleService-Info.plist` file in the `FirebaseVertexAI/Sample` directory"
        + " with this new file.")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
