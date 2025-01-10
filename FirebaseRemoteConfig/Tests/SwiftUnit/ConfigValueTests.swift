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

@testable import FirebaseRemoteConfig
import XCTest

class RemoteConfigValueTests: XCTestCase {
  func testStringValue_validUTF8Data() throws {
    // Given
    let data = try XCTUnwrap("test string".data(using: .utf8))
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let stringValue = configValue.stringValue
    // Then
    XCTAssertEqual(stringValue, "test string")
  }

  func testStringValue_invalidUTF8Data() {
    // Given
    let data = Data([0xFA, 0xDE, 0xD0, 0x0D]) // Invalid UTF-8
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let stringValue = configValue.stringValue
    // Then
    XCTAssertEqual(stringValue, "")
  }

  func testStringValue_nilData() {
    // Given
    let configValue = RemoteConfigValue(data: nil, source: .remote)
    // When
    let stringValue = configValue.stringValue
    // Then
    XCTAssertEqual(stringValue, "")
  }

  func testStringValue_emptyData() {
    // Given
    let configValue = RemoteConfigValue(data: Data(), source: .remote)
    // When
    let stringValue = configValue.stringValue
    // Then
    XCTAssertEqual(stringValue, "")
  }

  func testNumberValue_validDoubleString() throws {
    // Given
    let data = try XCTUnwrap("123.45".data(using: .utf8))
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let numberValue = configValue.numberValue
    // Then
    XCTAssertEqual(numberValue, 123.45)
  }

  func testNumberValue_invalidDoubleString() throws {
    // Given
    let data = try XCTUnwrap("not a number".data(using: .utf8))
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let numberValue = configValue.numberValue
    // Then
    XCTAssertEqual(numberValue, 0)
  }

  func testNumberValue_emptyData() {
    // Given
    let configValue = RemoteConfigValue(data: nil, source: .remote)
    // When
    let numberValue = configValue.numberValue
    // Then
    XCTAssertEqual(numberValue, 0)
  }

  func testBoolValue_trueValues() throws {
    // Given
    let trueStrings = ["true", "TRUE", "1", "yes", "YES", "y", "Y"]
    for str in trueStrings {
      // When
      let data = try XCTUnwrap(str.data(using: .utf8))
      let configValue = RemoteConfigValue(data: data, source: .remote)
      // Then
      XCTAssertTrue(configValue.boolValue)
    }
  }

  func testBoolValue_falseValues() throws {
    // Given
    let falseStrings = ["false", "FALSE", "0", "no", "NO", "n", "N", "other"]

    for str in falseStrings {
      // When, Then (combined in loop)
      let data = try XCTUnwrap(str.data(using: .utf8))
      let configValue = RemoteConfigValue(data: data, source: .remote)
      XCTAssertFalse(configValue.boolValue)
    }
  }

  func testBoolValue_emptyData() {
    // Given
    let configValue = RemoteConfigValue(data: nil, source: .remote)
    // When
    let boolValue = configValue.boolValue
    // Then
    XCTAssertFalse(boolValue)
  }

  func testJsonValue_validJSON() throws {
    // Given
    let dict = ["key": "value"]
    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let jsonValue = configValue.jsonValue
    // Then
    XCTAssertEqual(jsonValue as? [String: String], dict)
  }

  func testJsonValue_invalidJSON() throws {
    // Given
    let data = try XCTUnwrap("invalid json".data(using: .utf8)) // Invalid JSON
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let jsonValue = configValue.jsonValue
    // Then
    XCTAssertNil(jsonValue)
  }

  func testJsonValue_emptyData() {
    // Given
    let configValue = RemoteConfigValue(data: nil, source: .remote)
    // When
    let jsonValue = configValue.jsonValue
    // Then
    XCTAssertNil(jsonValue)
  }

  func testCopy() throws {
    // Given
    let data = try XCTUnwrap("test".data(using: .utf8))
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let copiedValue = configValue.copy(with: nil) as! RemoteConfigValue
    // Then
    XCTAssertEqual(configValue.dataValue, copiedValue.dataValue)
    XCTAssertEqual(configValue.source, copiedValue.source)
    XCTAssertEqual(configValue.stringValue, copiedValue.stringValue)
  }

  func testDebugDescription() throws {
    // Given
    let data = try XCTUnwrap("test".data(using: .utf8))
    let configValue = RemoteConfigValue(data: data, source: .remote)
    // When
    let debugDescription = configValue.debugDescription
    // Then
    let expectedPrefix = "<RemoteConfigValue: "
    XCTAssertTrue(debugDescription.hasPrefix(expectedPrefix))
    XCTAssertTrue(debugDescription.contains("String: test"))
    XCTAssertTrue(debugDescription.contains("Boolean: true"))
    XCTAssertTrue(debugDescription.contains("Source: 0"))
  }
}
