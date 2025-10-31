/*
 * Copyright 2019 Google LLC
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

public extension CollectionReference {
  /// Encodes an instance of `Encodable` and adds a new document to this collection
  /// with the encoded data, assigning it a document ID automatically.
  ///
  /// See `Firestore.Encoder` for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: An instance of `Encodable` to be encoded to a document.
  ///   - encoder: An encoder instance to use to run the encoding.
  ///   - completion: A block to execute once the document has been successfully
  ///                 written to the server. This block will not be called while
  ///                 the client is offline, though local changes will be visible
  ///                 immediately.
  /// - Returns: A `DocumentReference` pointing to the newly created document.
  @discardableResult
  func addDocument<T: Encodable>(from value: T,
                                 encoder: Firestore.Encoder = Firestore.Encoder(),
                                 completion: ((Error?) -> Void)? = nil) throws
    -> DocumentReference {
    let encoded = try encoder.encode(value)
    return addDocument(data: encoded, completion: completion)
  }

  /// Encodes an instance of `Encodable` and adds a new document to this collection
  /// with the encoded data, assigning it a document ID automatically.
  ///
  /// See `Firestore.Encoder` for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: An instance of `Encodable` to be encoded to a document.
  ///   - encoder: An encoder instance to use to run the encoding.
  /// - Throws: `Error` if the backend rejected the write.
  /// - Returns: A `DocumentReference` pointing to the newly created document.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  func addDocument<T: Encodable>(from value: T,
                                 encoder: Firestore.Encoder = Firestore.Encoder()) async throws
    -> DocumentReference {
    return try await withCheckedThrowingContinuation { continuation in
      var document: DocumentReference?
      do {
        document = try self.addDocument(from: value, encoder: encoder) { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            // Our callbacks guarantee that we either return an error or a document.
            continuation.resume(returning: document!)
          }
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
