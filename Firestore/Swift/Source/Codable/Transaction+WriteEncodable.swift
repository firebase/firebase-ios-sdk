/*
 * Copyright 2019 Google
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

extension Transaction {
  /// Encodes an instance of `Encodable` and overwrites the encoded data
  /// to the document referred by this `DocumentReference`. If no document exists,
  /// it is created. If a document already exists, it is overwritten.
  ///
  /// See `Firestore.Encoder` for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: a instance of `Encoded` to be encoded to a document.
  ///   - doc: The document to create/overwrite the encoded data to.
  /// - Returns: This instance of `Transaction`. Used for chaining method calls.
  public func setData<T: Encodable>(from value: T,
                                    forDocument doc: DocumentReference) throws -> Transaction {
    return try setData(from: value, encoder: Firestore.Encoder(), forDocument: doc)
  }

  /// Encodes an instance of `Encodable` and overwrites the encoded data
  /// to the document referred by this `DocumentReference`. If no document exists,
  /// it is created. If a document already exists, it is overwritten.
  ///
  /// See `Firestore.Encoder` for more details about the encoding process.
  ///
  /// - Parameters:
  ///   - value: a instance of `Encoded` to be encoded to a document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - doc: The document to create/overwrite the encoded data to.
  /// - Returns: This instance of `Transaction`. Used for chaining method calls.
  public func setData<T: Encodable>(from value: T,
                                    encoder: Firestore.Encoder,
                                    forDocument doc: DocumentReference) throws -> Transaction {
    setData(try encoder.encode(value), forDocument: doc)
    return self
  }

  /// Updates fields in the document referred to by `doc`, using the `Encodable` object
  /// passed in. If document does not exist, the write batch will fail.
  ///
  /// - Parameters:
  ///   - value: An instance of `Encodable` to be used to update the Firestore document.
  ///   - doc: The document to update the encoded data to.
  /// - Returns: This instance of `Transaction`. Used for chaining method calls.
  public func updateData<T: Encodable>(from value: T,
                                       forDocument doc: DocumentReference)
    throws -> Transaction {
    return try updateData(from: value, encoder: Firestore.Encoder(), forDocument: doc)
  }

  /// Updates fields in the document referred to by `doc`, using the `Encodable` object
  /// passed in. If document does not exist, the write batch will fail.
  ///
  /// - Parameters:
  ///   - value: An instance of `Encodable` to be used to update the Firestore document.
  ///   - encoder: The encoder instance to use to run the encoding.
  ///   - doc: The document to update the encoded data to.
  /// - Returns: This instance of `Transaction`. Used for chaining method calls.
  public func updateData<T: Encodable>(from value: T,
                                       encoder: Firestore.Encoder,
                                       forDocument doc: DocumentReference)
    throws -> Transaction {
    return updateData(try encoder.encode(value), forDocument: doc)
  }
}
