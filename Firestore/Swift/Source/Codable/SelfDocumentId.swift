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

/// A value that is populated in Codable objects with a `DocumentReference` by
/// the FirestoreDecoder when a document is read.
///
/// Note that limitations in Swift compiler-generated Codable implementations
/// prevent using this type wrapped in an Optional. Optional SelfDocumentIDs
/// are possible if you write a custom `init(from: Decoder)` method.
///
/// If the field name used for this type conflicts with a read document field,
/// an error is thrown. For example, if a custom object has a field `firstName`
/// with type `SelfDocumentID`, and there is a property from the document named
/// `firstName` as well, an error is thrown when you try to read the document.
///
/// When writing a Codable object containing a `SelfDocumentID`, its value is
/// ignored. This allows you to read a document from one path and write it into
/// another without adjusting the value here.
///
/// NOTE: Trying to encode/decode this type using encoders/decoders other than
/// FirestoreEncoder leads to an error.
public final class SelfDocumentID: Equatable, Codable {
  // MARK: - Initializers

  public init() {
    reference = nil
  }

  public init(from ref: DocumentReference?) {
    reference = ref
  }

  // MARK: - `Codable` implemention.

  public init(from decoder: Decoder) throws {
    throw FirestoreDecodingError.decodingIsNotSupported
  }

  public func encode(to encoder: Encoder) throws {
    throw FirestoreEncodingError.encodingIsNotSupported
  }

  // MARK: - Properties

  public var id: String? {
    return reference?.documentID
  }

  public let reference: DocumentReference?

  // MARK: - `Equatable` implementation

  public static func == (lhs: SelfDocumentID,
                         rhs: SelfDocumentID) -> Bool {
    return lhs.reference == rhs.reference
  }
}
