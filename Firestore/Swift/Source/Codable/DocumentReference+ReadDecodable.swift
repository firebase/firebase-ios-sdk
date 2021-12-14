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
  /// Encodes an instance of `Encodable` and overwrites the encoded data
  /// to the document referred by this `DocumentReference`. If no document exists,
  /// it is created. If a document already exists, it is overwritten.
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
}
