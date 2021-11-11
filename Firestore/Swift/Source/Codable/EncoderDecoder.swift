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

import FirebaseFirestore
import FirebaseEncoderSwift
import Foundation

extension Firestore {
  public typealias Encoder = StructureEncoder
  public typealias Decoder = StructureDecoder
}

extension Firestore.Encoder {
  internal func configureForFirestore() {
    self.passthroughTypeResolver = FirestorePassthroughTypes.self
  }
}

extension Firestore.Decoder {
  internal func configureForFirestore() {
    self.passthroughTypeResolver = FirestorePassthroughTypes.self
    self.dateDecodingStrategy = .timestamp(fallback: self.dateDecodingStrategy)
  }

  public func decode<T: Decodable>(_ t: T.Type, from data: Any, in reference: DocumentReference) throws -> T?  {
    self.userInfo[documentRefUserInfoKey] = reference
    self.configureForFirestore()
    return try self.decode(T.self, from: data)
  }
}
