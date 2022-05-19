/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseAuth
import Foundation

#if compiler(>=5.5.2) && canImport(_Concurrency)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  /// Used to obtain an auth credential via a mobile web flow.
  ///
  /// - Parameter uiDelegate: An optional UI delegate used to present the mobile web flow.
  /// - Throws:
  ///   - An error if the operation failed.
  /// - Returns: An `AuthCredential` when the credential is obtained.
  public extension OAuthProvider {
    func getCredentialWith(_ UIDelegate: AuthUIDelegate?) async throws -> AuthCredential {
      try await withCheckedThrowingContinuation { continuation in
        self.getCredentialWith(nil) { credential, error in
          if let error = error {
              continuation.resume(throwing: error)
          } else if let credential = credential {
              continuation.resume(returning: credential)
          }
        }
      }
    }
  }
#endif // canImport(Combine) && swift(>=5.0)
