// Copyright 2023 Google LLC
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
import FirebaseAppCheckInterop
@_implementationOnly import FirebaseCore

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@objc(FIRAuthProvider) public protocol AuthProvider {
  @objc func auth() -> Auth
}

@objc(FIRAuthComponent) class AuthComponent: NSObject, Library, AuthProvider {
  // MARK: - Private Variables

  /// The app associated with all Auth instances in this container.
  private let app: FirebaseApp

  /// A map of active instances, grouped by app. Keys are FirebaseApp names and values are arrays
  /// containing all instances of Auth associated with the given app.
  private var instances: [String: Auth] = [:]

  /// Lock to manage access to the instances array to avoid race conditions.
  private var instancesLock: os_unfair_lock = .init()

  // MARK: - Initializers

  required init(app: FirebaseApp) {
    self.app = app
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    let appCheckInterop = Dependency(with: AppCheckInterop.self, isRequired: false)
    return [Component(AuthProvider.self,
                      instantiationTiming: .lazy,
                      dependencies: [
                        appCheckInterop,
                      ]) { container, isCacheable in
        guard let app = container.app else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }

  // MARK: - AuthProvider conformance

  func auth() -> Auth {
    os_unfair_lock_lock(&instancesLock)

    // Unlock before the function returns.
    defer { os_unfair_lock_unlock(&instancesLock) }

    if let instance = instances[app.name] {
      return instance
    }
    let newInstance = Auth.Auth(app: app)
    instances[app.name] = newInstance
    return newInstance
  }
}
