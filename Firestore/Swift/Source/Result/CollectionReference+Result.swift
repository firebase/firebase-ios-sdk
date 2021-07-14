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
extension CollectionReference {
  /// Adds a new document to this collection with the specified data, assigning it a document ID
  /// automatically.
  ///
  /// - Parameters:
  ///   - data: The `Dictionary` containing the data for the new document.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be visible
  ///   immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  /// - Returns: A `DocumentReference` pointing to the newly created document.
  @discardableResult
  func addDocument(data: [String: Any],
                   completion: @escaping (_ result: Result<Void, Error>) -> Void)
    -> DocumentReference {
    return addDocument(data: data, completion: mapResultCompletion(completion))
  }

  /// Adds a new document to this collection encoding an instance of `Encodable`,  assigning it a
  /// document ID automatically.
  ///
  /// See` Firestore.Encode`  for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: The instance of `Encodable` to be encoded to a document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - completion: The closure to execute on successfully writing to the server or on receipt of
  ///   an error. It will not be called while the client is offline, though local changes will be visible
  ///   immediately.
  ///   - result: The result of request. On success it is empty, otherwise it contains an `Error`.
  /// - Throws: `Firestore.Encoder` encoding errors.
  /// - Returns: A `DocumentReference` pointing to the newly created document.
  @discardableResult
  func addDocument<T: Encodable>(from value: T,
                                 encoder: Firestore.Encoder = Firestore.Encoder(),
                                 completion: @escaping (_ result: Result<Void, Error>)
                                   -> Void) throws -> DocumentReference {
    try addDocument(from: value, encoder: encoder, completion: mapResultCompletion(completion))
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
  return {
    if let e = $0 {
      completion(.failure(e))
    } else {
      completion(.success(()))
    }
  }
}
