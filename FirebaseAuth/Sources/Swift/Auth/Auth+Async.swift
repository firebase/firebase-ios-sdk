// Copyright 2025 Google LLC
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

public extension Auth {
  /// An asynchronous sequence of authentication state changes.
  ///
  /// This sequence provides a modern, `async/await`-compatible way to monitor the authentication
  /// state of the current user. It emits a new `User?` value whenever the user signs in or
  /// out.
  ///
  /// The sequence's underlying listener is automatically managed. It is added to the `Auth`
  /// instance when you begin iterating over the sequence and is removed when the iteration
  /// is cancelled or terminates.
  ///
  /// - Important: The first value emitted by this sequence is always the *current* authentication
  ///   state, which may be `nil` if no user is signed in.
  ///
  /// ### Example Usage
  ///
  /// You can use a `for await` loop to handle authentication changes:
  ///
  /// ```swift
  /// func monitorAuthState() async {
  ///   for await user in Auth.auth().authStateChanges {
  ///     if let user = user {
  ///       print("User signed in: \(user.uid)")
  ///       // Update UI or perform actions for a signed-in user.
  ///     } else {
  ///       print("User signed out.")
  ///       // Update UI or perform actions for a signed-out state.
  ///     }
  ///   }
  /// }
  /// ```
  @available(iOS 18.0, *)
  var authStateChanges: some AsyncSequence<User?, Never> {
    AsyncStream { continuation in
      let listenerHandle = addStateDidChangeListener { _, user in
        continuation.yield(user)
      }

      continuation.onTermination = { @Sendable _ in
        self.removeStateDidChangeListener(listenerHandle)
      }
    }
  }

  /// An asynchronous sequence of ID token changes.
  ///
  /// This sequence provides a modern, `async/await`-compatible way to monitor changes to the
  /// current user's ID token. It emits a new `User?` value whenever the ID token changes.
  ///
  /// The sequence's underlying listener is automatically managed. It is added to the `Auth`
  /// instance when you begin iterating over the sequence and is removed when the iteration
  /// is cancelled or terminates.
  ///
  /// - Important: The first value emitted by this sequence is always the *current* authentication
  ///   state, which may be `nil` if no user is signed in.
  ///
  /// ### Example Usage
  ///
  /// You can use a `for await` loop to handle ID token changes:
  ///
  /// ```swift
  /// func monitorIDTokenChanges() async {
  ///   for await user in Auth.auth().idTokenChanges {
  ///     if let user = user {
  ///       print("ID token changed for user: \(user.uid)")
  ///       // Update UI or perform actions for a signed-in user.
  ///     } else {
  ///       print("User signed out.")
  ///       // Update UI or perform actions for a signed-out state.
  ///     }
  ///   }
  /// }
  /// ```
  @available(iOS 18.0, *)
  var idTokenChanges: some AsyncSequence<User?, Never> {
    AsyncStream { continuation in
      let listenerHandle = addIDTokenDidChangeListener { _, user in
        continuation.yield(user)
      }

      continuation.onTermination = { @Sendable _ in
        self.removeIDTokenDidChangeListener(listenerHandle)
      }
    }
  }
}
