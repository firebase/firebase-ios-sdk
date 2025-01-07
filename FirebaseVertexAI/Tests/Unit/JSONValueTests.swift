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
import XCTest

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class JSONValueTests: XCTestCase {
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()

  let numberKey = "pi"
  let numberValue = 3.14159
  let numberValueEncoded = "3.14159"
  let stringKey = "hello"
  let stringValue = "Hello, world!"

  override func setUp() {
    encoder.outputFormatting = .sortedKeys
  }

  func testDecodeNull() throws {
    let jsonData = try XCTUnwrap("null".data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .null)
  }

  func testDecodeNumber() throws {
    let jsonData = try XCTUnwrap("\(numberValue)".data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .number(numberValue))
  }

  func testDecodeString() throws {
    let jsonData = try XCTUnwrap("\"\(stringValue)\"".data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .string(stringValue))
  }

  func testDecodeBool() throws {
    let expectedBool = true
    let jsonData = try XCTUnwrap("\(expectedBool)".data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .bool(expectedBool))
  }

  func testDecodeObject() throws {
    let expectedObject: JSONObject = [
      numberKey: .number(numberValue),
      stringKey: .string(stringValue),
    ]
    let json = """
    {
      "\(numberKey)": \(numberValue),
      "\(stringKey)": "\(stringValue)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .object(expectedObject))
  }

  func testDecodeArray() throws {
    let expectedArray: [JSONValue] = [.null, .number(numberValue)]
    let jsonData = try XCTUnwrap("[ null, \(numberValue) ]".data(using: .utf8))

    let jsonObject = try XCTUnwrap(decoder.decode(JSONValue.self, from: jsonData))

    XCTAssertEqual(jsonObject, .array(expectedArray))
  }

  func testEncodeNull() throws {
    let jsonData = try encoder.encode(JSONValue.null)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, "null")
  }

  func testEncodeNumber() throws {
    let jsonData = try encoder.encode(JSONValue.number(numberValue))

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, "\(numberValue)")
  }

  func testEncodeString() throws {
    let jsonData = try encoder.encode(JSONValue.string(stringValue))

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, "\"\(stringValue)\"")
  }

  func testEncodeBool() throws {
    let boolValue = true

    let jsonData = try encoder.encode(JSONValue.bool(boolValue))

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, "\(boolValue)")
  }

  func testEncodeObject() throws {
    let objectValue: JSONObject = [
      numberKey: .number(numberValue),
      stringKey: .string(stringValue),
    ]

    let jsonData = try encoder.encode(JSONValue.object(objectValue))

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(
      json,
      "{\"\(stringKey)\":\"\(stringValue)\",\"\(numberKey)\":\(numberValueEncoded)}"
    )
  }

  func testEncodeArray() throws {
    let arrayValue: [JSONValue] = [.null, .number(numberValue)]

    let jsonData = try encoder.encode(JSONValue.array(arrayValue))

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, "[null,\(numberValueEncoded)]")
  }
}
