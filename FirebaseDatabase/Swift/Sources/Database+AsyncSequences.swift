/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if SWIFT_PACKAGE
  @_exported import FirebaseDatabaseInternal
#endif // SWIFT_PACKAGE
import Foundation

// MARK: - ChildEvent

/// An enumeration of granular child-level events emitted by `DatabaseQuery.childEvents`.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public enum ChildEvent: Sendable {
  /// Emitted when a new child node is added to the location, or initially for each existing child
  /// when iteration begins.
  case added(DataSnapshot, previousSiblingKey: String?)

  /// Emitted when the data at a child node (or any of its descendants) is modified.
  case changed(DataSnapshot, previousSiblingKey: String?)

  /// Emitted when an immediate child node is removed from the location.
  case removed(DataSnapshot)

  /// Emitted when a child node's relative order changes with respect to its siblings.
  case moved(DataSnapshot, previousSiblingKey: String?)
}

// MARK: - DatabaseQuery + AsyncSequence

public extension DatabaseQuery {
  /// An asynchronous sequence of the entire contents at a location.
  ///
  /// This sequence emits a new `DataSnapshot` for the initial data at the location and again
  /// every time the underlying data changes.
  ///
  /// The underlying observer is automatically registered when you begin iterating over the
  /// sequence and is removed when the iteration is cancelled or terminates.
  ///
  /// - Throws: An `Error` if the observer is cancelled (for example, due to a permission change),
  ///   causing the sequence to terminate.
  ///
  /// ### Example Usage
  ///
  /// ```swift
  /// func observeScore() async throws {
  ///   let scoreRef = Database.database().reference(withPath: "game/score")
  ///   for try await snapshot in scoreRef.snapshots {
  ///     print("Current score: \(snapshot.value ?? 0)")
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var snapshots: DatabaseQuerySnapshotsSequence {
    DatabaseQuerySnapshotsSequence(self)
  }

  /// An asynchronous sequence of child-level events at a location.
  ///
  /// This sequence emits `ChildEvent` values (`.added`, `.changed`, `.removed`, and `.moved`)
  /// whenever child nodes at the location change.
  ///
  /// The underlying observers are automatically registered when you begin iterating over the
  /// sequence and are removed when the iteration is cancelled or terminates.
  ///
  /// - Important: Just like `observe(.childAdded, with:)`, `.added` is emitted once for **every
  ///   existing child** at the location when iteration begins, and again each time a new child is
  ///   added thereafter.
  ///
  /// - Throws: An `Error` if an observer is cancelled (for example, due to a permission change),
  ///   causing the sequence to terminate.
  ///
  /// ### Example Usage
  ///
  /// ```swift
  /// func observeMessages() async throws {
  ///   let messagesRef = Database.database().reference(withPath: "chats/123/messages")
  ///   for try await event in messagesRef.childEvents {
  ///     switch event {
  ///     case let .added(snapshot, previousSiblingKey):
  ///       print("Added \(snapshot.key) after \(previousSiblingKey ?? "start")")
  ///     case let .changed(snapshot, _):
  ///       print("Updated \(snapshot.key)")
  ///     case let .removed(snapshot):
  ///       print("Removed \(snapshot.key)")
  ///     case let .moved(snapshot, previousSiblingKey):
  ///       print("Moved \(snapshot.key) after \(previousSiblingKey ?? "start")")
  ///     }
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var childEvents: ChildEventsSequence {
    ChildEventsSequence(self)
  }

  /// An `AsyncSequence` that emits `DataSnapshot` values whenever the query data changes.
  ///
  /// This struct is the concrete type returned by the `DatabaseQuery.snapshots` property.
  ///
  /// - Important: This type is marked `@unchecked Sendable` because the underlying
  ///   `DatabaseQuery` object is not annotated `Sendable` in Objective-C. However, the operations
  ///   performed (adding and removing observers) dispatch onto Realtime Database's internal serial
  ///   work queue and are thread-safe.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct DatabaseQuerySnapshotsSequence: AsyncSequence, @unchecked Sendable {
    public typealias Element = DataSnapshot
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    private let query: DatabaseQuery

    /// Creates a new sequence for monitoring query snapshots.
    /// - Parameter query: The `DatabaseQuery` instance to monitor.
    public init(_ query: DatabaseQuery) {
      self.query = query
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `DatabaseQuerySnapshotsSequence`.
    public func makeAsyncIterator() -> Iterator {
      Iterator(query: query)
    }

    /// The asynchronous iterator for `DatabaseQuerySnapshotsSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = DataSnapshot

      private let stream: AsyncThrowingStream<DataSnapshot, Error>
      private var streamIterator: AsyncThrowingStream<DataSnapshot, Error>.Iterator

      /// Initializes the iterator with the provided `DatabaseQuery` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listener.
      /// - Parameter query: The `DatabaseQuery` instance to monitor.
      init(query: DatabaseQuery) {
        nonisolated(unsafe) let query = query
        stream = AsyncThrowingStream { continuation in
          let handle = query.observe(.value) { snapshot in
            continuation.yield(snapshot)
          } withCancel: { error in
            continuation.finish(throwing: error)
          }

          continuation.onTermination = { @Sendable _ in
            query.removeObserver(withHandle: handle)
          }
        }
        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `DataSnapshot` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `DataSnapshot` object.
      public mutating func next() async throws -> Element? {
        try await streamIterator.next()
      }
    }
  }

  /// An `AsyncSequence` that emits `ChildEvent` values whenever the query's child data
  /// changes.
  ///
  /// This struct is the concrete type returned by the `DatabaseQuery.childEvents` property.
  ///
  /// - Important: This type is marked `@unchecked Sendable` because the underlying
  ///   `DatabaseQuery` object is not annotated `Sendable` in Objective-C. However, the operations
  ///   performed (adding and removing observers) dispatch onto Realtime Database's internal serial
  ///   work queue and are thread-safe.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct ChildEventsSequence: AsyncSequence, @unchecked Sendable {
    public typealias Element = ChildEvent
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    private let query: DatabaseQuery

    /// Creates a new sequence for monitoring child events.
    /// - Parameter query: The `DatabaseQuery` instance to monitor.
    public init(_ query: DatabaseQuery) {
      self.query = query
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `ChildEventsSequence`.
    public func makeAsyncIterator() -> Iterator {
      Iterator(query: query)
    }

    /// The asynchronous iterator for `ChildEventsSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = ChildEvent

      private let stream: AsyncThrowingStream<ChildEvent, Error>
      private var streamIterator: AsyncThrowingStream<ChildEvent, Error>.Iterator

      /// Initializes the iterator with the provided `DatabaseQuery` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listeners.
      /// - Parameter query: The `DatabaseQuery` instance to monitor.
      init(query: DatabaseQuery) {
        nonisolated(unsafe) let query = query
        stream = AsyncThrowingStream { continuation in
          let handles = [
            // Child Added
            query.observe(
              .childAdded,
              andPreviousSiblingKeyWith: { snapshot, previousKey in
                continuation.yield(.added(snapshot, previousSiblingKey: previousKey))
              },
              withCancel: { error in
                continuation.finish(throwing: error)
              }
            ),
            // Child Changed
            query.observe(
              .childChanged,
              andPreviousSiblingKeyWith: { snapshot, previousKey in
                continuation.yield(.changed(snapshot, previousSiblingKey: previousKey))
              },
              withCancel: { error in
                continuation.finish(throwing: error)
              }
            ),
            // Child Removed
            query.observe(
              .childRemoved,
              with: { snapshot in
                continuation.yield(.removed(snapshot))
              },
              withCancel: { error in
                continuation.finish(throwing: error)
              }
            ),
            // Child Moved
            query.observe(
              .childMoved,
              andPreviousSiblingKeyWith: { snapshot, previousKey in
                continuation.yield(.moved(snapshot, previousSiblingKey: previousKey))
              },
              withCancel: { error in
                continuation.finish(throwing: error)
              }
            ),
          ]

          continuation.onTermination = { @Sendable _ in
            for handle in handles {
              query.removeObserver(withHandle: handle)
            }
          }
        }
        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `ChildEvent` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `ChildEvent` object.
      public mutating func next() async throws -> Element? {
        try await streamIterator.next()
      }
    }
  }
}

// MARK: - Sendable Conformance

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension DatabaseQuery.DatabaseQuerySnapshotsSequence.Iterator: Sendable {}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension DatabaseQuery.ChildEventsSequence.Iterator: Sendable {}
