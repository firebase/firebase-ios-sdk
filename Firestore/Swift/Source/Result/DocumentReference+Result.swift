/*
 * Copyright 2020 Google LLC
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

import FirebaseFirestore

@available(swift 5.0)
extension DocumentReference {
  /// Writes the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, it is created. If a document already exists, it is overwritten.
  ///
  /// - Parameters:
  ///   - documentData: The `Dictionary` containing the data for the new document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  func setData(_ documentData: [String: Any],
               completion: @escaping (_ result: Result<Void, Error>) -> Void) {
    setData(documentData, completion: mapResultCompletion(completion))
  }

  /// Writes the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, it is created. If a document already exists and `merge` is `false`,  it is
  /// overwritten. If a document already exists and `merge` is `true`, the provided data will be
  /// merged into any existing document.
  ///
  /// - Parameters:
  ///   - documentData: The `Dictionary` containing the data for the new document.
  ///   - merge: Whether to merge the provided data into any existing document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  func setData(_ documentData: [String: Any], merge: Bool,
               completion: @escaping (_ result: Result<Void, Error>) -> Void) {
    setData(documentData, merge: merge, completion: mapResultCompletion(completion))
  }

  /// Writes the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, it is created. If a document already exists fields specified in `mergeFields`
  /// will be merged into any existing document.
  ///
  /// It is an error to include a field in `mergeFields` that does not have a corresponding value
  /// in the `data` dictionary.
  ///
  /// - Parameters:
  ///   - documentData: The `Dictionary` containing the data for the new document.
  ///   - mergeFields: The `Array` that contains a list of `String` or `FieldPath` elements
  ///   specifying which fields to merge. Fields can contain dots to reference nested fields within
  ///   the document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  func setData(_ documentData: [String: Any], mergeFields: [Any],
               completion: @escaping (_ result: Result<Void, Error>) -> Void) {
    setData(documentData, mergeFields: mergeFields, completion: mapResultCompletion(completion))
  }

  /// Writes the document referred to by this `DocumentReference` encoding an instance of
  /// `Encodable`. If no document exists, it is created. If a document already exists, it is
  /// overwritten.
  ///
  /// See Firestore.Encoder for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: The instance of Encodable to be encoded to a document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt
  ///   of an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  /// - Throws: `Firestore.Encoder` encoding errors.
  func setData<T: Encodable>(from value: T, encoder: Firestore.Encoder = Firestore.Encoder(),
                             completion: @escaping (_ result: Result<Void, Error>)
                               -> Void) throws {
    try setData(from: value, encoder: encoder, completion: mapResultCompletion(completion))
  }

  /// Writes the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, it is created. If a document already exists and `merge` is `false`,  it is
  /// overwritten. If a document already exists and `merge` is `true`, the provided data will be
  /// merged into any existing document.
  ///
  /// See Firestore.Encoder for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: The instance of Encodable to be encoded to a document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - merge: Whether to merge the provided data into any existing document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  /// - Throws: `Firestore.Encoder` encoding errors.
  func setData<T: Encodable>(from value: T, merge: Bool,
                             encoder: Firestore.Encoder = Firestore.Encoder(),
                             completion: @escaping (_ result: Result<Void, Error>)
                               -> Void) throws {
    try setData(
      from: value,
      merge: merge,
      encoder: encoder,
      completion: mapResultCompletion(completion)
    )
  }

  /// Writes the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, it is created. If a document already exists fields specified in `mergeFields`
  /// will be merged into any existing document.
  ///
  /// It is an error to include a field in `mergeFields` that does not have a corresponding value in
  /// the `data` dictionary.
  ///
  /// See Firestore.Encoder for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: The instance of Encodable to be encoded to a document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - mergeFields: The `Array` that contains a list of `String` or `FieldPath` elements
  ///   specifying which fields to merge. Fields can contain dots to reference nested fields within
  ///   the document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt
  ///   of an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  /// - Throws: `Firestore.Encoder` encoding errors.
  func setData<T: Encodable>(from value: T, mergeFields: [Any],
                             encoder: Firestore.Encoder = Firestore.Encoder(),
                             completion: @escaping (_ result: Result<Void, Error>)
                               -> Void) throws {
    try setData(
      from: value,
      mergeFields: mergeFields,
      encoder: encoder,
      completion: mapResultCompletion(completion)
    )
  }

  /// Updates the document referred to by this `DocumentReference` with the specified data. If no
  /// document exists, the update fails with an error. If a document already exists, it is
  /// overwritten.
  ///
  /// - Parameters:
  ///   - fields: The `Dictionary` containing the fields (expressed as `String` or `FieldPath`) and
  ///   values with which to update the document.
  ///   - completion: The closure to execute on successfully updating to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  func updateData(_ fields: [AnyHashable: Any],
                  completion: @escaping (_ result: Result<Void, Error>) -> Void) {
    updateData(fields, completion: mapResultCompletion(completion))
  }

  /// Delete the document referred to by this `DocumentReference` with the specified data.
  ///
  /// - Parameters:
  ///   - completion: The closure to execute on successfully deleting to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be
  ///   visible immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  func delete(completion: @escaping (_ result: Result<Void, Error>) -> Void) {
    delete(completion: mapResultCompletion(completion))
  }

  /// Reads the document referenced by this `DocumentReference`.
  ///
  /// - Parameters:
  ///   - source: The `FirestoreSource` where the results should be fetched:
  ///     - `default`:  Fetch from the server and, if it fails, the cache.
  ///     - `server`:  Fetch from the server only.
  ///     - `cache`:  Fetch from the cache only.
  ///   - completion: The closure to execute on receipt of a result.
  ///   - result: The result of request. On success it contains the `DocumentSnapshot`, otherwise an
  ///   `Error`.
  func getDocument(source: FirestoreSource = .default,
                   completion: @escaping (_ result: Result<DocumentSnapshot, Error>) -> Void) {
    getDocument(source: source, completion: mapResultCompletion(completion))
  }

  /// Attaches a listener for this `DocumentSnapshot` events.
  ///
  /// - Parameters:
  ///   - includeMetadataChanges: Whether metadata-only changes (i.e. only
  ///   `DocumentSnapshot.metadata` changed) should trigger snapshot events.
  ///   - listener: The closure to execute on receipt of a result.
  ///   - result: The result of request. On success it contains the `DocumentSnapshot`, otherwise an
  ///   `Error`.
  /// - Returns: The `ListenerRegistration` that can be used to remove this listener.
  func addSnapshotListener(includeMetadataChanges: Bool = false,
                           listener: @escaping (_ result: Result<DocumentSnapshot, Error>)
                             -> Void)
    -> ListenerRegistration {
    return addSnapshotListener(
      includeMetadataChanges: includeMetadataChanges,
      listener: mapResultCompletion(listener)
    )
  }
}

/// Returns a closure mapped from the a given closure with a `Result` parameter.
///
/// - Precondition:
///   Internal return value and error must not both be nil.
///
/// - Parameters:
///   - completion: The closure to map.
///   - result: The parameter of the closure to map.
/// - Returns: A closure mapped from the given closure.
private func mapResultCompletion<T>(_ completion: @escaping (_ result: Result<T, Error>) -> Void)
  -> ((T?, Error?) -> Void) {
  return { value, error in
    if let value = value {
      completion(.success(value))
    } else if let error = error {
      completion(.failure(error))
    } else {
      fatalError("Internal return value and error must not both be nil")
    }
  }
}

/// Returns a closure mapped from the a given closure with a `Result` parameter.
///
/// - Parameters:
///   - completion: The closure to map.
///   - result: The parameter of the closure to map.
/// - Returns: A closure mapped from the given closure.
private func mapResultCompletion(_ completion: @escaping (_ result: Result<Void, Error>) -> Void)
  -> ((Error?) -> Void) {
  return { error in
    if let error = error {
      completion(.failure(error))
    } else {
      completion(.success(()))
    }
  }
}
