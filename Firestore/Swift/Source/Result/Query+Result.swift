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
extension Query {
  /// Reads the documents matching this query.
  ///
  /// - Parameters:
  ///   - source: The `FirestoreSource` where the results should be fetched:
  ///     - `default`:  Fetch from the server and, if it fails, the cache.
  ///     - `server`:  Fetch from the server only.
  ///     - `cache`:  Fetch from the cache only.
  ///   - completion: The closure to execute on receipt of a result.
  ///   - result: The result of request. On success it contains the `QuerySnapshot`, otherwise an
  ///   `Error`.
  func getDocuments(source: FirestoreSource = .default,
                    completion: @escaping (_ result: Result<QuerySnapshot, Error>) -> Void) {
    getDocuments(source: source, completion: mapResultCompletion(completion))
  }

  /// Attaches a listener for this `Query` events.
  ///
  /// - Parameters:
  ///   - includeMetadataChanges: Whether metadata-only changes (i.e. only
  ///   `DocumentSnapshot.metadata` changed) should trigger snapshot events.
  ///   - listener: The closure to execute on receipt of a result.
  ///   - result: The result of request. On success it contains the `QuerySnapshot`, otherwise an
  ///   `Error`.
  /// - Returns: The `ListenerRegistration` that can be used to remove this listener.
  func addSnapshotListener(includeMetadataChanges: Bool = false,
                           listener: @escaping (_ result: Result<QuerySnapshot, Error>)
                             -> Void) -> ListenerRegistration {
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
