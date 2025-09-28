/*
 * Copyright 2024 Google LLC
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
  var snapshots: AsyncThrowingStream<DocumentSnapshot, Error> {
    return snapshots(includeMetadataChanges: false)
  }

  /// An asynchronous sequence of document snapshots.
  ///
  /// - Parameter includeMetadataChanges: Whether to receive events for metadata-only changes.
  /// - Returns: An `AsyncThrowingStream` of `DocumentSnapshot` events.
  func snapshots(includeMetadataChanges: Bool) -> AsyncThrowingStream<DocumentSnapshot, Error> {
    return AsyncThrowingStream { continuation in
      let listener = self
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
  }
}
