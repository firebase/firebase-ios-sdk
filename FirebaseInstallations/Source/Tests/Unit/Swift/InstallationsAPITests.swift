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

    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
      Task {
        do {
          try await Installations.installations().installationID()
        } catch {
          // ...
        }
      }
    }

    // Retrieves an installation auth token
    Installations.installations().authToken { result, error in
      if let _ /* result */ = result {
        // ...
      } else if let _ /* error */ = error {
        // ...
      }
    }

    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
      Task {
        do {
          _ = try await Installations.installations().authToken()
        } catch {
          // ...
        }
      }
    }

    // Retrieves an installation auth token with forcing refresh parameter
    Installations.installations().authTokenForcingRefresh(true) { result, error in
      if let _ /* result */ = result {
        // ...
      } else if let _ /* error */ = error {
        // ...
      }
    }

    if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
      // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
      Task {
        do {
          _ = try await Installations.installations().authTokenForcingRefresh(true)
        } catch {
          // ...
        }
      }
    }

    // Delete installation data
    Installations.installations().delete { error in
      if let _ /* error */ = error {
        // ...
      }
    }

    #if swift(>=5.5)
      if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
        // async/await is a Swift Concurrency feature available on iOS 13+ and macOS 10.15+
        Task {
          do {
            _ = try await Installations.installations().delete()
          } catch let error as NSError
            where error.domain == InstallationsErrorDomain && error.code == InstallationsErrorCode
            .unknown.rawValue {
            // Above is the old way to handle errors.
          } catch InstallationsErrorCode.unknown {
            // Above is the new way to handle errors.
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
        // Old error handling.
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

        // New error handling.
        switch error {
        case InstallationsErrorCode.unknown:
          break
        case InstallationsErrorCode.keychain:
          break
        case InstallationsErrorCode.serverUnreachable:
          break
        case InstallationsErrorCode.invalidConfiguration:
          break

        default:
          break
        }
      }
    }
    func globalStringSymbols() {
      let _: String = InstallationIDDidChangeAppNameKey
      let _: String = InstallationsErrorDomain
    }
  }
}
