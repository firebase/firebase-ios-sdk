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

  #if canImport(FirebaseFirestoreSwift)

    import FirebaseFirestoreSwift

  #endif

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  extension DocumentReference {
    // MARK: - Set Data

    /// Overwrites the document referred to by this `DocumentReference`. If no document exists, it
    /// is created. If a document already exists, it is overwritten.
    ///
    /// - Parameter documentData: A `Dictionary` containing the fields that make up the document to
    ///   be written.
    /// - Returns: A publisher emitting a `Void` value once the document has been successfully
    ///   written to the server. This publisher will not emit while the client is offline, though
    ///   local changes will be visible immediately.
    public func setData(_ documentData: [String: Any]) -> Future<Void, Error> {
      Future { promise in
        self.setData(documentData) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Writes to the document referred to by this `DocumentReference`. If the document does not yet
    /// exist, it will be created. If you pass `merge: true`, the provided data will be merged into
    /// any existing document.
    ///
    /// - Parameters:
    ///   - documentData: A `Dictionary` containing the fields that make up the document to be
    ///   written.
    ///   - merge: Whether to merge the provided data into any existing document.
    /// - Returns: A publisher emitting a `Void` value once the document has been successfully
    ///   written to the server. This publisher will not emit while the client is offline, though
    ///   local changes will be visible immediately.
    public func setData(_ documentData: [String: Any], merge: Bool) -> Future<Void, Error> {
      Future { promise in
        self.setData(documentData, merge: merge) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Writes to the document referred to by this `DocumentReference` and only replace the fields
    /// specified under `mergeFields`. Any field that is not specified in `mergeFields` is ignored
    /// and remains untouched. If the document doesn't yet exist, this method creates it and then
    /// sets the data.
    ///
    /// - Parameters:
    ///   - documentData: A `Dictionary` containing the fields that make up the document to be
    ///   written.
    ///   - mergeFields: An `Array` that contains a list of `String` or `FieldPath` elements
    ///   specifying which fields to merge. Fields can contain dots to reference nested fields
    ///   within the document.
    /// - Returns: A publisher emitting a `Void` value once the document has been successfully
    ///   written to the server. This publisher will not emit while the client is offline, though
    ///   local changes will be visible immediately.
    public func setData(_ documentData: [String: Any], mergeFields: [Any]) -> Future<Void, Error> {
      Future { promise in
        self.setData(documentData, mergeFields: mergeFields) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    #if canImport(FirebaseFirestoreSwift)

      /// Encodes an instance of `Encodable` and overwrites the encoded data to the document referred
      ///  by this `DocumentReference`. If no document exists, it is created. If a document already
      ///  exists, it is overwritten.
      ///
      /// - Parameters:
      ///   - value: An instance of `Encodable` to be encoded to a document.
      ///   - encoder: An encoder instance to use to run the encoding.
      /// - Returns: A publisher emitting a `Void` value once the document has been successfully
      ///   written to the server. This publisher will not emit while the client is offline, though
      ///   local changes will be visible immediately.
      public func setData<T: Encodable>(from value: T,
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
        Void,
        Error
      > {
        Future { promise in
          do {
            try self.setData(from: value) { error in
              if let error = error {
                promise(.failure(error))
              } else {
                promise(.success(()))
              }
            }
          } catch {
            promise(.failure(error))
          }
        }
      }

      /// Encodes an instance of `Encodable` and overwrites the encoded data to the document referred
      ///  by this `DocumentReference`. If no document exists, it is created. If a document already
      ///  exists, it is overwritten. If you pass `merge: true`, the provided Encodable will be merged
      ///   into any existing document.
      ///
      /// - Parameters:
      ///   - value: An instance of `Encodable` to be encoded to a document.
      ///   - merge: Whether to merge the provided data into any existing document.
      ///   - encoder: An encoder instance to use to run the encoding.
      /// - Returns: A publisher emitting a `Void` value once the document has been successfully
      ///   written to the server. This publisher will not emit while the client is offline, though
      ///   local changes will be visible immediately.
      public func setData<T: Encodable>(from value: T, merge: Bool,
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
        Void,
        Error
      > {
        Future { promise in
          do {
            try self.setData(from: value, merge: merge) { error in
              if let error = error {
                promise(.failure(error))
              } else {
                promise(.success(()))
              }
            }
          } catch {
            promise(.failure(error))
          }
        }
      }

      /// Encodes an instance of `Encodable` and writes the encoded data to the document referred by
      /// this `DocumentReference` by only replacing the fields specified under mergeFields. Any field
      /// that is not specified in mergeFields is ignored and remains untouched. If the document
      /// doesn’t yet exist, this method creates it and then sets the data.
      ///
      /// - Parameters:
      ///   - value: An instance of `Encodable` to be encoded to a document.
      ///   - mergeFields: An `Array` that contains a list of `String` or `FieldPath` elements
      ///   specifying which fields to merge. Fields can contain dots to reference nested fields
      ///   within the document.
      ///   - encoder: An encoder instance to use to run the encoding.
      /// - Returns: A publisher emitting a `Void` value once the document has been successfully
      ///   written to the server. This publisher will not emit while the client is offline, though
      ///   local changes will be visible immediately.
      public func setData<T: Encodable>(from value: T, mergeFields: [Any],
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
        Void,
        Error
      > {
        Future { promise in
          do {
            try self.setData(from: value, mergeFields: mergeFields) { error in
              if let error = error {
                promise(.failure(error))
              } else {
                promise(.success(()))
              }
            }
          } catch {
            promise(.failure(error))
          }
        }
      }

    #endif

    // MARK: - Update Data

    /// Updates fields in the document referred to by this `DocumentReference`. If the document does
    /// not exist, the update fails and the specified completion block receives an error.
    ///
    /// - Parameter documentData: A `Dictionary` containing the fields (expressed as a `String` or
    ///   `FieldPath`) and values with which to update the document.
    /// - Returns: A publisher emitting a `Void` when the update is complete. This block will only
    ///   execute when the client is online and the commit has completed against the server. This
    ///   publisher will not emit while the device is offline, though local changes will be visible
    ///   immediately.
    public func updateData(_ documentData: [String: Any]) -> Future<Void, Error> {
      Future { promise in
        self.updateData(documentData) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    // MARK: - Delete

    /// Deletes the document referred to by this `DocumentReference`.
    ///
    /// - Returns: A publisher emitting a `Void` when the document has been deleted from the server.
    ///   This publisher will not emit while the device is offline, though local changes will be
    ///   visible immediately.
    public func delete() -> Future<Void, Error> {
      Future { promise in
        self.delete { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    // MARK: - Get Document

    /// Reads the document referenced by this `DocumentReference`.
    ///
    /// - Parameter source: Indicates whether the results should be fetched from the cache only
    ///  (`Source.cache`), the server only (`Source.server`), or to attempt the server and fall back
    ///   to the cache (`Source.default`).
    /// - Returns: A publisher emitting a `DocumentSnapshot` instance.
    public func getDocument(source: FirestoreSource = .default)
      -> Future<DocumentSnapshot, Error> {
      Future { promise in
        self.getDocument(source: source) { snapshot, error in
          if let error = error {
            promise(.failure(error))
          } else if let snapshot = snapshot {
            promise(.success(snapshot))
          }
        }
      }
    }

    // MARK: - Snapshot Publisher

    /// Registers a publisher that publishes document snapshot changes.
    ///
    /// - Parameter includeMetadataChanges: Whether metadata-only changes (i.e. only
    ///   `DocumentSnapshot.metadata` changed) should trigger snapshot events.
    /// - Returns: A publisher emitting `DocumentSnapshot` instances.
    public func snapshotPublisher(includeMetadataChanges: Bool = false)
      -> AnyPublisher<DocumentSnapshot, Error> {
      let subject = PassthroughSubject<DocumentSnapshot, Error>()
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
