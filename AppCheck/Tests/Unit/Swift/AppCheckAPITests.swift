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

import FirebaseCore
import AppCheck

final class AppCheckAPITests {
  func usage() {
    // MARK: - AppAttestProvider

    #if TARGET_OS_IOS
      if #available(iOS 14.0, *) {
        if let app = FirebaseApp.app(), let provider = AppAttestProvider(app: app) {
          provider.getToken { token, error in
            // ...
          }
        }
      }
    #endif // TARGET_OS_IOS

    // MARK: - AppCheck

    // `AppCheckTokenDidChange` & associated notification keys
    _ = NotificationCenter.default
      .addObserver(
        forName: .InternalAppCheckTokenDidChange,
        object: nil,
        queue: .main
      ) { notification in
        _ = notification.userInfo?[InternalAppCheckTokenNotificationKey]
        _ = notification.userInfo?[InternalAppCheckAppNameNotificationKey]
      }

    guard let app = FirebaseApp.app() else { return }

    // Retrieving an AppCheck instance
    let appCheck = InternalAppCheck(app: app, appCheckProvider: DummyAppCheckProvider())

    // Get token
    appCheck.token(forcingRefresh: false) { token, error in
      if let _ /* error */ = error {
        // ...
      } else if let _ /* token */ = token {
        // ...
      }
    }

    // Get token (async/await)
    #if compiler(>=5.5.2) && canImport(_Concurrency)
      if #available(iOS 13.0, macOS 11.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            try await appCheck.token(forcingRefresh: false)
          } catch {
            // ...
          }
        }
      }
    #endif // compiler(>=5.5.2) && canImport(_Concurrency)

    // Get & Set `isTokenAutoRefreshEnabled`
    _ = appCheck.isTokenAutoRefreshEnabled
    appCheck.isTokenAutoRefreshEnabled = false

    // MARK: - `AppCheckDebugProvider`

    // `AppCheckDebugProvider` initializer
    if let app = FirebaseApp.app(), let debugProvider = InternalAppCheckDebugProvider(app: app) {
      // Get token
      debugProvider.getToken { token, error in
        if let _ /* error */ = error {
          // ...
        } else if let _ /* token */ = token {
          // ...
        }
      }

      // Get token (async/await)
      #if compiler(>=5.5.2) && canImport(_Concurrency)
        if #available(iOS 13.0, macOS 11.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
          // async/await is a Swift 5.5+ feature available on iOS 15+
          Task {
            do {
              _ = try await debugProvider.getToken()
            } catch {
              // ...
            }
          }
        }
      #endif // compiler(>=5.5.2) && canImport(_Concurrency)

      _ = debugProvider.localDebugToken()
      _ = debugProvider.currentDebugToken()
    }

    // MARK: - AppCheckToken

    let token = InternalAppCheckToken(token: "token", expirationDate: Date.distantFuture)
    _ = token.token
    _ = token.expirationDate

    // MARK: - AppCheckErrors

    appCheck.token(forcingRefresh: false) { _, error in
      if let error = error {
        switch error {
        case InternalAppCheckErrorCode.unknown:
          break
        case InternalAppCheckErrorCode.serverUnreachable:
          break
        case InternalAppCheckErrorCode.invalidConfiguration:
          break
        case InternalAppCheckErrorCode.keychain:
          break
        case InternalAppCheckErrorCode.unsupported:
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

    // MARK: - DeviceCheckProvider

    // `DeviceCheckProvider` initializer
    #if !os(watchOS)
      if #available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, *) {
        if let app = FirebaseApp.app(),
           let deviceCheckProvider = InternalDeviceCheckProvider(app: app) {
          // Get token
          deviceCheckProvider.getToken { token, error in
            if let _ /* error */ = error {
              // ...
            } else if let _ /* token */ = token {
              // ...
            }
          }
          // Get token (async/await)
          #if compiler(>=5.5.2) && canImport(_Concurrency)
            if #available(iOS 13.0, macOS 11.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
              // async/await is a Swift 5.5+ feature available on iOS 15+
              Task {
                do {
                  _ = try await deviceCheckProvider.getToken()
                } catch InternalAppCheckErrorCode.unsupported {
                  // ...
                } catch {
                  // ...
                }
              }
            }
          #endif // compiler(>=5.5.2) && canImport(_Concurrency)
        }
      }
    #endif // !os(watchOS)
  }
}

class DummyAppCheckProvider: NSObject, InternalAppCheckProvider {
  func getToken(completion handler: @escaping (InternalAppCheckToken?, Error?) -> Void) {
    handler(InternalAppCheckToken(token: "token", expirationDate: .distantFuture), nil)
  }
}
