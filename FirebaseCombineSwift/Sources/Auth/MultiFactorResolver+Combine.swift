// Copyright 2020 Google LLC
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
  public extension MultiFactorResolver {
    /// A helper function that helps users sign in with a second factor using a
    /// `MultiFactorAssertion`.
    /// This assertion confirms that the user has successfully completed the second factor.
    ///
    /// - Parameter assertion: The base class for asserting ownership of a second factor.
    /// - Returns: A publisher that emits an `AuthDataResult` when the sign-in flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    func resolveSignIn(with assertion: MultiFactorAssertion)
      -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.resolveSignIn(with: assertion) { authDataResult, error in
          if let error {
            promise(.failure(error))
          } else if let authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }
  }

#endif // os(iOS) || targetEnvironment(macCatalyst)
