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
public extension DocumentReference {
  /// An asynchronous sequence of document snapshots.
  ///
  /// This stream emits a new `DocumentSnapshot` every time the underlying data changes.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  var snapshots: DocumentSnapshotsSequence {
    return snapshots(includeMetadataChanges: false)
  }

  /// An asynchronous sequence of document snapshots.
  ///
  /// - Parameter includeMetadataChanges: Whether to receive events for metadata-only changes.
  /// - Returns: A `DocumentSnapshotsSequence` of `DocumentSnapshot` events.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func snapshots(includeMetadataChanges: Bool) -> DocumentSnapshotsSequence {
    return DocumentSnapshotsSequence(self, includeMetadataChanges: includeMetadataChanges)
  }

  /// An `AsyncSequence` that emits `DocumentSnapshot` values whenever the document data changes.
  ///
  /// This struct is the concrete type returned by the `DocumentReference.snapshots` property.
  @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  @frozen
  struct DocumentSnapshotsSequence: AsyncSequence, Sendable {
    public typealias Element = DocumentSnapshot
    public typealias Failure = Error
    public typealias AsyncIterator = Iterator

    @usableFromInline
    internal let documentReference: DocumentReference
    @usableFromInline
    internal let includeMetadataChanges: Bool

    /// Creates a new sequence for monitoring document snapshots.
    /// - Parameters:
    ///   - documentReference: The `DocumentReference` instance to monitor.
    ///   - includeMetadataChanges: Whether to receive events for metadata-only changes.
    @inlinable
    public init(_ documentReference: DocumentReference, includeMetadataChanges: Bool) {
      self.documentReference = documentReference
      self.includeMetadataChanges = includeMetadataChanges
    }

    /// Creates and returns an iterator for this asynchronous sequence.
    /// - Returns: An `Iterator` for `DocumentSnapshotsSequence`.
    @inlinable
    public func makeAsyncIterator() -> Iterator {
      Iterator(documentReference: documentReference, includeMetadataChanges: includeMetadataChanges)
    }

    /// The asynchronous iterator for `DocumentSnapshotsSequence`.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct Iterator: AsyncIteratorProtocol {
      public typealias Element = DocumentSnapshot
      @usableFromInline
      internal let stream: AsyncThrowingStream<DocumentSnapshot, Error>
      @usableFromInline
      internal var streamIterator: AsyncThrowingStream<DocumentSnapshot, Error>.Iterator

      /// Initializes the iterator with the provided `DocumentReference` instance.
      /// This sets up the `AsyncThrowingStream` and registers the necessary listener.
      /// - Parameters:
      ///   - documentReference: The `DocumentReference` instance to monitor.
      ///   - includeMetadataChanges: Whether to receive events for metadata-only changes.
      @inlinable
      init(documentReference: DocumentReference, includeMetadataChanges: Bool) {
        stream = AsyncThrowingStream { continuation in
          let listener = documentReference
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
      /// Returns a `DocumentSnapshot` value or `nil` if the sequence has terminated.
      /// Throws an error if the underlying listener encounters an issue.
      /// - Returns: An optional `DocumentSnapshot` object.
      @inlinable
      public mutating func next() async throws -> Element? {
        try await streamIterator.next()
      }
    }
  }
}

// Explicitly mark the Iterator as unavailable for Sendable conformance
@available(*, unavailable)
extension DocumentReference.DocumentSnapshotsSequence.Iterator: Sendable {}
