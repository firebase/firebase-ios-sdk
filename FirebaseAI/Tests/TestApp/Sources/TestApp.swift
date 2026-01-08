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

import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore
import SwiftUI
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

#if canImport(FoundationModels)
  @Generable
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  struct Person: FirebaseGenerable {
    let firstName: String
    let middleName: String?
    let lastName: String
    let age: Int
  }
#endif // canImport(FoundationModels)

@main
struct TestApp: App {
  init() {
    AppCheck.setAppCheckProviderFactory(TestAppCheckProviderFactory())

    // Configure default Firebase App
    FirebaseApp.configure()

    // Configure a Firebase App that is the same as the default app but without App Check.
    // This is used for tests that should fail when App Check is not configured.
    FirebaseApp.configure(
      appName: FirebaseAppNames.appCheckNotConfigured,
      plistName: "GoogleService-Info"
    )

    // Configure a Firebase App without a billing account (i.e., the "Spark" plan).
    FirebaseApp.configure(appName: FirebaseAppNames.spark, plistName: "GoogleService-Info-Spark")

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        let schemaJSONData: Data
        do {
          schemaJSONData = try JSONEncoder().encode(Person.jsonSchema)
          if let schemaJSON = String(data: schemaJSONData, encoding: .utf8) {
            print("Person Schema: \(schemaJSON)")
          }
        } catch {
          print(error)
        }
      }
    #endif // canImport(FoundationModels)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
