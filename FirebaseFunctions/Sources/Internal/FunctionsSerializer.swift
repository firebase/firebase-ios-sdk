// Copyright 2022 Google LLC
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

extension FunctionsSerializer {
  enum Error: Swift.Error {
    case unsupportedType(typeName: String)
    case failedToParseWrappedNumber(value: String, type: String)
  }
}

final class FunctionsSerializer: Sendable {
  // MARK: - Internal APIs

  // This function only supports the following types and will otherwise throw
  // an error.
  // - NSNull (note: `nil` collection values from a Swift caller will be treated as NSNull)
  // - NSNumber
  // - NSString
  // - NSDictionary
  // - NSArray
  func encode(_ object: Any) throws -> Any {
    if object is NSNull {
      return object
    } else if let number = object as? NSNumber {
      return wrapNumberIfNeeded(number)
    } else if object is NSString {
      return object
    } else if let dict = object as? NSDictionary {
      let encoded = NSMutableDictionary()
      try dict.forEach { key, value in
        encoded[key] = try encode(value)
      }
      return encoded
    } else if let array = object as? NSArray {
      return try array.map { element in
        try encode(element)
      }
    } else {
      throw Error.unsupportedType(typeName: typeName(of: object))
    }
  }

  // This function only supports the following types and will otherwise throw
  // an error.
  // - NSNull (note: `nil` collection values from a Swift caller will be treated as NSNull)
  // - NSNumber
  // - NSString
  // - NSDictionary
  // - NSArray
  func decode(_ object: Any) throws -> Any {
    // Return these types as is. PORTING NOTE: Moved from the bottom of the func for readability.
    if let dict = object as? NSDictionary {
      if let wrappedNumber = WrappedNumber(from: dict) {
        return try unwrapNumber(wrappedNumber)
      }

      let decoded = NSMutableDictionary()
      try dict.forEach { key, value in
        decoded[key] = try decode(value)
      }
      return decoded
    } else if let array = object as? NSArray {
      let decoded = NSMutableArray(capacity: array.count)
      try array.forEach { element in
        try decoded.add(decode(element) as Any)
      }
      return decoded
    } else if object is NSNumber || object is NSString || object is NSNull {
      return object as AnyObject
    }

    throw Error.unsupportedType(typeName: typeName(of: object))
  }

  // MARK: - Private Helpers

  private func typeName(of value: Any) -> String {
    String(describing: type(of: value))
  }

  private func wrapNumberIfNeeded(_ number: NSNumber) -> Any {
    switch String(cString: number.objCType) {
    case "q":
      // "long long" might be larger than JS supports, so make it a string:
      return WrappedNumber(type: .long, value: "\(number)").encoded
    case "Q":
      // "unsigned long long" might be larger than JS supports, so make it a string:
      return WrappedNumber(type: .unsignedLong, value: "\(number)").encoded
    default:
      // All other types should fit JS limits, so return the number as is:
      return number
    }
  }

  private func unwrapNumber(_ wrapped: WrappedNumber) throws(Error) -> any Numeric {
    switch wrapped.type {
    case .long:
      guard let n = Int(wrapped.value) else {
        throw .failedToParseWrappedNumber(
          value: wrapped.value,
          type: wrapped.type.rawValue
        )
      }
      return n
    case .unsignedLong:
      guard let n = UInt(wrapped.value) else {
        throw .failedToParseWrappedNumber(
          value: wrapped.value,
          type: wrapped.type.rawValue
        )
      }
      return n
    }
  }
}

// MARK: - WrappedNumber

extension FunctionsSerializer {
  private struct WrappedNumber {
    let type: NumberType
    let value: String

    // When / if objects are encoded / decoded using `Codable`,
    // these two `init`s and `encoded` won’t be needed anymore:

    init(type: NumberType, value: String) {
      self.type = type
      self.value = value
    }

    init?(from dictionary: NSDictionary) {
      guard
        let typeString = dictionary["@type"] as? String,
        let type = NumberType(rawValue: typeString),
        let value = dictionary["value"] as? String
      else {
        return nil
      }

      self.init(type: type, value: value)
    }

    var encoded: [String: String] {
      ["@type": type.rawValue, "value": value]
    }

    enum NumberType: String {
      case long = "type.googleapis.com/google.protobuf.Int64Value"
      case unsignedLong = "type.googleapis.com/google.protobuf.UInt64Value"
    }
  }
}
