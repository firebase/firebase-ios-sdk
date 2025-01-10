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

class RemoteConfigValueOrigTests: XCTestCase {
  func testConfigValueWithDifferentValueTypes() throws {
    let valueA = "0.33333"
    let dataA = try XCTUnwrap(valueA.data(using: .utf8))

    let configValueA = RemoteConfigValue(data: dataA, source: .remote)
    XCTAssertEqual(configValueA.stringValue, valueA)
    XCTAssertEqual(configValueA.dataValue, dataA)
    XCTAssertEqual(
      configValueA.numberValue,
      NSNumber(floatLiteral: 0.33333)
    )
    XCTAssertEqual(configValueA.boolValue, (valueA as NSString).boolValue)

    let valueB = "NO"
    let dataB = try XCTUnwrap(valueB.data(using: .utf8))
    let configValueB = RemoteConfigValue(data: dataB, source: .remote)
    XCTAssertEqual(configValueB.boolValue, (valueB as NSString).boolValue)

    // Test JSON value.
    let jsonDictionary = ["key1": "value1"]
    let jsonArray = [["key1": "value1"], ["key2": "value2"]]

    let jsonData = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
    let configValueC = RemoteConfigValue(data: jsonData, source: .remote)
    XCTAssertEqual(configValueC.jsonValue as? [String: String], jsonDictionary)

    let jsonArrayData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])
    let configValueD = RemoteConfigValue(data: jsonArrayData, source: .remote)
    XCTAssertEqual(configValueD.jsonValue as? [[String: String]], jsonArray)
  }

  func testConfigValueToNumber() throws {
    let strValue1 = "0.33"
    let data1 = try XCTUnwrap(strValue1.data(using: .utf8))
    let value1 = RemoteConfigValue(data: data1, source: .remote)
    XCTAssertEqual(value1.numberValue.floatValue, Float(strValue1)!)

    let strValue2 = "3.14159265358979"
    let data2 = try XCTUnwrap(strValue2.data(using: .utf8))
    let value2 = RemoteConfigValue(data: data2, source: .remote)
    XCTAssertEqual(value2.numberValue.doubleValue, Double(strValue2)!)

    let strValue3 = "1000000000"
    let data3 = try XCTUnwrap(strValue3.data(using: .utf8))
    let value3 = RemoteConfigValue(data: data3, source: .remote)

    XCTAssertEqual(value3.numberValue.intValue, Int(strValue3)!)

    let strValue4 = "1000000000123"
    let data4 = try XCTUnwrap(strValue4.data(using: .utf8))
    let value4 = RemoteConfigValue(data: data4, source: .remote)
    XCTAssertEqual(value4.numberValue.int64Value, Int64(strValue4)!)
  }
}
