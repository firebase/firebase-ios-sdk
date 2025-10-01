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
  /// Returns an `AsyncThrowingStream` that provides real-time updates to the configuration.
  ///
  /// You can listen for updates by iterating over the stream using a `for try await` loop.
  /// The stream will yield a `RemoteConfigUpdate` whenever a change is pushed from the
  /// Remote Config backend. After receiving an update, you must call `activate()` to make the
  /// new configuration available to your app.
  ///
  /// The underlying listener is automatically added when you begin iterating and is removed when
  /// the iteration is cancelled or finishes.
  ///
  /// - Throws: `RemoteConfigUpdateError` if the listener encounters a server-side error or another
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
  @available(iOS 18.0, *)
  var configUpdates: some AsyncSequence<RemoteConfigUpdate, Error> {
    AsyncThrowingStream { continuation in
      let listener = addOnConfigUpdateListener { update, error in
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
  }
}
