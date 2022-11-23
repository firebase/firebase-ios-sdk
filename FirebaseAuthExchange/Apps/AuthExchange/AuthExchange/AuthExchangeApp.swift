// Copyright 2022 Google LLC
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

import SwiftUI
import FirebaseAuthExchange
import FirebaseInstallations
import FirebaseCore

let testAsync = true

class AppDelegate: NSObject, UIApplicationDelegate, AuthExchangeDelegate {
  func refreshAuthExchangeToken(completion: @escaping (AuthExchangeToken?, Error?) -> Void) {
    if testAsync {
      Task {
        do {
          // or `try await self.obtainAuthExchangeTokenWithCustomProvider()`
          let authExchangeToken = try await self.obtainAuthExchangeTokenAsync()
          completion(authExchangeToken, nil)
        } catch {
          completion(nil, error)
        }
      }

    } else {
      obtainAuthExchangeToken(completion: completion)
    }
  }

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [
                     UIApplication.LaunchOptionsKey: Any
                   ]? = nil) -> Bool {
    FirebaseApp.configure()
    let authExchange = AuthExchange.authExchange()
    authExchange.authExchangeDelegate = self

    authExchange.tryDelegate()
    authExchange.clearAuthExchangeToken()
    return true
  }

  func obtainAuthExchangeToken(completion: @escaping (AuthExchangeToken?, Error?) -> Void) {
    Installations.installations().authToken(completion: { installationResult, error in
      if let error = error {
        print("Installations.authToken() failure: \(error).")
        completion(nil, error)
        return
      }
      guard let installationResult = installationResult else {
        print("Installations.authToken() failure: Empty result")
        return
      }
      AuthExchange.authExchange()
        .exchange(installationsToken: installationResult.authToken, handler: { result, error in
          if let error = error {
            print("AuthExchange.exchange(installationsToken:) failure")
            completion(nil, error)
          } else {
            print("AuthExchange.exchange(installationsToken:) success")
            completion(result?.authExchangeToken, nil)
          }
        })
    })
  }

  func obtainAuthExchangeTokenAsync() async throws -> AuthExchangeToken? {
    do {
      let result = try await Installations.installations().authToken()
      do {
        let authExchangeResult = try await AuthExchange.authExchange()
          .exchange(installationsToken: result.authToken)
        return authExchangeResult?.authExchangeToken ?? AuthExchangeToken(
          token: "",
          expirationDate: Date()
        )
      } catch {
        print("AuthExchange.exchange(installationsToken:) failure")
      }
    } catch {
      print("Installations.authToken() failure: \(error).")
    }
    return nil
  }
}

@main
struct AuthExchangeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
