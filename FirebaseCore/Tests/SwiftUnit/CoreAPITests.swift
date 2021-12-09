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

final class CoreAPITests {
  func usage() {
    // MARK: - FirebaseApp

    // Configure Firebase app
    FirebaseApp.configure()

    if let options = FirebaseOptions(contentsOfFile: "path/to/GoogleService-Info.plist") {
      FirebaseApp.configure(name: "App", options: options)
      FirebaseApp.configure(options: options)
    }

    // Retrieve Firebase app(s)
    if let _ /* app */ = FirebaseApp.app() {
      // ...
    }

    if let _ /* app */ = FirebaseApp.app(name: "App") {
      // ...
    }

    if let _ /* apps */ = FirebaseApp.allApps {
      // ...
    }

    // Delete Firebase app
    if let app = FirebaseApp.app() {
      app.delete { _ /* succes */ in
        // ...
      }

      #if compiler(>=5.5) && canImport(_Concurrency)
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
          // async/await is a Swift 5.5+ feature available on iOS 15+
          Task {
            await app.delete()
          }
        }
      #endif // compiler(>=5.5) && canImport(_Concurrency)
    }

    // Properties
    if let app = FirebaseApp.app() {
      _ = app.name
      _ = app.options
      _ = app.isDataCollectionDefaultEnabled
      app.isDataCollectionDefaultEnabled = false
    }

    // MARK: - FirebaseConfiguration

    _ = FirebaseConfiguration.shared
    FirebaseConfiguration.shared.setLoggerLevel(.debug)

    // MARK: - FirebaseLoggerLevel

    let loggerLevel: FirebaseLoggerLevel = .debug
    switch loggerLevel {
    case FirebaseLoggerLevel.error:
      break
    case FirebaseLoggerLevel.warning:
      break
    case FirebaseLoggerLevel.notice:
      break
    case FirebaseLoggerLevel.info:
      break
    case FirebaseLoggerLevel.debug:
      break
    default:
      break
    }

    _ = FirebaseLoggerLevel.min
    _ = FirebaseLoggerLevel.max

    // MARK: - FirebaseOptions

    // FirebaseOptions default instance
    if let _ /* defaultOptions */ = FirebaseOptions.defaultOptions() {
      // ...
    }

    // FirebaseOptions initializers
    _ = FirebaseOptions(googleAppID: "googleAppID", gcmSenderID: "gcmSenderID")

    if let _ /* options */ = FirebaseOptions(contentsOfFile: "path/to/file") {
      // ...
    }

    // Properties
    if let options = FirebaseOptions.defaultOptions() {
      _ = options.bundleID
      _ = options.gcmSenderID
      _ = options.googleAppID

      if let _ /* apiKey */ = options.apiKey {
        // ...
      }

      if let _ /* clientID */ = options.clientID {
        // ...
      }

      if let _ /* trackingID */ = options.trackingID {
        // ...
      }

      if let _ /* projectID */ = options.projectID {
        // ...
      }

      if let _ /* androidClientID */ = options.androidClientID {
        // ...
      }

      if let _ /* databaseURL */ = options.databaseURL {
        // ...
      }

      if let _ /* deepLinkURLScheme */ = options.deepLinkURLScheme {
        // ...
      }

      if let _ /* storageBucket */ = options.storageBucket {
        // ...
      }

      if let _ /* appGroupID */ = options.appGroupID {
        // ...
      }
    }

    // MARK: - FirebaseVersion

    _ = FirebaseVersion()
  }
}
