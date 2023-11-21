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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@objc(FIRStorageProvider)
protocol StorageProvider {
  @objc func storage(for bucket: String) -> Storage
}

@objc(FIRStorageComponent) class StorageComponent: NSObject, Library, StorageProvider {
  // MARK: - Private Variables

  /// The app associated with all Storage instances in this container.
  /// This is `unowned` instead of `weak` so it can be used without unwrapping in `storage(...)`
  private unowned let app: FirebaseApp

  /// A map of active instances, grouped by app. Keys are FirebaseApp names and values are arrays
  /// containing all instances of Storage associated with the given app.
  private var instances: [String: Storage] = [:]

  /// Lock to manage access to the instances array to avoid race conditions.
  private var instancesLock: os_unfair_lock = .init()

  // MARK: - Initializers

  required init(app: FirebaseApp) {
    self.app = app
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    let appCheckInterop = Dependency(with: AppCheckInterop.self, isRequired: false)
    let authInterop = Dependency(with: AuthInterop.self, isRequired: false)
    return [Component(StorageProvider.self,
                      instantiationTiming: .lazy,
                      dependencies: [
                        appCheckInterop,
                        authInterop,
                      ]) { container, isCacheable in
        guard let app = container.app else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }

  // MARK: - StorageProvider conformance

  func storage(for bucket: String) -> Storage {
    os_unfair_lock_lock(&instancesLock)

    // Unlock before the function returns.
    defer { os_unfair_lock_unlock(&instancesLock) }

    if let instance = instances[bucket] {
      return instance
    }
    let newInstance = FirebaseStorage.Storage(app: app, bucket: bucket)
    instances[bucket] = newInstance
    return newInstance
  }
}
