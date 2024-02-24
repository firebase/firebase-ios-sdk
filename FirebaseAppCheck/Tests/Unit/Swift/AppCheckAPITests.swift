//
// Copyright 2021 Google LLC
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
//

// MARK: This file is used to evaluate the experience of using Firebase APIs in Swift.

import Foundation

import FirebaseAppCheck
import FirebaseCore

final class AppCheckAPITests {
  func usage() {
    // MARK: - AppAttestProvider

    if #available(iOS 14.0, macOS 11.3, macCatalyst 14.5, tvOS 15.0, watchOS 9.0, *) {
      if let app = FirebaseApp.app(), let provider = AppAttestProvider(app: app) {
        provider.getToken { token, error in
          // ...
        }
      }
    }

    // MARK: - AppCheck

    // `AppCheckTokenDidChange` & associated notification keys
    _ = NotificationCenter.default
      .addObserver(
        forName: .AppCheckTokenDidChange,
        object: nil,
        queue: .main
      ) { notification in
        _ = notification.userInfo?[AppCheckTokenNotificationKey]
        _ = notification.userInfo?[AppCheckAppNameNotificationKey]
      }

    // Retrieving an AppCheck instance
    _ = AppCheck.appCheck()

    if let app = FirebaseApp.app() {
      _ = AppCheck.appCheck(app: app)
    }

    // Get token
    AppCheck.appCheck().token(forcingRefresh: false) { token, error in
      if let _ /* error */ = error {
        // ...
      } else if let _ /* token */ = token {
        // ...
      }
    }

    // Get token (async/await)
    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
      Task {
        do {
          try await AppCheck.appCheck().token(forcingRefresh: false)
        } catch {
          // ...
        }
      }
    }

    // Set `AppCheckProviderFactory`
    AppCheck.setAppCheckProviderFactory(DummyAppCheckProviderFactory())

    // Get & Set `isTokenAutoRefreshEnabled`
    _ = AppCheck.appCheck().isTokenAutoRefreshEnabled
    AppCheck.appCheck().isTokenAutoRefreshEnabled = false

    // MARK: - `AppCheckDebugProvider`

    // `AppCheckDebugProvider` initializer
    if let app = FirebaseApp.app(), let debugProvider = AppCheckDebugProvider(app: app) {
      // Get token
      debugProvider.getToken { token, error in
        if let _ /* error */ = error {
          // ...
        } else if let _ /* token */ = token {
          // ...
        }
      }

      // Get token (async/await)
      if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
        // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
        Task {
          do {
            _ = try await debugProvider.getToken()
          } catch {
            // ...
          }
        }
      }

      _ = debugProvider.localDebugToken()
      _ = debugProvider.currentDebugToken()
    }

    // MARK: - AppCheckToken

    let token = AppCheckToken(token: "token", expirationDate: Date.distantFuture)
    _ = token.token
    _ = token.expirationDate

    // MARK: - AppCheckErrors

    AppCheck.appCheck().token(forcingRefresh: false) { _, error in
      if let error {
        switch error {
        case AppCheckErrorCode.unknown:
          break
        case AppCheckErrorCode.serverUnreachable:
          break
        case AppCheckErrorCode.invalidConfiguration:
          break
        case AppCheckErrorCode.keychain:
          break
        case AppCheckErrorCode.unsupported:
          break
        default:
          break
        }
      }
      // ...
    }

    // MARK: - AppCheckProvider

    // A protocol implemented by:
    // - `AppAttestDebugProvider`
    // - `AppCheckDebugProvider`
    // - `DeviceCheckProvider`

    // MARK: - AppCheckProviderFactory

    // A protocol implemented by:
    // - `AppCheckDebugProvider`
    // - `DeviceCheckProvider`

    // MARK: - DeviceCheckProvider

    // `DeviceCheckProvider` initializer
    #if !os(watchOS)
      if #available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, *) {
        if let app = FirebaseApp.app(), let deviceCheckProvider = DeviceCheckProvider(app: app) {
          // Get token
          deviceCheckProvider.getToken { token, error in
            if let _ /* error */ = error {
              // ...
            } else if let _ /* token */ = token {
              // ...
            }
          }
          // Get token (async/await)
          if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
            // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
            Task {
              do {
                _ = try await deviceCheckProvider.getToken()
              } catch AppCheckErrorCode.unsupported {
                // ...
              } catch {
                // ...
              }
            }
          }
        }
      }
    #endif // !os(watchOS)
  }
}

class DummyAppCheckProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    handler(AppCheckToken(token: "token", expirationDate: .distantFuture), nil)
  }
}

class DummyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return DummyAppCheckProvider()
  }
}
