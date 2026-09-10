import FirebaseCore
import Foundation

// MARK: - DatabaseEvent

/// An enumeration of granular child-level events.
public enum DatabaseEvent {
  case childAdded(DataSnapshot, previousSiblingKey: String?)
  case childChanged(DataSnapshot, previousSiblingKey: String?)
  case childRemoved(DataSnapshot)
  case childMoved(DataSnapshot, previousSiblingKey: String?)
}

// MARK: - DatabaseQuery + AsyncSequence

public extension DatabaseQuery {
  /// An asynchronous stream of the entire contents at a location.
  /// This stream emits a new `DataSnapshot` every time the data changes.
  var snapshots: DatabaseQuerySnapshotsSequence {
    DatabaseQuerySnapshotsSequence(self)
  }

  /// An asynchronous stream of child-level events at a location.
  func childEvents() -> DatabaseChildEventsSequence {
    DatabaseChildEventsSequence(self)
  }
}

// MARK: - DatabaseQuerySnapshotsSequence

/// An asynchronous sequence that emits `DataSnapshot` values whenever the query data changes.
///
/// This struct is the concrete type returned by the `DatabaseQuery.snapshots` property.
///
/// - Important: This type is marked `Sendable` because `DatabaseQuery` itself is `Sendable`.
public struct DatabaseQuerySnapshotsSequence: AsyncSequence, Sendable {
  public typealias Element = DataSnapshot
  public typealias Failure = Error
  public typealias AsyncIterator = Iterator

  @usableFromInline
  let query: DatabaseQuery

  /// Creates a new sequence for monitoring query snapshots.
  /// - Parameter query: The `DatabaseQuery` instance to monitor.
  @inlinable
  public init(_ query: DatabaseQuery) {
    self.query = query
  }

  /// Creates and returns an iterator for this asynchronous sequence.
  /// - Returns: An `Iterator` for `DatabaseQuerySnapshotsSequence`.
  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(query: query)
  }

  /// The asynchronous iterator for `DatabaseQuerySnapshotsSequence`.
  public struct Iterator: AsyncIteratorProtocol {
    public typealias Element = DataSnapshot

    @usableFromInline
    let stream: AsyncThrowingStream<DataSnapshot, Error>
    @usableFromInline
    var streamIterator: AsyncThrowingStream<DataSnapshot, Error>.Iterator

    /// Initializes the iterator with the provided `DatabaseQuery` instance.
    /// This sets up the `AsyncThrowingStream` and registers the necessary listener.
    /// - Parameter query: The `DatabaseQuery` instance to monitor.
    @inlinable
    init(query: DatabaseQuery) {
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
    @inlinable
    public mutating func next() async throws -> Element? {
      try await streamIterator.next()
    }
  }
}

// MARK: - DatabaseChildEventsSequence

/// An asynchronous sequence that emits `DatabaseEvent` values whenever the query's child data
/// changes.
///
/// This struct is the concrete type returned by the `DatabaseQuery.childEvents()` method.
///
/// - Important: This type is marked `Sendable` because `DatabaseQuery` itself is `Sendable`.
public struct DatabaseChildEventsSequence: AsyncSequence, Sendable {
  public typealias Element = DatabaseEvent
  public typealias Failure = Error
  public typealias AsyncIterator = Iterator

  @usableFromInline
  let query: DatabaseQuery

  /// Creates a new sequence for monitoring child events.
  /// - Parameter query: The `DatabaseQuery` instance to monitor.
  @inlinable
  public init(_ query: DatabaseQuery) {
    self.query = query
  }

  /// Creates and returns an iterator for this asynchronous sequence.
  /// - Returns: An `Iterator` for `DatabaseChildEventsSequence`.
  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(query: query)
  }

  /// The asynchronous iterator for `DatabaseChildEventsSequence`.
  public struct Iterator: AsyncIteratorProtocol {
    public typealias Element = DatabaseEvent

    @usableFromInline
    let stream: AsyncThrowingStream<DatabaseEvent, Error>
    @usableFromInline
    var streamIterator: AsyncThrowingStream<DatabaseEvent, Error>.Iterator

    /// Initializes the iterator with the provided `DatabaseQuery` instance.
    /// This sets up the `AsyncThrowingStream` and registers the necessary listeners.
    /// - Parameter query: The `DatabaseQuery` instance to monitor.
    @inlinable
    init(query: DatabaseQuery) {
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

        // We capture `handles` (the array of handles we just populated)
        // by value in the capture list `[handles]`.

        // This ensures the closure uses an immutable copy of the array, preventing data races.
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
    @inlinable
    public mutating func next() async throws -> Element? {
      try await streamIterator.next()
    }
  }
}

// MARK: - Sendable Conformance

// `DatabaseQuery` is thread-safe, so we can mark it as `@unchecked Sendable`.
// We use `@retroactive` to silence Swift 6 warnings about conforming a type from another module.
extension DatabaseQuery: @retroactive @unchecked Sendable {}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension DatabaseQuerySnapshotsSequence.Iterator: Sendable {}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension DatabaseChildEventsSequence.Iterator: Sendable {}
