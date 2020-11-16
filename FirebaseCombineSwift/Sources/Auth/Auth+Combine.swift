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
  extension Auth {
    /// Registers an authentication state listener and publishes any
    /// updates to subscribers.
    ///
    /// - Returns: A publisher emitting `User` instances
    public func authStateDidChangePublisher() -> AnyPublisher<User?, Never> {
      let subject = PassthroughSubject<User?, Never>()
      let handle = addStateDidChangeListener { auth, user in
        subject.send(user)
      }
      return subject
        .handleEvents(receiveCancel: { self.removeStateDidChangeListener(handle) })
        .eraseToAnyPublisher()
    }
  }

#endif
