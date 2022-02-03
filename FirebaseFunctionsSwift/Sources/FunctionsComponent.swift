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
import FirebaseCoreInternal

@objc(FIRFunctionsProvider)
protocol FunctionsProvider {
  @objc func functions(for app: FirebaseApp,
                       region: String?,
                       customDomain: String?,
                       type: AnyClass) -> Functions
  // TODO: See if we can avoid the `type` parameter by either making it a `Functions` argument to
  // allow subclasses, or avoid it entirely and fix tests. This was done for FunctionsCombineUnit,
  // although we may be able to now port to using `@testable` instead of using the mock.
}

@objc class FunctionsComponent: NSObject, Library, FunctionsProvider {
  // MARK: - Private Variables

  /// The app associated with all functions instances in this container.
  private let app: FirebaseApp

  /// A map of active instances, grouped by app. Keys are FirebaseApp names and values are arrays
  /// containing all instances of Functions associated with the given app.
  private let instances: [String: [Functions]] = [:]

  /// Lock to manage access to the instances array to avoid race conditions.
  private let instancesLock: os_unfair_lock = os_unfair_lock()

  // MARK: - Initializers
  required init(app: FirebaseApp) {
    self.app = app
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    // TODO: We don't actually add a dependency on FCM or AppCheck here even though it's used.. is
    // that okay?
    // TODO: Get Auth Interop Working, we need the type.
//    let authInterop = Dependency(with: AuthProvider.self, isRequired: false)
    return [Component(FunctionsProvider.self,
              instantiationTiming: .lazy,
              dependencies: [/*authInterop*/]) { container, isCacheable in
      guard let app = container.app else { return nil }
      isCacheable.pointee = true
      return self.init(app: app)
    }]
  }

  // MARK: - FunctionsProvider conformance

  func functions(for app: FirebaseApp,
                 region: String?,
                 customDomain: String?,
                 type: AnyClass) -> Functions {
    // TODO: Check local dictionary of instances first.

    // TODO: Slightly awkward usage now because of default arguments, we can't pass in an optional
    // region and it select the default for us. This if statement is fine though for the time being
    // to ensure they always stay up to date.
    if let region = region {
      return Functions(app: app, region: region, customDomain: customDomain)
    } else {
      // TODO: Fix this
      fatalError()
//      return Functions(app: app, customDomain: customDomain)
    }

  }
}
