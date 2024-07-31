// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/*
 *** IMPORTANT ***

 Although this class is marked as public,
 this class is not part of supported public API and is subject to change.
 It is only for internal use by Data Connect generated code.

 */
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class CodecHelper<K: CodingKey> {
  // MARK: Encoding

  public func encode(_ value: Encodable, forKey: K,
                     container: inout KeyedEncodingContainer<K>) throws {
    switch value {
    case let int64Value as Int64:
      let int64Converter = Int64CodableConverter()
      let int64Value = try int64Converter.encode(input: int64Value)
      try container.encode(int64Value, forKey: forKey)
    case let uuidValue as UUID:
      let uuidConverter = UUIDCodableConverter()
      let uuidValue = try uuidConverter.encode(input: uuidValue)
      try container.encode(uuidValue, forKey: forKey)
    default:
      try container.encode(value, forKey: forKey)
    }
  }

  

  // MARK: Decoding

  public func decode<T: Decodable>(_ type: T.Type, forKey: K,
                                   container: inout KeyedDecodingContainer<K>) throws -> T {
    if type == Int64.self || type == Int64?.self {
      let int64String = try container.decodeIfPresent(String.self, forKey: forKey)
      let int64Converter = Int64CodableConverter()
      let int64Value = try int64Converter.decode(input: int64String)
      return int64Value as! T
    } else if type == UUID.self || type == UUID?.self {
      let uuidString = try container.decodeIfPresent(String.self, forKey: forKey)
      let uuidConverter = UUIDCodableConverter()
      let uuidDecoded = try uuidConverter.decode(input: uuidString)

      return uuidDecoded as! T
    }
    return try container.decode(type, forKey: forKey)
  }

  

  public init() {}
}

