/*
 * Copyright 2022 Google LLC
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
import FirebaseSharedSwift
import Foundation

public extension Firestore {
  class Encoder {
    /// The strategy to use in encoding dates. Defaults to `.timestamp`.
    public var dateEncodingStrategy: FirebaseDataEncoder.DateEncodingStrategy = .timestamp

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    public var dataEncodingStrategy: FirebaseDataEncoder.DataEncodingStrategy = .base64

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    public var nonConformingFloatEncodingStrategy: FirebaseDataEncoder
      .NonConformingFloatEncodingStrategy = .throw

    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
    public var keyEncodingStrategy: FirebaseDataEncoder.KeyEncodingStrategy = .useDefaultKeys

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
      let encoder = FirebaseDataEncoder()
      encoder.dateEncodingStrategy = dateEncodingStrategy
      encoder.dataEncodingStrategy = dataEncodingStrategy
      encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
      encoder.keyEncodingStrategy = keyEncodingStrategy
      encoder.passthroughTypeResolver = FirestorePassthroughTypes.self
      encoder.userInfo = userInfo
      let encoded = try encoder.encode(value)
      guard let dictionaryValue = encoded as? [String: Any] else {
        throw EncodingError
          .invalidValue(value,
                        EncodingError
                          .Context(codingPath: [],
                                   debugDescription: "Top-level \(T.self) is not allowed."))
      }
      return dictionaryValue
    }

    public init() {}
  }

  class Decoder {
    /// The strategy to use in decoding dates. Defaults to `.timestamp`.
    public var dateDecodingStrategy: FirebaseDataDecoder.DateDecodingStrategy = .timestamp

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    public var dataDecodingStrategy: FirebaseDataDecoder.DataDecodingStrategy = .base64

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    public var nonConformingFloatDecodingStrategy: FirebaseDataDecoder
      .NonConformingFloatDecodingStrategy = .throw

    /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
    public var keyDecodingStrategy: FirebaseDataDecoder.KeyDecodingStrategy = .useDefaultKeys

    /// Contextual user-provided information for use during decoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public func decode<T: Decodable>(_ t: T.Type, from data: Any) throws -> T {
      let decoder = FirebaseDataDecoder()
      decoder.dateDecodingStrategy = dateDecodingStrategy
      decoder.dataDecodingStrategy = dataDecodingStrategy
      decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
      decoder.keyDecodingStrategy = keyDecodingStrategy
      decoder.passthroughTypeResolver = FirestorePassthroughTypes.self
      decoder.userInfo = userInfo
      // configure for firestore
      return try decoder.decode(t, from: data)
    }

    public func decode<T: Decodable>(_ t: T.Type, from data: Any,
                                     in reference: DocumentReference?) throws -> T {
      if let reference = reference {
        userInfo[CodingUserInfoKey.documentRefUserInfoKey] = reference
      }
      return try decode(T.self, from: data)
    }

    public init() {}
  }
}
