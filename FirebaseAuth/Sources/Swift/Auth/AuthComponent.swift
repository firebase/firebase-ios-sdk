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
import FirebaseAuthInterop
import FirebaseCore
import FirebaseCoreExtension

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRAuthComponent)
class AuthComponent: NSObject, Library, ComponentLifecycleMaintainer {
  // MARK: - Private Variables

  /// The app associated with all Auth instances in this container.
  /// This is `unowned` instead of `weak` so it can be used without unwrapping in `auth()`
  private unowned let app: FirebaseApp

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
    let authCreationBlock: ComponentCreationBlock = { container, isCacheable in
      guard let app = container.app else { return nil }
      isCacheable.pointee = true
      return Auth(app: app)
    }
    let authInterop = Component(AuthInterop.self,
                                instantiationTiming: .alwaysEager,
                                creationBlock: authCreationBlock)
    return [authInterop]
  }

  // MARK: - AuthProvider conformance

  @discardableResult func auth() -> Auth {
    os_unfair_lock_lock(&instancesLock)

    // Unlock before the function returns.
    defer { os_unfair_lock_unlock(&instancesLock) }

    if let instance = instances[app.name] {
      return instance
    }
    let newInstance = Auth(app: app)
    instances[app.name] = newInstance
    return newInstance
  }

  // MARK: - ComponentLifecycleMaintainer conformance

  func appWillBeDeleted(_ app: FirebaseApp) {
    kAuthGlobalWorkQueue.async {
      // This doesn't stop any request already issued, see b/27704535

      if let keychainServiceName = Auth.deleteKeychainServiceNameForAppName(app.name) {
        let keychain = AuthKeychainServices(
          service: keychainServiceName,
          storage: AuthKeychainStorageReal.shared
        )
        let userKey = "\(app.name)_firebase_user"
        try? keychain.removeData(forKey: userKey)
      }
      DispatchQueue.main.async {
        // TODO(ObjC): Move over to fire an event instead, once ready.
        NotificationCenter.default.post(name: Auth.authStateDidChangeNotification, object: nil)
      }
    }
  }
}
