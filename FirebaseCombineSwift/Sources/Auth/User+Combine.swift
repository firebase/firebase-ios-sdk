// Copyright 2021 Google LLC
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

#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseAuth)

  import Combine
  import FirebaseAuth

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  extension User {
    /// Associates a user account from a third-party identity provider with this user and
    /// returns additional identity provider data.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter credential: The credential for the identity provider.
    /// - Returns: A publisher that emits an `AuthDataResult` when the association flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `FIRAuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a type
    ///     already linked to this account.
    ///   - `FIRAuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a credential
    ///     that has already been linked with a different Firebase account.
    ///   - `FIRAuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity provider
    ///     represented by the credential are not enabled. Enable them in the Auth section of the Firebase console.
    ///
    ///   See `FIRAuthErrors` for a list of error codes that are common to all FIRUser methods.
    public func link(with credential: AuthCredential) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.link(with: credential) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }
  }
#endif
