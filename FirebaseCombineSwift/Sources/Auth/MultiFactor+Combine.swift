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
  public extension MultiFactor {
    /// Get a session for a second factor enrollment operation.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher that emits a `MultiFactorSession` for a second factor
    ///   enrollment operation. This is used to identify the current user trying to enroll a
    /// second factor. The publisher will emit on
    ///   the *main* thread.
    @discardableResult
    func getSession() -> Future<MultiFactorSession, Error> {
      Future<MultiFactorSession, Error> { promise in
        self.getSessionWithCompletion { session, error in
          if let session {
            promise(.success(session))
          } else if let error {
            promise(.failure(error))
          }
        }
      }
    }

    /// Enrolls a second factor as identified by the `MultiFactorAssertion` parameter for the
    /// current user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///     - assertion: The base class for asserting ownership of a second factor.
    ///     - displayName: An optional display name associated with the multi factor to enroll.
    ///
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher
    /// will emit on the *main* thread.
    @discardableResult
    func enroll(with assertion: MultiFactorAssertion,
                displayName: String?) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.enroll(with: assertion, displayName: displayName) { error in
          if let error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Unenroll the given multi factor.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter factorInfo: The structure used to represent a second factor entity from a
    /// client perspective.
    /// - Returns: A publisher that emits when the request to send the unenrollment verification
    /// email is complete. The publisher
    /// will emit on the *main* thread.
    @discardableResult
    func unenroll(with factorInfo: MultiFactorInfo) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.unenroll(with: factorInfo) { error in
          if let error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Unenroll the given multi factor.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher that emits when the request to send the unenrollment verification
    /// email is complete.
    /// The publisher will emit on the *main* thread.
    @discardableResult
    func unenroll(withFactorUID factorUID: String) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.unenroll(withFactorUID: factorUID) { error in
          if let error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }
  }

#endif // os(iOS) || targetEnvironment(macCatalyst)
