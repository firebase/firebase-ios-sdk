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

/// Determines settings related to an auth object.
@objc(FIRAuthSettings) open class AuthSettings: NSObject, NSCopying {
  /// Flag to determine whether app verification should be disabled for testing or not.
  @objc open var appVerificationDisabledForTesting: Bool

  /// Flag to determine whether app verification should be disabled for testing or not.
  @objc open var isAppVerificationDisabledForTesting: Bool {
    get {
      return appVerificationDisabledForTesting
    }
    set {
      appVerificationDisabledForTesting = newValue
    }
  }

  override init() {
    appVerificationDisabledForTesting = false
  }

  // MARK: NSCopying

  open func copy(with zone: NSZone? = nil) -> Any {
    let settings = AuthSettings()
    settings.appVerificationDisabledForTesting = appVerificationDisabledForTesting
    return settings
  }
}
