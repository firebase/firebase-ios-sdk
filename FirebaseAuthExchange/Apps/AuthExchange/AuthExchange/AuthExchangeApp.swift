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
  func refreshToken(authExchange: AuthExchange,
                    completion: @escaping (AuthExchangeToken?, Error?) -> Void) {
    if testAsync {
      Task {
        do {
          // or `try await self.obtainAuthExchangeTokenWithCustomProvider()`
          let authExchangeToken = try await self
            .obtainAuthExchangeTokenAsync(authExchange: authExchange)
          completion(authExchangeToken, nil)
        } catch {
          completion(nil, error)
        }
      }

    } else {
      obtainAuthExchangeToken(authExchange: authExchange, completion: completion)
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
    authExchange.clearState()
    return true
  }

  func obtainAuthExchangeToken(authExchange: AuthExchange,
                               completion: @escaping (AuthExchangeToken?, Error?) -> Void) {
    authExchange
      .updateWithInstallationsToken(completion: { result, error in
        if let error = error {
          print("AuthExchange.updateWithInstallationsToken() failure")
          completion(nil, error)
        } else {
          print("AuthExchange.updateWithInstallationsToken() success")
          completion(result?.authExchangeToken, nil)
        }
      })
  }

  func obtainAuthExchangeTokenAsync(authExchange: AuthExchange) async throws -> AuthExchangeToken? {
    do {
      let authExchangeResult = try await authExchange.updateWithInstallationsToken()
      print("AuthExchange.updateWithInstallationsToken() success")
      return authExchangeResult.authExchangeToken
    } catch {
      print("AuthExchange.updateWithInstallationsToken() failure")
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
