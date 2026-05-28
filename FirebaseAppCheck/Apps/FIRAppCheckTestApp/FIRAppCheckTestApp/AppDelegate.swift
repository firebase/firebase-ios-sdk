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

import UIKit

import AppCheckCore
import FirebaseAppCheck
import FirebaseCore
import FirebaseStorage

class AppDelegate: UIResponder, UIApplicationDelegate {
  private(set) static var shared: AppDelegate?

  override init() {
    super.init()
    AppDelegate.shared = self
  }

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]?) -> Bool {
    // Manual override for testing/debugging.
    // Change this to explicitly set a provider, or leave nil to use environment variable.
    let manualProviderOverride: String? = nil // e.g., "debug" or "recaptcha"

    let options = setupAppCheck(overrideProvider: manualProviderOverride)

    FirebaseApp.configure(options: options)

    return true
  }

  private func setupAppCheck(overrideProvider: String?) -> FirebaseOptions {
    // Note: If running via `xcodebuild test`, pass this with the `TEST_RUNNER_` prefix
    // (e.g., `TEST_RUNNER_APP_CHECK_PROVIDER="debug"`). Xcode strips the prefix at runtime.
    let providerType = overrideProvider ?? ProcessInfo.processInfo
      .environment["APP_CHECK_PROVIDER"] ?? "debug"

    if overrideProvider == nil && ProcessInfo.processInfo.environment["APP_CHECK_PROVIDER"] == nil {
      print("⚠️ Warning: APP_CHECK_PROVIDER environment variable is missing. Defaulting to 'debug'.")
    }

    print("Info: Using App Check provider: '\(providerType)'")

    guard let options = FirebaseOptions.defaultOptions() else {
      fatalError("Failed to load default Firebase options. Ensure GoogleService-Info.plist is added to the project.")
    }

    let providerFactory: AppCheckProviderFactory
    switch providerType {
    case "recaptcha":
      guard let siteKey = ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"],
            !siteKey.isEmpty else {
        fatalError(
          "Error: RECAPTCHA_SITE_KEY environment variable is missing or empty. E2E tests require this key."
        )
      }
      options.recaptchaSiteKey = siteKey
      providerFactory = RecaptchaEnterpriseProviderFactory()
    case "debug":
      providerFactory = AppCheckDebugProviderFactory()
    default:
      print(
        "Warning: Unknown APP_CHECK_PROVIDER '\(providerType)'. Falling back to Debug provider."
      )
      providerFactory = AppCheckDebugProviderFactory()
    }

    AppCheck.setAppCheckProviderFactory(providerFactory)

    return options
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication,
                   configurationForConnecting connectingSceneSession: UISceneSession,
                   options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }

  func application(_ application: UIApplication,
                   didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called
    // shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they
    // will not return.
  }

  // MARK: App Check providers

  func requestDeviceCheckToken() {
    guard let firebaseApp = FirebaseApp.app() else {
      return
    }

    Task {
      do {
        if let provider = DeviceCheckProvider(app: firebaseApp) {
          let token = try await provider.getToken()
          print("DeviceCheck token: \(token.token), expiration date: \(token.expirationDate)")
        }
      } catch {
        print("DeviceCheck error: \((error as NSError).userInfo)")
      }
    }
  }

  func requestDebugToken() {
    guard let firebaseApp = FirebaseApp.app() else {
      return
    }

    if let debugProvider = AppCheckDebugProvider(app: firebaseApp) {
      print("Debug token: \(debugProvider.currentDebugToken())")

      Task {
        do {
          let token = try await debugProvider.getToken()
          print("Debug FAC token: \(token.token), expiration date: \(token.expirationDate)")
        } catch {
          print("Debug error: \(error)")
        }
      }
    }
  }

  // MARK: App Check API

  @discardableResult
  func fetchAppCheckToken(forcingRefresh: Bool = false) async throws -> AppCheckToken {
    let token = try await AppCheck.appCheck().token(forcingRefresh: forcingRefresh)

    let ttl = token.expirationDate.timeIntervalSinceNow
    print("[NON-LIMITED USE] Token: \(token.token)")
    print("  - Expiration date: \(token.expirationDate)")
    print("  - TTL: \(Int(ttl)) seconds")

    try await readFromStorage()

    return token
  }

  func readFromStorage() async throws {
    print("Attempting to read from Cloud Storage...")
    let storage = Storage.storage()
    let storageRef = storage.reference()
    // NOTE: This path corresponds to the security rules configured for the test project.
    // The rules allow public read on '/cep/ping'. If these rules change, this test may fail.
    let pingRef = storageRef.child("cep/ping")

    let data = try await pingRef.data(maxSize: 1 * 1024 * 1024)

    // This shouldn't be possible, but we want to know if it ever happens.
    guard let string = String(data: data, encoding: .utf8) else {
      fatalError(
        "Unexpected state: data is not valid UTF-8. This shouldn't happen, but we want to know if it does."
      )
    }

    print("Storage content: \(string)")
  }

  func requestLimitedUseToken() async throws -> String {
    let result = try await AppCheck.appCheck().limitedUseToken()
    print("[LIMITED USE] Token: \(result.token)")
    print("  - Expiration date: \(result.expirationDate)")
    return result.token
  }

  func requestAppAttestToken() {
    guard let firebaseApp = FirebaseApp.app() else {
      return
    }

    guard let appAttestProvider = AppAttestProvider(app: firebaseApp) else {
      print("Failed to instantiate AppAttestProvider")
      return
    }

    Task {
      do {
        let token = try await appAttestProvider.getToken()
        print("App Attest FAC token: \(token.token), expiration date: \(token.expirationDate)")
      } catch {
        print("App Attest error: \(error)")
      }
    }
  }
}
