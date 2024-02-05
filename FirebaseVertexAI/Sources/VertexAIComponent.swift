// Copyright 2024 Google LLC
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
import FirebaseCore
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
@objc(FIRVertexAIProvider)
protocol VertexAIProvider {
  @objc func vertexAI(location: String, modelResourceName: String) -> VertexAI
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
@objc(FIRVertexAIComponent)
class VertexAIComponent: NSObject, Library, VertexAIProvider {
  // MARK: - Private Variables

  /// The app associated with all `VertexAI` instances in this container.
  /// This is `unowned` instead of `weak` so it can be used without unwrapping in `vertexAI(...)`
  private unowned let app: FirebaseApp

  /// A map of active  `VertexAI` instances for `app`, keyed by model resource names
  /// (e.g., "projects/my-project-id/locations/us-central1/publishers/google/models/gemini-pro").
  private var instances: [String: VertexAI] = [:]

  /// Lock to manage access to the `instances` array to avoid race conditions.
  private var instancesLock: os_unfair_lock = .init()

  // MARK: - Initializers

  required init(app: FirebaseApp) {
    self.app = app
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    let appCheckInterop = Dependency(with: AppCheckInterop.self, isRequired: false)
    return [Component(VertexAIProvider.self,
                      instantiationTiming: .lazy,
                      dependencies: [
                        appCheckInterop,
                      ]) { container, isCacheable in
        guard let app = container.app else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }

  // MARK: - VertexAIProvider conformance

  func vertexAI(location: String, modelResourceName: String) -> VertexAI {
    os_unfair_lock_lock(&instancesLock)

    // Unlock before the function returns.
    defer { os_unfair_lock_unlock(&instancesLock) }

    if let instance = instances[modelResourceName] {
      return instance
    }
    let newInstance = VertexAI(app: app, location: location, modelResourceName: modelResourceName)
    instances[modelResourceName] = newInstance
    return newInstance
  }
}
