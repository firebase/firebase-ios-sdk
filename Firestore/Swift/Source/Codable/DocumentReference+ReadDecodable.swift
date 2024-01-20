/*
 * Copyright 2021 Google LLC
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
#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

public extension DocumentReference {
  /// Fetches and decodes the document referenced by this `DocumentReference`.
  ///
  /// This allows users to retrieve a Firestore document and have it decoded to
  /// an instance of caller-specified type as follows:
  /// ```swift
  /// ref.getDocument(as: Book.self) { result in
  ///   do {
  ///     let book = try result.get()
  ///   } catch {
  ///     // Handle error
  ///   }
  /// }
  /// ```
  ///
  /// This method attempts to provide up-to-date data when possible by waiting
  /// for data from the server, but it may return cached data or fail if you are
  /// offline and the server cannot be reached. If `T` denotes an optional
  /// type, the method returns a successful status with a value of `nil` for
  /// non-existing documents.
  ///
  /// - Parameters:
  ///   - as: A `Decodable` type to convert the document fields to.
  ///   - serverTimestampBehavior: Configures how server timestamps that have
  ///     not yet been set to their final value are returned from the snapshot.
  ///   - decoder: The decoder to use to convert the document. Defaults to use
  ///     the default decoder.
  ///   - completion: The closure to call when the document snapshot has been
  ///     fetched and decoded.
  func getDocument<T: Decodable>(as type: T.Type,
                                 with serverTimestampBehavior: ServerTimestampBehavior =
                                   .none,
                                 decoder: Firestore.Decoder = .init(),
                                 completion: @escaping (Result<T, Error>) -> Void) {
    getDocument { snapshot, error in
      guard let snapshot = snapshot else {
        /**
         * Force unwrapping here is fine since this logic corresponds to the auto-synthesized
         * async/await wrappers for Objective-C functions with callbacks taking an object and an error
         * parameter. The API should (and does) guarantee that either object or error is set, but never both.
         * For more details see:
         * https://github.com/firebase/firebase-ios-sdk/pull/9101#discussion_r809117034
         */
        completion(.failure(error!))
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

  /// Fetches and decodes the document referenced by this `DocumentReference`.
  ///
  /// This allows users to retrieve a Firestore document and have it decoded
  /// to an instance of caller-specified type as follows:
  /// ```swift
  /// do {
  ///   let book = try await ref.getDocument(as: Book.self)
  /// } catch {
  ///   // Handle error
  /// }
  /// ```
  ///
  /// This method attempts to provide up-to-date data when possible by waiting
  /// for data from the server, but it may return cached data or fail if you
  /// are offline and the server cannot be reached. If `T` denotes
  /// an optional type, the method returns a successful status with a value
  /// of `nil` for non-existing documents.
  ///
  /// - Parameters:
  ///   - as: A `Decodable` type to convert the document fields to.
  ///   - serverTimestampBehavior: Configures how server timestamps that have
  ///     not yet been set to their final value are returned from the
  ///     snapshot.
  ///   - decoder: The decoder to use to convert the document. Defaults to use
  ///     the default decoder.
  /// - Returns: This instance of the supplied `Decodable` type `T`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func getDocument<T: Decodable>(as type: T.Type,
                                 with serverTimestampBehavior: ServerTimestampBehavior =
                                   .none,
                                 decoder: Firestore.Decoder = .init()) async throws -> T {
    let snapshot = try await getDocument()
    return try snapshot.data(as: T.self,
                             with: serverTimestampBehavior,
                             decoder: decoder)
  }
}
