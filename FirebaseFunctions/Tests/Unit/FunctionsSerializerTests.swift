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

import FirebaseCore
@testable import FirebaseFunctions
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

import XCTest

class FunctionsSerializerTests: XCTestCase {
  private var serializer: FunctionsSerializer!

  override func setUp() {
    super.setUp()
    serializer = FunctionsSerializer()
  }

  func testEncodeNull() throws {
    let null = NSNull()
    XCTAssertEqual(try serializer.encode(null) as? NSNull, null)
  }

  func testDecodeNull() throws {
    let null = NSNull()
    XCTAssertEqual(try serializer.decode(null) as? NSNull, null)
  }

  func testEncodeInt32() throws {
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.encode(one) as? NSNumber)
  }

  func testEncodeInt() throws {
    let one = NSNumber(1)
    let dict = try XCTUnwrap(serializer.encode(one) as? NSDictionary)
    XCTAssertEqual("type.googleapis.com/google.protobuf.Int64Value", dict["@type"] as? String)
    XCTAssertEqual("1", dict["value"] as? String)
  }

  func testDecodeInt32() throws {
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  func testDecodeInt() throws {
    let one = NSNumber(1)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  func testDecodeIntFromDictionary() throws {
    let dictOne = ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                   "value": "1"]
    XCTAssertEqual(NSNumber(1), try serializer.decode(dictOne) as? NSNumber)
  }

  func testEncodeLong() throws {
    let lowLong = NSNumber(-9_223_372_036_854_775_800)
    let dict = try XCTUnwrap(serializer.encode(lowLong) as? NSDictionary)
    XCTAssertEqual("type.googleapis.com/google.protobuf.Int64Value", dict["@type"] as? String)
    XCTAssertEqual("-9223372036854775800", dict["value"] as? String)
  }

  func testDecodeLong() throws {
    let lowLong = NSNumber(-9_223_372_036_854_775_800)
    XCTAssertEqual(lowLong, try serializer.decode(lowLong) as? NSNumber)
  }

  func testDecodeLongFromDictionary() throws {
    let dictLowLong = ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                       "value": "-9223372036854775800"]
    let decoded = try serializer.decode(dictLowLong) as? NSNumber
    XCTAssertEqual(NSNumber(-9_223_372_036_854_775_800), decoded)
    // A naive implementation might convert a number to a double and think that's close enough.
    // We need to make sure it's a long long for accuracy.
    XCTAssertEqual(decoded?.objCType[0], CChar("q".utf8.first!))
  }

  func testDecodeInvalidLong() throws {
    let typeString = "type.googleapis.com/google.protobuf.Int64Value"
    let badVal = "-9223372036854775800 and some other junk"
    let dictLowLong = ["@type": typeString, "value": badVal]
    do {
      _ = try serializer.decode(dictLowLong) as? NSNumber
    } catch let FunctionsSerializer.Error.invalidValueForType(value, type) {
      XCTAssertEqual(value, badVal)
      XCTAssertEqual(type, typeString)
      return
    }
    XCTFail()
  }

  func testEncodeUnsignedLong() throws {
    let typeString = "type.googleapis.com/google.protobuf.UInt64Value"
    let highULong = NSNumber(value: 18_446_744_073_709_551_607 as UInt64)
    let expected = ["@type": typeString, "value": "18446744073709551607"]
    let encoded = try serializer.encode(highULong) as? [String: String]
    XCTAssertEqual(encoded, expected)
  }

  func testDecodeUnsignedLong() throws {
    let highULong = NSNumber(value: 18_446_744_073_709_551_607 as UInt64)
    XCTAssertEqual(highULong, try serializer.decode(highULong) as? NSNumber)
  }

  func testDecodeUnsignedLongFromDictionary() throws {
    let typeString = "type.googleapis.com/google.protobuf.UInt64Value"
    let highULong = NSNumber(value: 18_446_744_073_709_551_607 as UInt64)
    let coded = ["@type": typeString, "value": "18446744073709551607"]
    let decoded = try serializer.decode(coded) as? NSNumber
    XCTAssertEqual(highULong, decoded)
    // A naive implementation might convert a number to a double and think that's close enough.
    // We need to make sure it's an unsigned long long for accuracy.
    XCTAssertEqual(decoded?.objCType[0], CChar("Q".utf8.first!))
  }

  func testDecodeUnsignedLongFromDictionaryOverflow() throws {
    let typeString = "type.googleapis.com/google.protobuf.UInt64Value"
    let tooHighVal = "18446744073709551616"
    let coded = ["@type": typeString, "value": tooHighVal]
    do {
      _ = try serializer.decode(coded) as? NSNumber
    } catch let FunctionsSerializer.Error.invalidValueForType(value, type) {
      XCTAssertEqual(value, tooHighVal)
      XCTAssertEqual(type, typeString)
      return
    }
    XCTFail()
  }

  func testEncodeDouble() throws {
    let myDouble = NSNumber(value: 1.2 as Double)
    XCTAssertEqual(myDouble, try serializer.encode(myDouble) as? NSNumber)
  }

  func testDecodeDouble() throws {
    let myDouble = NSNumber(value: 1.2 as Double)
    XCTAssertEqual(myDouble, try serializer.decode(myDouble) as? NSNumber)
  }

  func testEncodeBool() throws {
    XCTAssertEqual(true, try serializer.encode(true) as? NSNumber)
  }

  func testDecodeBool() throws {
    XCTAssertEqual(true, try serializer.decode(true) as? NSNumber)
  }

  func testEncodeString() throws {
    XCTAssertEqual("hello", try serializer.encode("hello") as? String)
  }

  func testDecodeString() throws {
    XCTAssertEqual("good-bye", try serializer.decode("good-bye") as? String)
  }

  // TODO: Should we add support for Array as well as NSArray?

  func testEncodeSimpleArray() throws {
    let input = [1 as Int32, 2 as Int32] as NSArray
    XCTAssertEqual(input, try serializer.encode(input) as? NSArray)
  }

  func testEncodeArray() throws {
    let input = [
      1 as Int32,
      "two",
      [3 as Int32, ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                    "value": "9876543210"]] as [Any],
    ] as NSArray
    XCTAssertEqual(input, try serializer.encode(input) as? NSArray)
  }

  func testEncodeArrayWithInvalidElements() {
    let input = ["TEST", CustomObject()] as NSArray

    try assert(serializer.encode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testDecodeArray() throws {
    let input = [
      1 as Int64,
      "two",
      [3 as Int32, ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                    "value": "9876543210"]] as [Any],
    ] as NSArray
    let expected = [1 as Int64, "two", [3 as Int32, 9_876_543_210 as Int64] as [Any]] as NSArray
    XCTAssertEqual(expected, try serializer.decode(input) as? NSArray)
  }

  func testDecodeArrayWithInvalidElements() {
    let input = ["TEST", CustomObject()] as NSArray

    try assert(serializer.decode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testEncodeDictionary() throws {
    let input = [
      "foo": 1 as Int32,
      "bar": "hello",
      "baz": [3 as Int32, 9_876_543_210 as Int64] as [Any],
    ] as NSDictionary
    let expected = [
      "foo": 1,
      "bar": "hello",
      "baz": [3, ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                  "value": "9876543210"]] as [Any],
    ] as NSDictionary
    XCTAssertEqual(expected, try serializer.encode(input) as? NSDictionary)
  }

  func testEncodeDictionaryWithInvalidElements() {
    let input = ["TEST_CustomObj": CustomObject()] as NSDictionary

    try assert(serializer.encode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testEncodeDictionaryWithInvalidNestedDictionary() {
    let input =
      ["TEST_NestedDict": ["TEST_CustomObj": CustomObject()] as NSDictionary] as NSDictionary

    try assert(serializer.encode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testDecodeDictionary() throws {
    let input = ["foo": 1, "bar": "hello", "baz": [3, 9_876_543_210]] as NSDictionary
    let expected = ["foo": 1, "bar": "hello", "baz": [3, 9_876_543_210]] as NSDictionary
    XCTAssertEqual(expected, try serializer.decode(input) as? NSDictionary)
  }

  func testDecodeDictionaryWithInvalidElements() {
    let input = ["TEST_CustomObj": CustomObject()] as NSDictionary

    try assert(serializer.decode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testDecodeDictionaryWithInvalidNestedDictionary() {
    let input =
      ["TEST_NestedDict": ["TEST_CustomObj": CustomObject()] as NSDictionary] as NSDictionary

    try assert(serializer.decode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testEncodeUnknownType() {
    let input = ["@type": "unknown", "value": "whatever"] as NSDictionary
    XCTAssertEqual(input, try serializer.encode(input) as? NSDictionary)
  }

  func testDecodeUnknownType() {
    let input = ["@type": "unknown", "value": "whatever"] as NSDictionary
    XCTAssertEqual(input, try serializer.decode(input) as? NSDictionary)
  }

  func testDecodeUnknownTypeWithoutValue() {
    let input = ["@type": "unknown"] as NSDictionary
    XCTAssertEqual(input, try serializer.decode(input) as? NSDictionary)
  }

  func testEncodeUnsupportedType() {
    let input = CustomObject()

    try assert(serializer.encode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }

  func testDecodeUnsupportedType() {
    let input = CustomObject()

    try assert(serializer.decode(input), throwsUnsupportedTypeErrorWithName: "CustomObject")
  }
}

// MARK: - Utilities

extension FunctionsSerializerTests {
  private func assert<T>(_ expression: @autoclosure () throws -> T,
                         throwsUnsupportedTypeErrorWithName expectedTypeName: String,
                         line: UInt = #line) {
    XCTAssertThrowsError(try expression(), line: line) { error in
      guard case let .unsupportedType(typeName: typeName) = error as? FunctionsSerializer
        .Error else {
        return XCTFail("Unexpected error: \(error)", line: line)
      }

      XCTAssertEqual(typeName, expectedTypeName, line: line)
    }
  }
}

/// Used to represent a type that cannot be encoded or decoded.
private class CustomObject {
  let id = 123
}
