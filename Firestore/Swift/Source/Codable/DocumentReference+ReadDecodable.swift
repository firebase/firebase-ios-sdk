/*
 * Copyright 2021 Google
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

import Foundation
import FirebaseFirestore

extension DocumentReference {
  /// Fetches and decodes the document referenced by this `DocumentReference`.
  ///
  /// This allows users to retrieve a Firestore document and have it decoded to an instance of
  /// caller-specified type.
  /// ```swift
  ///     ref.getDocument(as: Book.self) { result in
  ///       do {
  ///         let book = try result.get()
  ///       } catch {
  ///         // Handle error
  ///       }
  ///     }
  /// ```
  /// - Parameters:
  ///   - as: A `Decodable` type to convert the document fields to.
  ///   - serverTimestampBehavior: Configures how server timestamps that have
  ///     not yet been set to their final value are returned from the snapshot.
  ///   - decoder: The decoder to use to convert the document. `nil` to use
  ///   - completion: The closure to call when the document snapshot has been fetched and decoded.
  public func getDocument<T: Decodable>(as type: T.Type,
                                        with serverTimestampBehavior: ServerTimestampBehavior =
                                          .none,
                                        decoder: Firestore.Decoder? = nil,
                                        completion: @escaping (Result<T, Error>) -> Void) {
    getDocument { snapshot, error in
      guard let snapshot = snapshot else {
        completion(.failure(error ?? FirestoreDecodingError.internal))
        return
      }
      let result = Result {
        try snapshot.data(as: T.self,
                          with: serverTimestampBehavior,
                          decoder: decoder)
      }
      completion(result)
    }
  }

  // TODO: How do you annotate that using Xcode 13.2 you can actually compile to earlier os versions
  #if compiler(>=5.5) && canImport(_Concurrency)
    /// Fetches and decodes the document referenced by this `DocumentReference`.
    ///
    /// This allows users to retrieve a Firestore document and have it decoded to an instance of
    /// caller-specified type.
    /// ```swift
    ///     let book = try await ref.getDocument(as: Book.self)
    /// ```
    /// - Parameters:
    ///   - as: A `Decodable` type to convert the document fields to.
    ///   - serverTimestampBehavior: Configures how server timestamps that have
    ///     not yet been set to their final value are returned from the snapshot.
    ///   - decoder: The decoder to use to convert the document. `nil` to use
    /// - Returns: This instance of the supplied `Decodable` type `T`.
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    public func getDocument<T: Decodable>(as type: T.Type,
                                          with serverTimestampBehavior: ServerTimestampBehavior =
                                            .none,
                                          decoder: Firestore.Decoder? = nil) async throws -> T {
      let snapshot = try await getDocument()
      return try snapshot.data(as: T.self,
                               with: serverTimestampBehavior,
                               decoder: decoder)
    }
  #endif
}
