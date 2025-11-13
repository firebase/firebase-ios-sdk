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
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension Query {
  /// An asynchronous sequence of query snapshots.
  ///
  /// This stream emits a new `QuerySnapshot` every time the underlying data changes.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var snapshots: QuerySnapshotsSequence {
    return snapshots(includeMetadataChanges: false)
  }

  /// An asynchronous sequence of query snapshots.
  ///
  /// - Parameter includeMetadataChanges: Whether to receive events for metadata-only changes.
  /// - Returns: A `QuerySnapshotsSequence` of `QuerySnapshot` events.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func snapshots(includeMetadataChanges: Bool) -> QuerySnapshotsSequence {
    return QuerySnapshotsSequence(self, includeMetadataChanges: includeMetadataChanges)
  }

  /// An `AsyncSequence` that emits `QuerySnapshot` values whenever the query data changes.
  ///
  /// This struct is the concrete type returned by the `Query.snapshots` property.
  ///
  /// - Important: This type is marked `Sendable` because `Query` itself is `Sendable`.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @frozen
  struct QuerySnapshotsSequence: AsyncSequence, Sendable {
    public typealias Element = QuerySnapshot
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    @usableFromInline
    let query: Query
    @usableFromInline
    let includeMetadataChanges: Bool

    /// Creates a new sequence for monitoring query snapshots.
    /// - Parameters:
    ///   - query: The `Query` instance to monitor.
    ///   - includeMetadataChanges: Whether to receive events for metadata-only changes.
    @inlinable
    public init(_ query: Query, includeMetadataChanges: Bool) {
      self.query = query
      self.includeMetadataChanges = includeMetadataChanges
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `QuerySnapshotsSequence`.
    @inlinable
    public func makeAsyncIterator() -> Iterator {
      Iterator(query: query, includeMetadataChanges: includeMetadataChanges)
    }

    /// The asynchronous iterator for `QuerySnapshotsSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = QuerySnapshot
      @usableFromInline
      let stream: AsyncThrowingStream<QuerySnapshot, Error>
      @usableFromInline
      var streamIterator: AsyncThrowingStream<QuerySnapshot, Error>.Iterator

      /// Initializes the iterator with the provided `Query` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listener.
      /// - Parameters:
      ///   - query: The `Query` instance to monitor.
      ///   - includeMetadataChanges: Whether to receive events for metadata-only changes.
      @inlinable
      init(query: Query, includeMetadataChanges: Bool) {
        stream = AsyncThrowingStream { continuation in
          let listener = query
            .addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { snapshot, error in
              if let error = error {
                continuation.finish(throwing: error)
              } else if let snapshot = snapshot {
                continuation.yield(snapshot)
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
      /// Returns a `QuerySnapshot` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `QuerySnapshot` object.
      @inlinable
      public mutating func next() async throws -> Element? {
        try await streamIterator.next()
      }
    }
  }
}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension Query.QuerySnapshotsSequence.Iterator: Sendable {}
