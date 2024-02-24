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

import FirebaseAppCheck
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]?) -> Bool {
    let providerFactory = AppCheckDebugProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)

    FirebaseApp.configure()

    requestLimitedUseToken()

    requestDeviceCheckToken()

    requestDebugToken()

    if #available(iOS 14.0, *) {
      requestAppAttestToken()
    }

    return true
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

    DeviceCheckProvider(app: firebaseApp)?.getToken { token, error in
      if let token {
        print("DeviceCheck token: \(token.token), expiration date: \(token.expirationDate)")
      }

      if let error {
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

      debugProvider.getToken { token, error in
        if let token {
          print("Debug FAC token: \(token.token), expiration date: \(token.expirationDate)")
        }

        if let error {
          print("Debug error: \(error)")
        }
      }
    }
  }

  // MARK: App Check API

  func requestLimitedUseToken() {
    AppCheck.appCheck().limitedUseToken { result, error in
      if let result {
        print("FAC limited-use token: \(result.token), expiration date: \(result.expirationDate)")
      }

      if let error {
        print("Error: \(String(describing: error))")
      }
    }
  }

  @available(iOS 14.0, *)
  func requestAppAttestToken() {
    guard let firebaseApp = FirebaseApp.app() else {
      return
    }

    guard let appAttestProvider = AppAttestProvider(app: firebaseApp) else {
      print("Failed to instantiate AppAttestProvider")
      return
    }

    appAttestProvider.getToken { token, error in
      if let token {
        print("App Attest FAC token: \(token.token), expiration date: \(token.expirationDate)")
      }

      if let error {
        print("App Attest error: \(error)")
      }
    }
  }
}
