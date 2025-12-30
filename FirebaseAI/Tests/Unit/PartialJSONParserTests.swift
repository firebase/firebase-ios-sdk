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

  func testParseEscapedQuote() {
    let json = #"{"key": "hello \"world\""}"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["key"], .string("hello \"world\""))
  }

  func testParseEscapeSequences() {
    let json = #"{"key": "line\nbreak\ttab\\slash"}"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["key"], .string("line\nbreak\ttab\\slash"))
  }

  func testParsePrimitives() {
    let json = #"{"b": true, "f": false, "n": null}"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["b"], .bool(true))
    XCTAssertEqual(obj["f"], .bool(false))
    XCTAssertEqual(obj["n"], .null)
  }

  func testParsePartialNumbers() {
    // Parser returns nil for partial numbers, so key is ignored
    let json = #"{"a": 12, "b": -"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["a"], .number(12))
    XCTAssertNil(obj["b"])
  }

  func testParsePartialUnicode() {
    // Incomplete unicode \u12 should result in partial string "\u" plus the following chars
    // The parser consumes \u, sees it's incomplete, appends \\u, then continues parsing 1 and 2 as
    // literals.
    let json = #"{"key": "\u12"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["key"], .string("\\u12"))
  }

  func testParseTrailingCommas() {
    let json = #"{"a": 1, }"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["a"], .number(1))
  }

  func testParseEmptyStructures() {
    let json = #"{"a": [], "b": {}}"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse() else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(obj["a"], .array([]))
    XCTAssertEqual(obj["b"], .object([:]))
  }

  func testParseComplexNestedPartial() {
    let json = #"{"arr": [1, {"nested": "v"#
    let parser = PartialJSONParser(input: json)
    guard case let .object(obj) = parser.parse(),
          case let .array(arr) = obj["arr"],
          arr.count == 2,
          case let .object(nested) = arr[1] else {
      XCTFail("Expected nested structure")
      return
    }
    XCTAssertEqual(arr[0], .number(1))
    XCTAssertEqual(nested["nested"], .string("v"))
  }

  func testParseNumberBacktracking() {
    // "1.2.3" should parse as 1.2, leaving ".3" (which might be ignored or handled next)
    // The parser consumes as much as possible, then backtracks.
    // "1.2.3" -> consumes all, fails Double("1.2.3").
    // Backtracks to "1.2." -> fail.
    // Backtracks to "1.2" -> success.
    // Remaining input ".3" will likely fail to parse as anything valid next, but the number 1.2
    // should be
    // extracted.
    let json = #"[1.2.3]"#
    let parser = PartialJSONParser(input: json)
    guard case let .array(arr) = parser.parse() else {
      XCTFail("Expected array")
      return
    }
    XCTAssertEqual(arr.count, 1)
    XCTAssertEqual(arr[0], .number(1.2))
  }
}
