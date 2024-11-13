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

/// Public representation of a credential.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRAuthCredential) open class AuthCredential: NSObject, @unchecked Sendable {
  /// The name of the identity provider for the credential.
  @objc public let provider: String

  init(provider: String) {
    self.provider = provider
  }

  func prepare(_ request: VerifyAssertionRequest) {
    fatalError("This method must be overridden by a subclass.")
  }
}
