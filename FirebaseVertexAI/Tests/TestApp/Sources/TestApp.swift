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

import FirebaseAppCheck
import FirebaseCore
import SwiftUI

@main
struct TestApp: App {
  init() {
    AppCheck.setAppCheckProviderFactory(TestAppCheckProviderFactory())

    // Configure default Firebase App
    FirebaseApp.configure()

    // Configure a Firebase App without a billing account (i.e., the "Spark" plan).
    guard let plistPath =
      Bundle.main.path(forResource: "GoogleService-Info-Spark", ofType: "plist") else {
      fatalError("The file 'GoogleService-Info-Spark.plist' was not found.")
    }
    guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
      fatalError("Failed to parse options from 'GoogleService-Info-Spark.plist'.")
    }
    FirebaseApp.configure(name: FirebaseAppNames.spark, options: options)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
