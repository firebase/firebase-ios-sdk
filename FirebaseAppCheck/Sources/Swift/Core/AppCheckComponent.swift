// Copyright 2026 Google LLC
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

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import FirebaseCoreExtension

/// Registers App Check with Firebase Core.
///
/// The Objective-C class name is load-bearing: `FirebaseCore` registers this class by name in
/// `+[FIRApp registerSwiftComponents]` and removes it, by name, for apps created by the ARCore SDK.
@objc(FIRAppCheckComponent)
final class AppCheckComponent: NSObject, Library {
  static func componentsToRegister() -> [Component] {
    let creationBlock: ComponentCreationBlock = { container, isCacheable in
      isCacheable.pointee = true
      guard let app = container.app else { return nil }
      return AppCheck(app: app)
    }
    // Use eager instantiation timing to give a chance for FAC token to be requested before it is
    // actually needed to avoid extra delaying dependent requests.
    let appCheckProvider = Component(AppCheckInterop.self,
                                     instantiationTiming: .alwaysEager,
                                     creationBlock: creationBlock)
    return [appCheckProvider]
  }
}
