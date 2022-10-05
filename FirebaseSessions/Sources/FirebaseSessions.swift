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

import Foundation
import FirebaseCore

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@objc(FIRSessionsProvider)
protocol SessionsProvider {
  @objc static func sessions() -> Void
}

@objc(FIRSessions) class Sessions: NSObject, Library, SessionsProvider {
  // MARK: - Private Variables

  /// The app associated with all sessions.
  private let googleAppID: String

  // MARK: - Initializers

  required init(app: FirebaseApp) {
    googleAppID = app.options.googleAppID
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    return [Component(SessionsProvider.self,
                      instantiationTiming: .alwaysEager,
                      dependencies: []) { container, isCacheable in
        // Sessions SDK only works for the default app
        guard let app = container.app, app.isDefaultApp else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }

  // MARK: - SessionsProvider conformance

  static func sessions() {}
}
