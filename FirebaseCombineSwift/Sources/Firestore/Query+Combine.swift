// Copyright 2021 Google LLC
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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseFirestore

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  extension Query {
    // MARK: - Get Documents

    /// Reads the documents matching this query.
    ///
    /// - Parameter source: Indicates whether the results should be fetched from the cache only
    ///   (`Source.cache`), the server only (`Source.server`), or to attempt the server and fall back
    ///   to the cache (`Source.default`).
    /// - Returns: A publisher emitting a `QuerySnapshot` instance.
    public func getDocuments(source: FirestoreSource = .default) -> Future<QuerySnapshot, Error> {
      Future { promise in
        self.getDocuments(source: source) { snapshot, error in
          if let error = error {
            promise(.failure(error))
          } else if let snapshot = snapshot {
            promise(.success(snapshot))
          }
        }
      }
    }

    // MARK: - Snapshot Publisher

    /// Registers a publisher that publishes query snapshot changes.
    ///
    /// - Parameter includeMetadataChanges: Whether metadata-only changes (i.e. only
    ///   `QuerySnapshot.metadata` changed) should trigger snapshot events.
    /// - Returns: A publisher emitting `QuerySnapshot` instances.
    public func snapshotPublisher(includeMetadataChanges: Bool = false)
      -> AnyPublisher<QuerySnapshot, Error> {
      let subject = PassthroughSubject<QuerySnapshot, Error>()
      let listenerHandle =
        addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { snapshot, error in
          if let error = error {
            subject.send(completion: .failure(error))
          } else if let snapshot = snapshot {
            subject.send(snapshot)
          }
        }
      return subject
        .handleEvents(receiveCancel: listenerHandle.remove)
        .eraseToAnyPublisher()
    }
  }

#endif
