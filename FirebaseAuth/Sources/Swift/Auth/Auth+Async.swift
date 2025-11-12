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
  ///     if let user {
  ///       print("User signed in: \(user.uid)")
  ///       // Update UI or perform actions for a signed-in user.
  ///     } else {
  ///       print("User signed out.")
  ///       // Update UI or perform actions for a signed-out state.
  ///     }
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var authStateChanges: AuthStateChangesSequence {
    AuthStateChangesSequence(self)
  }

  /// An `AsyncSequence` that emits `User?` values whenever the authentication state changes.
  ///
  /// This struct is the concrete type returned by the `Auth.authStateChanges` property.
  ///
  /// - Important: This type is marked `@unchecked Sendable` because the underlying `Auth` object
  ///   is not explicitly marked `Sendable` by the framework. However, the operations performed
  ///   (adding and removing listeners) are known to be thread-safe.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct AuthStateChangesSequence: AsyncSequence, @unchecked Sendable {
    public typealias Element = User?
    public typealias Failure = Never
    public typealias AsyncIterator = Iterator

    private let auth: Auth

    /// Creates a new sequence for monitoring authentication state changes.
    /// - Parameter auth: The `Auth` instance to monitor.
    public init(_ auth: Auth) {
      self.auth = auth
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `AuthStateChangesSequence`.
    public func makeAsyncIterator() -> Iterator {
      Iterator(auth: auth)
    }

    /// The asynchronous iterator for `AuthStateChangesSequence`.
    ///
    /// - Important: This type is marked `@unchecked Sendable` for the same reasons as its parent
    ///   `AuthStateChangesSequence`.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
      private let stream: AsyncStream<User?>
      private var streamIterator: AsyncStream<User?>.Iterator

      /// Initializes the iterator with the provided `Auth` instance.
      /// This sets up the `AsyncStream` and registers the necessary listener.
      /// - Parameter auth: The `Auth` instance to monitor.
      init(auth: Auth) {
        stream = AsyncStream<User?> { continuation in
          let handle = auth.addStateDidChangeListener { _, user in
            continuation.yield(user)
          }

          continuation.onTermination = { @Sendable _ in
            auth.removeStateDidChangeListener(handle)
          }
        }

        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `User?` value (where `nil` indicates no signed-in user) or `nil` if the
      /// sequence has terminated.
      /// - Returns: An optional `User?` object, wrapped in another optional to indicate the end of
      /// the sequence.
      public mutating func next() async -> User?? {
        await streamIterator.next()
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
  ///     if let user {
  ///       print("ID token changed for user: \(user.uid)")
  ///       // Update UI or perform actions for a signed-in user.
  ///     } else {
  ///       print("User signed out.")
  ///       // Update UI or perform actions for a signed-out state.
  ///     }
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var idTokenChanges: IDTokenChangesSequence {
    IDTokenChangesSequence(self)
  }

  /// An `AsyncSequence` that emits `User?` values whenever the ID token changes.
  ///
  /// This struct is the concrete type returned by the `Auth.idTokenChanges` property.
  ///
  /// - Important: This type is marked `@unchecked Sendable` because the underlying `Auth` object
  ///   is not explicitly marked `Sendable` by the framework. However, the operations performed
  ///   (adding and removing listeners) are known to be thread-safe.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct IDTokenChangesSequence: AsyncSequence, @unchecked Sendable {
    public typealias Element = User?
    public typealias Failure = Never
    public typealias AsyncIterator = Iterator

    private let auth: Auth

    /// Creates a new sequence for monitoring ID token changes.
    /// - Parameter auth: The `Auth` instance to monitor.
    public init(_ auth: Auth) {
      self.auth = auth
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `IDTokenChangesSequence`.
    public func makeAsyncIterator() -> Iterator {
      Iterator(auth: auth)
    }

    /// The asynchronous iterator for `IDTokenChangesSequence`.
    ///
    /// - Important: This type is marked `@unchecked Sendable` for the same reasons as its parent
    ///   `IDTokenChangesSequence`.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
      private let stream: AsyncStream<User?>
      private var streamIterator: AsyncStream<User?>.Iterator

      /// Initializes the iterator with the provided `Auth` instance.
      /// This sets up the `AsyncStream` and registers the necessary listener.
      /// - Parameter auth: The `Auth` instance to monitor.
      init(auth: Auth) {
        stream = AsyncStream<User?> { continuation in
          let handle = auth.addIDTokenDidChangeListener { _, user in
            continuation.yield(user)
          }

          continuation.onTermination = { @Sendable _ in
            auth.removeIDTokenDidChangeListener(handle)
          }
        }

        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `User?` value (where `nil` indicates no signed-in user) or `nil` if the
      /// sequence has terminated.
      /// - Returns: An optional `User?` object, wrapped in another optional to indicate the end of
      /// the sequence.
      public mutating func next() async -> User?? {
        await streamIterator.next()
      }
    }
  }
}
