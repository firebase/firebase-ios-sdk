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

import XCTest

import FirebaseCore
import FirebaseAppCheck

class AppCheckTests: XCTestCase {
  func usageExample() {
    AppCheck.setAppCheckProviderFactory(self)
    FirebaseApp.configure()

    let firebaseOptions = FirebaseOptions(contentsOfFile: "path")!
    FirebaseApp.configure(name: "AppName", options: firebaseOptions)

    AppCheck.appCheck().token(forcingRefresh: true) { token, error in
      // ...
    }
  }

  @available(iOS 14, *)
  func appAttestUsageExample() {
    if let app = FirebaseApp.app(), let provider = AppAttestProvider(app: app) {
      provider.getToken { token, error in
        // ...
      }
    }
  }

  #if swift(>=5.5)
    @available(iOS 14, *)
    func asyncAppAttestUsageExample() {
      if let app = FirebaseApp.app(), let provider = AppAttestProvider(app: app) {
        provider.getToken { token, error in
          // ...
        }
      }
    }

    func asyncGetTokenUsageExample() async throws {
      try await AppCheck.appCheck().token(forcingRefresh: true)
    }
  #endif // swift(>=5.5)
}

class DummyAppCheckProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    handler(AppCheckToken(token: "token", expirationDate: .distantFuture), nil)
  }
}

extension AppCheckTests: AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return DummyAppCheckProvider()
  }
}
