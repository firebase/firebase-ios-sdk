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

@available(iOS 13.0.0, macOS 10.15.0, macCatalyst 13.0.0, tvOS 13.0.0, watchOS 7.0.0, *)
public extension RemoteConfig {
  /// Returns an `AsyncSequence` that provides real-time updates to the configuration.
  ///
  /// You can listen for updates by iterating over the stream using a `for try await` loop.
  /// The stream will yield a `RemoteConfigUpdate` whenever a change is pushed from the
  /// Remote Config backend. After receiving an update, you must call `activate()` to make the
  /// new configuration available to your app.
  ///
  /// The underlying listener is automatically added when you begin iterating and is removed when
  /// the iteration is cancelled or finishes.
  ///
  /// - Throws: An `Error` if the listener encounters a server-side error or another
  ///           issue, causing the stream to terminate.
  ///
  /// ### Example Usage
  ///
  /// ```swift
  /// func listenForRealtimeUpdates() {
  ///   Task {
  ///     do {
  ///       for try await configUpdate in remoteConfig.configUpdates {
  ///         print("Updated keys: \(configUpdate.updatedKeys)")
  ///         // Activate the new config to make it available
  ///         let status = try await remoteConfig.activate()
  ///         print("Config activated with status: \(status)")
  ///       }
  ///     } catch {
  ///       print("Error listening for remote config updates: \(error)")
  ///     }
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var configUpdates: RemoteConfigUpdateSequence {
    RemoteConfigUpdateSequence(self)
  }

  /// An `AsyncSequence` that emits `RemoteConfigUpdate` values whenever the config is updated.
  ///
  /// This struct is the concrete type returned by the `RemoteConfig.configUpdates` property.
  ///
  /// - Important: This type is marked `Sendable` because `RemoteConfig` is assumed to be
  /// `Sendable`.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @frozen
  struct RemoteConfigUpdateSequence: AsyncSequence, Sendable {
    public typealias Element = RemoteConfigUpdate
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    @usableFromInline
    let remoteConfig: RemoteConfig

    /// Creates a new sequence for monitoring real-time config updates.
    /// - Parameter remoteConfig: The `RemoteConfig` instance to monitor.
    @inlinable
    public init(_ remoteConfig: RemoteConfig) {
      self.remoteConfig = remoteConfig
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `RemoteConfigUpdateSequence`.
    @inlinable
    public func makeAsyncIterator() -> Iterator {
      Iterator(remoteConfig: remoteConfig)
    }

    /// The asynchronous iterator for `RemoteConfigUpdateSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = RemoteConfigUpdate

      @usableFromInline
      let stream: AsyncThrowingStream<RemoteConfigUpdate, Error>
      @usableFromInline
      var streamIterator: AsyncThrowingStream<RemoteConfigUpdate, Error>.Iterator

      /// Initializes the iterator with the provided `RemoteConfig` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listener.
      /// - Parameter remoteConfig: The `RemoteConfig` instance to monitor.
      @inlinable
      init(remoteConfig: RemoteConfig) {
        stream = AsyncThrowingStream { continuation in
          let listener = remoteConfig.addOnConfigUpdateListener { update, error in
            switch (update, error) {
            case let (update?, _):
              // If there's an update, yield it. We prioritize the update over a potential error.
              continuation.yield(update)
            case let (_, error?):
              // If there's no update but there is an error, terminate the stream with the error.
              continuation.finish(throwing: error)
            case (nil, nil):
              // If both are nil (the "should not happen" case), gracefully finish the stream.
              continuation.finish()
            }
          }

          continuation.onTermination = { @Sendable _ in
            listener.remove()
          }
        }
        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `RemoteConfigUpdate` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `RemoteConfigUpdate` object.
      @inlinable
      public mutating func next() async throws -> Element? {
        try await streamIterator.next()
      }
    }
  }
}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension RemoteConfig.RemoteConfigUpdateSequence.Iterator: Sendable {}

// Since RemoteConfig is a thread-safe Objective-C class (it uses a serial queue for its
// operations), we can safely declare its conformance to Sendable.
extension RemoteConfig: @unchecked Sendable {}
