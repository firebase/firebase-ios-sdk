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
import FirebaseInstallations

final class InstallationsAPITests {
  func usage() {
    // MARK: - Installations

    // `InstallationIDDidChange` & associated notification keys
    _ = NotificationCenter.default
      .addObserver(
        forName: .InstallationIDDidChange,
        object: nil,
        queue: .main
      ) { notification in
        _ = notification.userInfo?[InstallationIDDidChangeAppNameKey]
      }

    // Retrieving an Installations instance
    _ = Installations.installations()

    if let app = FirebaseApp.app() {
      _ = Installations.installations(app: app)
    }

    // Create or retrieve an installations ID
    Installations.installations().installationID { id, error in
      if let _ /* id */ = id {
        // ...
      } else if let _ /* error */ = error {
        // ...
      }
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            try await Installations.installations().installationID()
          } catch {
            // ...
          }
        }
      }
    #endif // compiler(>=5.5) && canImport(_Concurrency)

    // Retrieves an installation auth token
    Installations.installations().authToken { result, error in
      if let _ /* result */ = result {
        // ...
      } else if let _ /* error */ = error {
        // ...
      }
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            _ = try await Installations.installations().authToken()
          } catch {
            // ...
          }
        }
      }
    #endif // compiler(>=5.5) && canImport(_Concurrency)

    // Retrieves an installation auth token with forcing refresh parameter
    Installations.installations().authTokenForcingRefresh(true) { result, error in
      if let _ /* result */ = result {
        // ...
      } else if let _ /* error */ = error {
        // ...
      }
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            _ = try await Installations.installations().authTokenForcingRefresh(true)
          } catch {
            // ...
          }
        }
      }
    #endif // compiler(>=5.5) && canImport(_Concurrency)

    // Delete installation data
    Installations.installations().delete { error in
      if let _ /* error */ = error {
        // ...
      }
    }

    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            _ = try await Installations.installations().delete()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // MARK: -  InstallationsAuthTokenResult

    Installations.installations().authToken { result, _ in
      if let result = result {
        _ = result.expirationDate
        _ = result.authToken
      }
    }

    // MARK: - InstallationsErrorCode

    Installations.installations().authToken { _, error in
      if let error = error {
        switch (error as NSError).code {
        case Int(InstallationsErrorCode.unknown.rawValue):
          break
        case Int(InstallationsErrorCode.keychain.rawValue):
          break
        case Int(InstallationsErrorCode.serverUnreachable.rawValue):
          break
        case Int(InstallationsErrorCode.invalidConfiguration.rawValue):
          break
        default:
          break
        }
      }
    }
  }
}
