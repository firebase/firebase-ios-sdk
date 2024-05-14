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

import FirebaseAppCheck
import FirebaseCore
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]? = nil) -> Bool {
    // Recommendation: Protect your Vertex AI API resources from abuse by preventing unauthorized
    // clients using App Check; see https://firebase.google.com/docs/app-check#get_started. Choose
    // one of the options below to pick between the Debug, DeviceCheck or App Attest providers.
    AppCheck.setAppCheckProviderFactory(AppCheckNotConfiguredFactory())

    // Option 1: Uncomment the following line to use the App Check Debug Provider; see
    // https://firebase.google.com/docs/app-check/ios/debug-provider#simulator for configuration
    // instructions.
    // AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())

    // Option 2: Uncomment the following line to use the DeviceCheck Provider; see
    // https://firebase.google.com/docs/app-check/ios/devicecheck-provider#project-setup for
    // configuration instructions.
    // AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())

    // Option 3: Uncomment the following line to use the App Attest Provider; see
    // https://firebase.google.com/docs/app-check/ios/app-attest-provider#project-setup for
    // configuration instructions.
    // AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())

    FirebaseApp.configure()

    if let firebaseApp = FirebaseApp.app(), firebaseApp.options.projectID == "mockproject-1234" {
      guard let bundleID = Bundle.main.bundleIdentifier else { fatalError() }
      fatalError("""
      You must create and/or download a valid `GoogleService-Info.plist` file for \(bundleID) from \
      https://console.firebase.google.com to run this sample. Replace the existing \
      `GoogleService-Info.plist` file in the `FirebaseVertexAI/Sample` directory with this new file.
      """)
    }

    return true
  }
}

@main
struct VertexAISampleApp: App {
  @UIApplicationDelegateAdaptor var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return AppAttestProvider(app: app)
  }
}

/// Placeholder App Check provider factory that returns a simple ``AppCheckNotConfigured`` error.
private class AppCheckNotConfiguredFactory: NSObject, AppCheckProviderFactory {
  private class AppCheckNotConfiguredProvider: NSObject, AppCheckProvider {
    func getToken() async throws -> AppCheckToken {
      throw AppCheckNotConfigured()
    }
  }

  func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    return AppCheckNotConfiguredProvider()
  }
}

/// Error indicating that App Check is not configured in the sample app.
struct AppCheckNotConfigured: Error {}
