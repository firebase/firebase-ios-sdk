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

class SerializerTests: XCTestCase {
  func testEncodeNull() throws {
    let serializer = FUNSerializer()
    let null = NSNull()
    XCTAssertEqual(try serializer.encode(null) as? NSNull, null)
  }

  func testDecodeNull() throws {
    let serializer = FUNSerializer()
    let null = NSNull()
    XCTAssertEqual(try serializer.decode(null) as? NSNull, null)
  }

  func testEncodeInt32() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.encode(one) as? NSNumber)
  }

  func testEncodeInt() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(1)
    let dict = try XCTUnwrap(try serializer.encode(one) as? NSDictionary)
    XCTAssertEqual("type.googleapis.com/google.protobuf.Int64Value", dict["@type"] as? String)
    XCTAssertEqual("1", dict["value"] as? String)
  }

  func testDecodeInt32() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  func testDecodeInt() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(1)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  func testDecodeIntFromDictionary() throws {
    let serializer = FUNSerializer()
    let dictOne = ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                   "value": "1"]
    XCTAssertEqual(NSNumber(1), try serializer.decode(dictOne) as? NSNumber)
  }

  func testEncodeLong() throws {
    let serializer = FUNSerializer()
    let lowLong = NSNumber(-9_223_372_036_854_775_800)
    let dict = try XCTUnwrap(try serializer.encode(lowLong) as? NSDictionary)
    XCTAssertEqual("type.googleapis.com/google.protobuf.Int64Value", dict["@type"] as? String)
    XCTAssertEqual("-9223372036854775800", dict["value"] as? String)
  }

  func testDecodeLong() throws {
    let serializer = FUNSerializer()
    let lowLong = NSNumber(-9_223_372_036_854_775_800)
    XCTAssertEqual(lowLong, try serializer.decode(lowLong) as? NSNumber)
  }

  func testDecodeLongFromDictionary() throws {
    let serializer = FUNSerializer()
    let dictLowLong = ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                       "value": "-9223372036854775800"]
    let decoded = try serializer.decode(dictLowLong) as? NSNumber
    XCTAssertEqual(NSNumber(-9_223_372_036_854_775_800), decoded)
    // A naive implementation might convert a number to a double and think that's close enough.
    // We need to make sure it's a long long for accuracy.
    XCTAssertEqual(decoded?.objCType[0], CChar("q".utf8.first!))
  }

  func testDecodeInvalidLong() throws {
    let serializer = FUNSerializer()
    let typeString = "type.googleapis.com/google.protobuf.Int64Value"
    let badVal = "-9223372036854775800 and some other junk"
    let dictLowLong = ["@type": typeString, "value": badVal]
    do {
      _ = try serializer.decode(dictLowLong) as? NSNumber
    } catch let SerializerError.invalidValueForType(value, type) {
      XCTAssertEqual(value, badVal)
      XCTAssertEqual(type, typeString)
      return
    }
    XCTFail()
  }

  func testEncodeUnsignedLong() throws {
    let serializer = FUNSerializer()
    let typeString = "type.googleapis.com/google.protobuf.UInt64Value"
    let highULong = NSNumber(value: 18_446_744_073_709_551_607 as UInt64)
    let expected = ["@type": typeString, "value": "18446744073709551607"]
    let encoded = try serializer.encode(highULong) as? [String: String]
    XCTAssertEqual(encoded, expected)
  }

  func testDecodeUnsignedLong() throws {
    let serializer = FUNSerializer()
    let highULong = NSNumber(value: 18_446_744_073_709_551_607 as UInt64)
    XCTAssertEqual(highULong, try serializer.decode(highULong) as? NSNumber)
  }

  func testDecodeUnsignedLongFromDictionary() throws {
    let serializer = FUNSerializer()
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
    let serializer = FUNSerializer()
    let typeString = "type.googleapis.com/google.protobuf.UInt64Value"
    let tooHighVal = "18446744073709551616"
    let coded = ["@type": typeString, "value": tooHighVal]
    do {
      _ = try serializer.decode(coded) as? NSNumber
    } catch let SerializerError.invalidValueForType(value, type) {
      XCTAssertEqual(value, tooHighVal)
      XCTAssertEqual(type, typeString)
      return
    }
    XCTFail()
  }

  func testEncodeDouble() throws {
    let serializer = FUNSerializer()
    let myDouble = NSNumber(value: 1.2 as Double)
    XCTAssertEqual(myDouble, try serializer.encode(myDouble) as? NSNumber)
  }

  func testDecodeDouble() throws {
    let serializer = FUNSerializer()
    let myDouble = NSNumber(value: 1.2 as Double)
    XCTAssertEqual(myDouble, try serializer.decode(myDouble) as? NSNumber)
  }

  func testEncodeBool() throws {
    let serializer = FUNSerializer()
    XCTAssertEqual(true, try serializer.encode(true) as? NSNumber)
  }

  func testDecodeBool() throws {
    let serializer = FUNSerializer()
    XCTAssertEqual(true, try serializer.decode(true) as? NSNumber)
  }

  func testEncodeString() throws {
    let serializer = FUNSerializer()
    XCTAssertEqual("hello", try serializer.encode("hello") as? String)
  }

  func testDecodeString() throws {
    let serializer = FUNSerializer()
    XCTAssertEqual("good-bye", try serializer.decode("good-bye") as? String)
  }

  // TODO: Should we add support for Array as well as NSArray?

  func testEncodeSimpleArray() throws {
    let serializer = FUNSerializer()
    let input = [1 as Int32, 2 as Int32] as NSArray
    XCTAssertEqual(input, try serializer.encode(input) as? NSArray)
  }

  func testEncodeArray() throws {
    let serializer = FUNSerializer()
    let input = [
      1 as Int32,
      "two",
      [3 as Int32, ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                    "value": "9876543210"]] as [Any],
    ] as NSArray
    XCTAssertEqual(input, try serializer.encode(input) as? NSArray)
  }

  func testDecodeArray() throws {
    let serializer = FUNSerializer()
    let input = [
      1 as Int64,
      "two",
      [3 as Int32, ["@type": "type.googleapis.com/google.protobuf.Int64Value",
                    "value": "9876543210"]] as [Any],
    ] as NSArray
    let expected = [1 as Int64, "two", [3 as Int32, 9_876_543_210 as Int64] as [Any]] as NSArray
    XCTAssertEqual(expected, try serializer.decode(input) as? NSArray)
  }

  func testEncodeMap() {
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
    let serializer = FUNSerializer()
    XCTAssertEqual(expected, try serializer.encode(input) as? NSDictionary)
  }

  func testDecodeMap() {
    let input = ["foo": 1, "bar": "hello", "baz": [3, 9_876_543_210]] as NSDictionary
    let expected = ["foo": 1, "bar": "hello", "baz": [3, 9_876_543_210]] as NSDictionary
    let serializer = FUNSerializer()
    XCTAssertEqual(expected, try serializer.decode(input) as? NSDictionary)
  }

  func testEncodeUnknownType() {
    let input = ["@type": "unknown", "value": "whatever"] as NSDictionary
    let serializer = FUNSerializer()
    XCTAssertEqual(input, try serializer.encode(input) as? NSDictionary)
  }

  func testDecodeUnknownType() {
    let input = ["@type": "unknown", "value": "whatever"] as NSDictionary
    let serializer = FUNSerializer()
    XCTAssertEqual(input, try serializer.decode(input) as? NSDictionary)
  }

  func testDecodeUnknownTypeWithoutValue() {
    let input = ["@type": "unknown"] as NSDictionary
    let serializer = FUNSerializer()
    XCTAssertEqual(input, try serializer.decode(input) as? NSDictionary)
  }

  // - (void)testDecodeUnknownTypeWithoutValue {
//  NSDictionary *input = @{
//    @"@type" : @"unknown",
//  };
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(input, [serializer decode:input error:&error]);
//  XCTAssertNil(error);
  // }
//
  // @end
}
