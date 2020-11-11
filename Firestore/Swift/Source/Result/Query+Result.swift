/*
 * Copyright 2020 Google
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

#if swift(>=5.0)

  extension Query {
    /// Reads the documents matching this query.
    ///
    /// - Parameters:
    ///   - source: The `FirestoreSource` where the results should be fetched:
    ///     - `default`:  Fetch from the server and, if it fails, the cache.
    ///     - `server`:  Fetch from the server only.
    ///     - `cache`:  Fetch from the cache only.
    ///   - completion: The closure to execute on receipt of a result.
    ///   - result: The result of request. On success it contains the `QuerySnapshot`, otherwise an `Error`.
    func getDocuments(source: FirestoreSource = .default,
                      completion: @escaping (_ result: Result<QuerySnapshot, Error>) -> Void) {
      getDocuments(source: source, completion: mapResultClosure(completion))
    }

    /// Attaches a listener for this `Query` events.
    ///
    /// - Parameters:
    ///   - includeMetadataChanges: Indicates if metadata changes  should trigger snapshot events.
    ///   - listenerHandler: The closure to execute on receipt of a result.
    ///   - result: The result of request. On success it contains the `QuerySnapshot`, otherwise an `Error`.
    /// - Returns: The `ListenerRegistration` that can be used to remove this listener.
    func addSnapshotListener(includeMetadataChanges: Bool = false,
                             listenerHandler: @escaping (_ result: Result<QuerySnapshot, Error>)
                               -> Void) -> ListenerRegistration {
      addSnapshotListener(
        includeMetadataChanges: includeMetadataChanges,
        listener: mapResultClosure(listenerHandler)
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
  private func mapResultClosure<T>(_ completion: @escaping (_ result: Result<T, Error>) -> Void)
    -> ((T?, Error?) -> Void) {
    {
      if let t = $0 {
        completion(.success(t))
      } else if let e = $1 {
        completion(.failure(e))
      } else {
        // preconditionFailure("Internal return value and error must not both be nil")
        completion(.failure(NSError(domain: "FirebaseFirestoreSwift",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey:
                                      "InternalError - Return value and error are both nil"])))
      }
    }
  }

#endif
