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

import FirebaseFirestore

/// A special type used to mark a custom object field to be
/// automatically populated with the document's referecne
/// when the custom object is created from a Cloud Firestore
/// document (for example, via `DocumentSnapshot.data()`).
///
/// If the field name used for this type conflicts with a read
/// document field, an error is thrown. For example, if a custom
/// object has a field `firstName` with type AutoPopulatedDocumentId,
/// and there is a property from the document named `firstName`
/// as well, an error is thrown when you try to read the
/// document.
///
/// When using a custom object to write to a document, the field
/// with this type is ignored, which allows writing the object
/// back to any document, even if it's not the origin of the
/// object.
///
/// NOTE: Trying to decode to an `AutoPopulatedDocumentId?` type
/// leads to an error, this is because compiler generated codable
/// implementations checks for fields existence for optional
/// types.
///
/// NOTE: Trying to encode/decode this type using
/// encoders/decoders other than FirestoreEncoder leads to an
/// error.
public final class AutoPopulatedDocumentId: Equatable, Codable {
  public let ref: DocumentReference

  public init(from ref: DocumentReference) {
    self.ref = ref
  }

  public init(from decoder: Decoder) throws {
    throw FirestoreDecodingError.decodingIsNotSupported
  }

  public func encode(to encoder: Encoder) throws {
    throw FirestoreEncodingError.encodingIsNotSupported
  }

  public static func == (lhs: AutoPopulatedDocumentId,
                         rhs: AutoPopulatedDocumentId) -> Bool {
    return lhs.ref == rhs.ref
  }
}
