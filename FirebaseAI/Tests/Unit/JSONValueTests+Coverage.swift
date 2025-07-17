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

@testable import FirebaseAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValueTests {
  func testDecodeNestedObject() throws {
    let nestedObject: JSONObject = [
      "nestedKey": .string("nestedValue"),
    ]
    let expectedObject: JSONObject = [
      "numberKey": .number(numberValue),
      "objectKey": .object(nestedObject),
    ]
    let json = """
    {
      "numberKey": \(numberValue),
      "objectKey": {
        "nestedKey": "nestedValue"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .object(expectedObject))
  }

  func testDecodeNestedArray() throws {
    let nestedArray: [JSONValue] = [.string("a"), .string("b")]
    let expectedObject: JSONObject = [
      "numberKey": .number(numberValue),
      "arrayKey": .array(nestedArray),
    ]
    let json = """
    {
      "numberKey": \(numberValue),
      "arrayKey": ["a", "b"]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .object(expectedObject))
  }

  func testEncodeNestedObject() throws {
    let nestedObject: JSONObject = [
      "nestedKey": .string("nestedValue"),
    ]
    let objectValue: JSONObject = [
      "numberKey": .number(numberValue),
      "objectKey": .object(nestedObject),
    ]

    let jsonData = try encoder.encode(JSONValue.object(objectValue))
    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))
    XCTAssertEqual(jsonObject, .object(objectValue))
  }

  func testEncodeNestedArray() throws {
    let nestedArray: [JSONValue] = [.string("a"), .string("b")]
    let objectValue: JSONObject = [
      "numberKey": .number(numberValue),
      "arrayKey": .array(nestedArray),
    ]

    let jsonData = try encoder.encode(JSONValue.object(objectValue))
    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))
    XCTAssertEqual(jsonObject, .object(objectValue))
  }
}
