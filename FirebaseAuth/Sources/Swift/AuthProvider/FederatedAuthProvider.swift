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

/// Utility type for constructing federated auth provider credentials.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRFederatedAuthProvider) public protocol FederatedAuthProvider: NSObjectProtocol {
  #if os(iOS)

    /// Used to obtain an auth credential via a mobile web flow.
    /// This method is available on iOS only.
    /// - Parameter uiDelegate: An optional UI delegate used to present the mobile web flow.
    /// - Parameter completionHandler: Optionally; a block which is invoked
    /// asynchronously on the main thread when the mobile web flow is
    /// completed.
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    @objc(getCredentialWithUIDelegate:completion:)
    func credential(with uiDelegate: AuthUIDelegate?) async throws -> AuthCredential
  #endif
}
