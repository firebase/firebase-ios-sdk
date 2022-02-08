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

private enum Constants {
  static let longType = "type.googleapis.com/google.protobuf.Int64Value"
  static let unsignedLongType = "type.googleapis.com/google.protobuf.UInt64Value"
  static let dateType = "type.googleapis.com/google.protobuf.Timestamp"
}

enum SerializerError: Error {
  // TODO: Add parameters class name and value
  case unsupportedType // (className: String, value: AnyObject)
  case unknownNumberType(charValue: String, number: NSNumber)
  case invalidValueForType(value: String, requestedType: String)
}

class FUNSerializer: NSObject {
  private let dateFormatter: DateFormatter

  override init() {
    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
  }

  // MARK: - Internal APIs

  internal func encode(_ object: Any) throws -> AnyObject {
    if object is NSNull {
      return object as AnyObject
    } else if object is NSNumber {
      return try encodeNumber(object as! NSNumber)
    } else if object is NSString {
      return object as AnyObject
    } else if object is NSDictionary {
      let dict = object as! NSDictionary
      let encoded: NSMutableDictionary = .init()
      dict.enumerateKeysAndObjects { key, obj, _ in
        // TODO(wilsonryan): Not exact translation
        let anyObj = obj as AnyObject
        let stringKey = key as! String
        let value = try! encode(anyObj)
        encoded[stringKey] = value
      }
      return encoded
    } else if object is NSArray {
      let array = object as! NSArray
      let encoded = NSMutableArray()
      for item in array {
        let anyItem = item as AnyObject
        let encodedItem = try encode(anyItem)
        encoded.add(encodedItem)
      }
      return encoded

    } else {
      throw SerializerError.unsupportedType
    }
  }

  internal func decode(_ object: Any) throws -> AnyObject? {
    // Return these types as is. PORTING NOTE: Moved from the bottom of the func for readability.
    if let dict = object as? NSDictionary {
      if let requestedType = dict["@type"] as? String {
        guard let value = dict["value"] as? String else {
          // Seems like we should throw here - but this maintains compatiblity.
          return dict
        }
        let result = try decodeWrappedType(requestedType, value)
        if result != nil { return result }

        // Treat unknown types as dictionaries, so we don't crash old clients when we add types.
      }

      let decoded = NSMutableDictionary()
      var decodeError: Error?
      dict.enumerateKeysAndObjects { key, obj, stopPointer in
        do {
          let decodedItem = try self.decode(obj)
          decoded[key] = decodedItem
        } catch {
          decodeError = error
          stopPointer.pointee = true
          return
        }
      }

      // Throw the internal error that popped up, if it did.
      if let decodeError = decodeError {
        throw decodeError
      }
      return decoded
    } else if let array = object as? NSArray {
      let result = NSMutableArray(capacity: array.count)
      for obj in array {
        // TODO: Is this data loss? The API is a bit weird.
        if let decoded = try decode(obj) {
          result.add(decoded)
        }
      }
      return result
    } else if object is NSNumber || object is NSString || object is NSNull {
      return object as AnyObject
    }

    throw SerializerError.unsupportedType
  }

  // MARK: - Private Helpers

  private func encodeNumber(_ number: NSNumber) throws -> AnyObject {
    // Recover the underlying type of the number, using the method described here:
    // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber
    let cType = number.objCType

    // Type Encoding values taken from
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/
    // Articles/ocrtTypeEncodings.html
    switch cType[0] {
    case CChar("q".utf8.first!):
      // "long long" might be larger than JS supports, so make it a string.
      return ["@type": Constants.longType, "value": "\(number)"] as AnyObject
    case CChar("Q".utf8.first!):
      // "unsigned long long" might be larger than JS supports, so make it a string.
      return ["@type": Constants.unsignedLongType,
              "value": "\(number)"] as AnyObject

    case CChar("i".utf8.first!),
         CChar("s".utf8.first!),
         CChar("l".utf8.first!),
         CChar("I".utf8.first!),
         CChar("S".utf8.first!):
      // If it"s an integer that isn"t too long, so just use the number.
      return number

    case CChar("f".utf8.first!), CChar("d".utf8.first!):
      // It"s a float/double that"s not too large.
      return number

    case CChar("B".utf8.first!), CChar("c".utf8.first!), CChar("C".utf8.first!):
      // Boolean values are weird.
      //
      // On arm64, objCType of a BOOL-valued NSNumber will be "c", even though @encode(BOOL)
      // returns "B". "c" is the same as @encode(signed char). Unfortunately this means that
      // legitimate usage of signed chars is impossible, but this should be rare.
      //
      // Just return Boolean values as-is.
      return number

    default:
      // All documented codes should be handled above, so this shouldn"t happen.
      throw SerializerError.unknownNumberType(charValue: String(cType[0]), number: number)
    }
  }

  private func decodeWrappedType(_ type: String, _ value: String) throws -> AnyObject? {
    switch type {
    case Constants.longType:
      let formatter = NumberFormatter()
      guard let n = formatter.number(from: value) else {
        throw SerializerError.invalidValueForType(value: value, requestedType: type)
      }
      return n
    case Constants.unsignedLongType:
      // NSNumber formatter doesn't handle unsigned long long, so we have to parse it.
      let str = (value as NSString).utf8String
      var endPtr: UnsafeMutablePointer<CChar>?
      let returnValue = UInt64(strtoul(str, &endPtr, 10))
      guard String(returnValue) == value else {
        throw SerializerError.invalidValueForType(value: value, requestedType: type)
      }
      return NSNumber(value: returnValue)

    default:
      return nil
    }
  }
}
