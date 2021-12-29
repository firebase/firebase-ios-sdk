// Copyright 2021 Google LLC
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

import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift

import XCTest

/// String constants used for testing.
private enum Constants {
  static let stringKey = "myString"
  static let stringValue = "string contents"
  static let intKey = "myInt"
  static let intValue = 123
  static let floatKey = "myFloat"
  static let floatValue = 42.75 as Float
  static let doubleValue = 42.75
  static let trueKey = "myTrue"
  static let falseKey = "myFalse"
  static let jsonKey = "Recipe"
  static let jsonValue = ["recipeName": "PB&J",
                          "ingredients": ["bread", "peanut butter", "jelly"],
                          "cookTime": 7] as [String: AnyHashable]
}

#if compiler(>=5.5) && canImport(_Concurrency)
  @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
  class ValueTests: APITestBase {
    var console: RemoteConfigConsole!

    override func setUpWithError() throws {
      try super.setUpWithError()
      if APITests.useFakeConfig {
        let jsonData = try JSONSerialization.data(
          withJSONObject: Constants.jsonValue
        )
        guard let jsonValue = String(data: jsonData, encoding: .ascii) else {
          fatalError("Failed to make json Value from jsonData")
        }
        fakeConsole.config = [Constants.stringKey: Constants.stringValue,
                              Constants.intKey: String(Constants.intValue),
                              Constants.floatKey: String(Constants.floatValue),
                              Constants.trueKey: String(true),
                              Constants.falseKey: String(false),
                              Constants.jsonKey: jsonValue]
      }
    }

    func testFetchAndActivateAllTypes() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      XCTAssertEqual(config[Constants.stringKey].stringValue, Constants.stringValue)
      XCTAssertEqual(config[Constants.intKey].numberValue.intValue, Constants.intValue)
      XCTAssertEqual(config[Constants.intKey].numberValue.int8Value, Int8(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.int16Value, Int16(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.int32Value, Int32(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.int64Value, Int64(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.uintValue, UInt(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.uint8Value, UInt8(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.uint16Value, UInt16(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.uint32Value, UInt32(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.uint64Value, UInt64(Constants.intValue))
      XCTAssertEqual(config[Constants.intKey].numberValue.decimalValue, Decimal(Constants.intValue))
      XCTAssertEqual(config[Constants.floatKey].numberValue.floatValue, Constants.floatValue)
      XCTAssertEqual(config[Constants.floatKey].numberValue.doubleValue, Constants.doubleValue)
      XCTAssertEqual(config[Constants.trueKey].boolValue, true)
      XCTAssertEqual(config[Constants.falseKey].boolValue, false)
      XCTAssertEqual(
        config[Constants.jsonKey].jsonValue as! [String: AnyHashable],
        Constants.jsonValue
      )
    }

    func testStrongTyping() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      XCTAssertEqual(config[stringValue: Constants.stringKey], Constants.stringValue)
      XCTAssertEqual(config[intValue: Constants.intKey], Constants.intValue)
      XCTAssertEqual(config[int8Value: Constants.intKey], Int8(Constants.intValue))
      XCTAssertEqual(config[int16Value: Constants.intKey], Int16(Constants.intValue))
      XCTAssertEqual(config[int32Value: Constants.intKey], Int32(Constants.intValue))
      XCTAssertEqual(config[int64Value: Constants.intKey], Int64(Constants.intValue))
      XCTAssertEqual(config[uintValue: Constants.intKey], UInt(Constants.intValue))
      XCTAssertEqual(config[uint8Value: Constants.intKey], UInt8(Constants.intValue))
      XCTAssertEqual(config[uint16Value: Constants.intKey], UInt16(Constants.intValue))
      XCTAssertEqual(config[uint32Value: Constants.intKey], UInt32(Constants.intValue))
      XCTAssertEqual(config[uint64Value: Constants.intKey], UInt64(Constants.intValue))
      XCTAssertEqual(config[decimalValue: Constants.intKey], Decimal(Constants.intValue))
      XCTAssertEqual(config[floatValue: Constants.floatKey], Constants.floatValue)
      XCTAssertEqual(config[doubleValue: Constants.floatKey], Constants.doubleValue)
      XCTAssertEqual(config[boolValue: Constants.trueKey], true)
      XCTAssertEqual(config[boolValue: Constants.falseKey], false)
      XCTAssertEqual(try XCTUnwrap(config[jsonValue: Constants.jsonKey]), Constants.jsonValue)
    }

    func testStringFails() {
      XCTAssertEqual(config[stringValue: "UndefinedKey"], "")
    }

    func testJSONFails() {
      XCTAssertNil(config[jsonValue: "UndefinedKey"])
      XCTAssertNil(config[jsonValue: Constants.stringKey])
    }
  }
#endif
