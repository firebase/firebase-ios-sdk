// Copyright 2024 Google LLC
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

#if swift(>=5.5.2)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *)
  public extension Auth {
    /// An asynchronous stream of authentication state changes.
    ///
    /// This stream provides a modern, `async/await`-compatible way to monitor the authentication
    /// state of the current user. It emits a new `User?` value whenever the user signs in or
    /// out.
    ///
    /// The stream's underlying listener is automatically managed. It is added to the `Auth`
    /// instance when you begin iterating over the stream and is removed when the iteration
    /// is cancelled or terminates.
    ///
    /// - Important: The first value emitted by this stream is always the *current* authentication
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
    var authStateChanges: AsyncStream<User?> {
      return AsyncStream { continuation in
        let listenerHandle = addStateDidChangeListener { _, user in
          continuation.yield(user)
        }

        continuation.onTermination = { @Sendable _ in
          self.removeStateDidChangeListener(listenerHandle)
        }
      }
    }
  }
#endif // swift(>=5.5.2)
