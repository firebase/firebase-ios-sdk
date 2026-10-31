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

import FirebaseCore
#if SWIFT_PACKAGE
  @_exported import FirebaseDatabaseInternal
#endif // SWIFT_PACKAGE
import Foundation

// MARK: - DatabaseEvent

/// An enumeration of granular child-level events.
public enum DatabaseEvent: Sendable {
  case childAdded(DataSnapshot, previousSiblingKey: String?)
  case childChanged(DataSnapshot, previousSiblingKey: String?)
  case childRemoved(DataSnapshot)
  case childMoved(DataSnapshot, previousSiblingKey: String?)
}

// MARK: - DatabaseQuery + AsyncSequence

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
  /// This sequence emits `DatabaseEvent` values (`.childAdded`, `.childChanged`,
  /// `.childRemoved`, and `.childMoved`) whenever child nodes at the location change.
  ///
  /// The underlying observers are automatically registered when you begin iterating over the
  /// sequence and are removed when the iteration is cancelled or terminates.
  ///
  /// - Returns: A `DatabaseChildEventsSequence` of `DatabaseEvent` events.
  /// - Throws: An `Error` if an observer is cancelled (for example, due to a permission change),
  ///   causing the sequence to terminate.
  ///
  /// ### Example Usage
  ///
  /// ```swift
  /// func observeMessages() async throws {
  ///   let messagesRef = Database.database().reference(withPath: "chats/123/messages")
  ///   for try await event in messagesRef.childEvents() {
  ///     switch event {
  ///     case let .childAdded(snapshot, previousSiblingKey):
  ///       print("Added \(snapshot.key) after \(previousSiblingKey ?? "start")")
  ///     case let .childChanged(snapshot, _):
  ///       print("Updated \(snapshot.key)")
  ///     case let .childRemoved(snapshot):
  ///       print("Removed \(snapshot.key)")
  ///     case let .childMoved(snapshot, previousSiblingKey):
  ///       print("Moved \(snapshot.key) after \(previousSiblingKey ?? "start")")
  ///     }
  ///   }
  /// }
  /// ```
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func childEvents() -> DatabaseChildEventsSequence {
    DatabaseChildEventsSequence(self)
  }

  /// An `AsyncSequence` that emits `DataSnapshot` values whenever the query data changes.
  ///
  /// This struct is the concrete type returned by the `DatabaseQuery.snapshots` property.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct DatabaseQuerySnapshotsSequence: AsyncSequence {
    public typealias Element = DataSnapshot
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    let query: DatabaseQuery

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

      let stream: AsyncThrowingStream<DataSnapshot, Error>
      var streamIterator: AsyncThrowingStream<DataSnapshot, Error>.Iterator

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

  /// An `AsyncSequence` that emits `DatabaseEvent` values whenever the query's child data
  /// changes.
  ///
  /// This struct is the concrete type returned by the `DatabaseQuery.childEvents()` method.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  struct DatabaseChildEventsSequence: AsyncSequence {
    public typealias Element = DatabaseEvent
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    let query: DatabaseQuery

    /// Creates a new sequence for monitoring child events.
    /// - Parameter query: The `DatabaseQuery` instance to monitor.
    public init(_ query: DatabaseQuery) {
      self.query = query
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `DatabaseChildEventsSequence`.
    public func makeAsyncIterator() -> Iterator {
      Iterator(query: query)
    }

    /// The asynchronous iterator for `DatabaseChildEventsSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = DatabaseEvent

      let stream: AsyncThrowingStream<DatabaseEvent, Error>
      var streamIterator: AsyncThrowingStream<DatabaseEvent, Error>.Iterator

      /// Initializes the iterator with the provided `DatabaseQuery` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listeners.
      /// - Parameter query: The `DatabaseQuery` instance to monitor.
      init(query: DatabaseQuery) {
        nonisolated(unsafe) let query = query
        stream = AsyncThrowingStream { continuation in
          var handles = [DatabaseHandle]()

          // Child Added
          let childAddedHandle = query.observe(
            .childAdded,
            andPreviousSiblingKeyWith: { snapshot, previousKey in
              continuation.yield(.childAdded(snapshot, previousSiblingKey: previousKey))
            },
            withCancel: { error in
              continuation.finish(throwing: error)
            }
          )
          handles.append(childAddedHandle)

          // Child Changed
          let childChangedHandle = query.observe(
            .childChanged,
            andPreviousSiblingKeyWith: { snapshot, previousKey in
              continuation.yield(.childChanged(snapshot, previousSiblingKey: previousKey))
            },
            withCancel: { error in
              continuation.finish(throwing: error)
            }
          )
          handles.append(childChangedHandle)

          // Child Removed
          let childRemovedHandle = query.observe(.childRemoved, with: { snapshot in
            continuation.yield(.childRemoved(snapshot))
          }, withCancel: { error in
            continuation.finish(throwing: error)
          })
          handles.append(childRemovedHandle)

          // Child Moved
          let childMovedHandle = query.observe(
            .childMoved,
            andPreviousSiblingKeyWith: { snapshot, previousKey in
              continuation.yield(.childMoved(snapshot, previousSiblingKey: previousKey))
            },
            withCancel: { error in
              continuation.finish(throwing: error)
            }
          )
          handles.append(childMovedHandle)

          // Capture `handles` by value so the closure uses an immutable copy of the array.
          continuation.onTermination = { @Sendable [handles] _ in
            for handle in handles {
              query.removeObserver(withHandle: handle)
            }
          }
        }
        streamIterator = stream.makeAsyncIterator()
      }

      /// Produces the next element in the asynchronous sequence.
      ///
      /// Returns a `DatabaseEvent` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `DatabaseEvent` object.
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
extension DatabaseQuery.DatabaseChildEventsSequence.Iterator: Sendable {}
