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

#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseAuth)

  import Combine
  import FirebaseAuth

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  public typealias AuthStateDidChangePublisher = AnyPublisher<(Auth, User?), Never>

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  extension Auth {
    // MARK: - Authentication State Management

    /// Registers a publisher that publishes authentication state changes.
    ///
    /// The publisher emits values when:
    ///
    /// - It is registered,
    /// - A user with a different UID from the current user has signed in, or
    /// - The current user has signed out.
    ///
    /// - Returns: A publisher emitting (`Auth`, User`) tuples.
    public func authStateDidChangePublisher() -> AuthStateDidChangePublisher {
      let subject = PassthroughSubject<(Auth, User?), Never>()
      let handle = addStateDidChangeListener { auth, user in
        subject.send((auth, user))
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeStateDidChangeListener(handle)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - Anonymous Authentication

    /// Asynchronously creates and becomes an anonymous user.
    /// - Returns: A publisher that emits the result of the sign in flow.
    /// - Remark: If there is already an anonymous user signed in, that user will be returned instead.
    ///   If there is any other existing user signed in, that user will be signed out.
    /// - Remark: Possible error codes:
    /// - `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
    ///   not enabled. Enable them in the Auth section of the Firebase console.
    /// - Remark: See `AuthErrors` for a list of error codes that are common to all API methods
    public func signInAnonymously() -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signInAnonymously { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    // MARK: - Email/Password Authentication

    /// Creates and, on success, signs in a user with the given email address and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's desired password.
    /// - Returns: A publisher that emits the result of the sign in flow.
    /// - Remark: Possible error codes:
    /// - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    /// - `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
    ///   already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
    ///   used, and prompt the user to sign in with one of those.
    /// - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
    ///   are not enabled. Enable them in the Auth section of the Firebase console.
    /// - `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
    ///   considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
    ///   dictionary object will contain more detailed explanation that can be shown to the user.
    /// - Remark: See `AuthErrors` for a list of error codes that are common to all API methods
    public func createUser(withEmail email: String,
                           password: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { [weak self] promise in
        self?.createUser(withEmail: email, password: password) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Signs in using an email address and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's desired password.
    /// - Returns: A publisher that emits the result of the sign in flow.
    /// - Remark: Possible error codes:
    /// - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
    ///   accounts are not enabled. Enable them in the Auth section of the
    ///   Firebase console.
    /// - `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    /// - `AuthErrorCodeWrongPassword` - Indicates the user attempted
    ///   sign in with an incorrect password.
    /// - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    /// - Remark: See `AuthErrors` for a list of error codes that are common to all API methods
    public func signIn(withEmail email: String,
                       password: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { [weak self] promise in
        self?.signIn(withEmail: email, password: password) { authDataResult, error in
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
