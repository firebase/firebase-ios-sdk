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

@objc(FIRCombineProvider)
protocol CombineProvider {
}

@objc(FIRCombineComponent) class CombineComponent: NSObject, Library, CombineProvider {
  // MARK: - Private Variables

  /// The app associated with all functions instances in this container.
  private let app: FirebaseApp

  // MARK: - Initializers

  required init(app: FirebaseApp) {
    self.app = app
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    return [Component(CombineProvider.self,
                      instantiationTiming: .lazy,
                      dependencies: [ /* authInterop */ ]) { container, isCacheable in
        guard let app = container.app else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }
}
