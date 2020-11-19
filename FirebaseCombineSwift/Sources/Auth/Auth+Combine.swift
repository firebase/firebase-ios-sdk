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
  }

#endif
