/*
 * Copyright 2021 Google LLC
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

import FirebaseAppCheck
import FirebaseCore
import Foundation

class MyAppCheckProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping AppCheckTokenHandler) {
    DispatchQueue.main.async {
      // Create or request Firebase App Check token. Usually the token is requested from your
      // server.
      let myToken = AppCheckToken(
        token: "MyToken",
        expirationDate: Date(timeIntervalSinceNow: 60 * 60)
      )

      // Pass the token or error to the completion handler.
      handler(myToken, nil)
    }
  }
}

// AppCheckProviderFactory is needed for Firebase to create app check providers as needed.
class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    // Different app check providers can be used for different Firebase apps.
    switch app.name {
    case "my-device-check-app":
      return FIRAppCheckDebugProvider(app: app)
    default:
      return MyAppCheckProvider()
    }
  }
}
