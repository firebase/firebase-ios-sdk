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

#if os(iOS) || targetEnvironment(macCatalyst)

  import Combine
  import FirebaseAuth

  @available(iOS 13.0, macCatalyst 13.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension OAuthProvider {
    /// Used to obtain an auth credential via a mobile web flow.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter uiDelegate: An optional UI delegate used to present the mobile web flow.
    /// - Returns: A publisher that emits an `AuthCredential` when the credential is obtained
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    func getCredentialWith(_ uiDelegate: AuthUIDelegate?)
      -> Future<AuthCredential, Error> {
      Future<AuthCredential, Error> { promise in
        self.getCredentialWith(uiDelegate) { authCredential, error in
          if let error {
            promise(.failure(error))
          } else if let authCredential {
            promise(.success(authCredential))
          }
        }
      }
    }
  }

#endif // os(iOS) || targetEnvironment(macCatalyst)
