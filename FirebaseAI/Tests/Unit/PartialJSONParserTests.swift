// Copyright 2025 Google LLC
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

import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class PartialJSONParserTests: XCTestCase {
  func testParseCompleteObject() {
    let json = #"{"key": "value", "num": 123}"#
    let parser = PartialJSONParser(input: json)
    let result = parser.parse()

    guard case let .object(obj) = result else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["key"], .string("value"))
    XCTAssertEqual(obj["num"], .number(123))
  }

  func testParsePartialString() {
    let json = #"{"key": "val"#
    let parser = PartialJSONParser(input: json)
    let result = parser.parse()

    guard case let .object(obj) = result else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["key"], .string("val"))
  }

  func testParsePartialArray() {
    let json = #"[1, 2, "#
    let parser = PartialJSONParser(input: json)
    let result = parser.parse()

    guard case let .array(arr) = result else {
      XCTFail("Expected array")
      return
    }
    XCTAssertEqual(arr.count, 2)
    XCTAssertEqual(arr[0], .number(1))
    XCTAssertEqual(arr[1], .number(2))
  }

  func testParsePartialNestedObject() {
    let json = #"{"outer": {"inner": "val"#
    let parser = PartialJSONParser(input: json)
    let result = parser.parse()

    guard case let .object(obj) = result,
          case let .object(inner) = obj["outer"] else {
      XCTFail("Expected nested object")
      return
    }
    XCTAssertEqual(inner["inner"], .string("val"))
  }

  func testParseEmpty() {
    let parser = PartialJSONParser(input: "")
    XCTAssertNil(parser.parse())
  }

  func testParseOnlyOpenBrace() {
    let parser = PartialJSONParser(input: "{")
    guard case let .object(obj) = parser.parse() else {
      XCTFail()
      return
    }
    XCTAssertTrue(obj.isEmpty)
  }

  func testParsePartialKey() {
    let json = #"{"ke"#
    let parser = PartialJSONParser(input: json)
    // "ke" is parsed as string key, but no colon.
    // So key is ignored.
    guard case let .object(obj) = parser.parse() else {
      XCTFail()
      return
    }
    XCTAssertTrue(obj.isEmpty)
  }

  func testParsePartialKeyWithColon() {
    let json = #"{"key":"#
    let parser = PartialJSONParser(input: json)
    // "key" parsed, colon parsed.
    // parseValue called on EOF -> returns nil.
    // Key ignored.
    guard case let .object(obj) = parser.parse() else {
      XCTFail()
      return
    }
    XCTAssertTrue(obj.isEmpty)
  }
}
