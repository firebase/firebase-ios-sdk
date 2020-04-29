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

#if canImport(Combine)
  import Combine

  import Foundation
  import FirebaseFirestore

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  extension Query {
    /**
     * Reads the documents matching this query.
     *
     * This method returns a publisher that yields an array
     * of `QuerySnapshot`s, requiring the user to extract the underlying
     * `DocumentSnapshot`s before using them:
     *
     * ```
     * let noBooks = [Book]()
     * db.collection("books").getDocuments()
     *   .map { querySnapshot in
     *     querySnapshot.documents.compactMap { (queryDocumentSnapshot) in
     *       return try? queryDocumentSnapshot.data(as: Book.self)
     *     }
     *   }
     *   .replaceError(with: noBooks)
     *   .assign(to: \.books, on: self)
     *   .store(in: &cancellables)
     * ```
     */
    public func getDocuments() -> AnyPublisher<QuerySnapshot, Error> {
      Future<QuerySnapshot, Error> { [weak self] promise in
        self?.getDocuments { querySnapshot, error in
          if let error = error {
            promise(.failure(error))
          } else if let querySnapshot = querySnapshot {
            promise(.success(querySnapshot))
          }
        }
      }
      .eraseToAnyPublisher()
    }

    /**
     * Reads the documents matching this query.
     *
     * This method returns a publisher that yields an array
     * of `DocumentSnapshot`s, allowing the user to easily iterate over
     * the documents themselves:
     *
     * ```
     * let noBooks = [Book]()
     * db.collection("books").getDocuments2()
     *   .map { documentSnapshots in
     *     documentSnapshots.compactMap { documentSnapshot -> Book? in
     *       return try? documentSnapshot.data(as: Book.self)
     *     }
     *   }
     *   .replaceError(with: noBooks)
     *   .assign(to: \.books, on: self)
     *   .store(in: &cancellables)
     * ```
     */
    public func getDocuments2() -> AnyPublisher<[DocumentSnapshot], Error> {
      Future<[DocumentSnapshot], Error> { [weak self] promise in
        self?.getDocuments(completion: { querySnapshot, error in
          if let error = error {
            promise(.failure(error))
          } else if let querySnapshot = querySnapshot {
            promise(.success(querySnapshot.documents))
          }
        })
      }
      .eraseToAnyPublisher()
    }
  }
#endif
