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

#if compiler(>=5.5) && canImport(_Concurrency)
  @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
  class ValueTests: APITestBase {
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
      XCTAssertEqual(
        config[Constants.floatKey].numberValue.decimalValue,
        Decimal(Constants.doubleValue)
      )
      XCTAssertEqual(config[Constants.floatKey].numberValue.floatValue, Constants.floatValue)
      XCTAssertEqual(config[Constants.floatKey].numberValue.doubleValue, Constants.doubleValue)
      XCTAssertEqual(config[Constants.trueKey].boolValue, true)
      XCTAssertEqual(config[Constants.falseKey].boolValue, false)
      XCTAssertEqual(
        config[Constants.stringKey].dataValue,
        Constants.stringValue.data(using: .utf8)
      )
      XCTAssertEqual(
        config[Constants.jsonKey].jsonValue as! [String: AnyHashable],
        Constants.jsonValue
      )
    }

    func testStrongTypingViaSubscriptApi() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      XCTAssertEqual(config[decodedValue: Constants.stringKey], Constants.stringValue)
      XCTAssertEqual(config[decodedValue: Constants.intKey], Constants.intValue)
      XCTAssertEqual(config[decodedValue: Constants.floatKey], Constants.floatValue)
      XCTAssertEqual(config[decodedValue: Constants.floatKey], Constants.doubleValue)
      XCTAssertEqual(config[decodedValue: Constants.trueKey], true)
      XCTAssertEqual(config[decodedValue: Constants.falseKey], false)
      XCTAssertEqual(
        config[decodedValue: Constants.stringKey],
        Constants.stringValue.data(using: .utf8)
      )
      XCTAssertEqual(try XCTUnwrap(config[jsonValue: Constants.jsonKey]), Constants.jsonValue)
    }

    func testStrongTypingViaDecoder() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      XCTAssertEqual(
        try config[Constants.stringKey].decoded(asType: String.self),
        Constants.stringValue
      )
      XCTAssertEqual(try config[Constants.intKey].decoded(asType: Int.self), Constants.intValue)
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: Int8.self),
        Int8(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: Int16.self),
        Int16(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: Int32.self),
        Int32(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: Int64.self),
        Int64(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: UInt.self),
        UInt(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: UInt8.self),
        UInt8(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: UInt16.self),
        UInt16(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: UInt32.self),
        UInt32(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.intKey].decoded(asType: UInt64.self),
        UInt64(Constants.intValue)
      )
      XCTAssertEqual(
        try config[Constants.floatKey].decoded(asType: Decimal.self),
        Decimal(Constants.doubleValue)
      )
      XCTAssertEqual(
        try config[Constants.floatKey].decoded(asType: Float.self),
        Constants.floatValue
      )
      XCTAssertEqual(
        try config[Constants.floatKey].decoded(asType: Double.self),
        Constants.doubleValue
      )
      XCTAssertEqual(try config[Constants.trueKey].decoded(asType: Bool.self), true)
      XCTAssertEqual(try config[Constants.falseKey].decoded(asType: Bool.self), false)
      XCTAssertEqual(
        try config[Constants.stringKey].decoded(asType: Data.self),
        Constants.stringValue.data(using: .utf8)
      )
    }

    func testStrongTypingViaDecoderAlternateDecoderApi() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let myString: String = try config[Constants.stringKey].decoded()
      XCTAssertEqual(myString, Constants.stringValue)
      let myInt: Int = try config[Constants.intKey].decoded()
      XCTAssertEqual(myInt, Constants.intValue)
      let myInt8: Int8 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myInt8, Int8(Constants.intValue))
      let myInt16: Int16 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myInt16, Int16(Constants.intValue))
      let myInt32: Int32 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myInt32, Int32(Constants.intValue))
      let myInt64: Int64 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myInt64, Int64(Constants.intValue))
      let myUInt: UInt = try config[Constants.intKey].decoded()
      XCTAssertEqual(myUInt, UInt(Constants.intValue))
      let myUInt8: UInt8 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myUInt8, UInt8(Constants.intValue))
      let myUInt16: UInt16 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myUInt16, UInt16(Constants.intValue))
      let myUInt32: UInt32 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myUInt32, UInt32(Constants.intValue))
      let myUInt64: UInt64 = try config[Constants.intKey].decoded()
      XCTAssertEqual(myUInt64, UInt64(Constants.intValue))
      let myDecimal: Decimal = try config[Constants.floatKey].decoded()
      XCTAssertEqual(myDecimal, Decimal(Constants.doubleValue))
      let myFloat: Float = try config[Constants.floatKey].decoded()
      XCTAssertEqual(myFloat, Constants.floatValue)
      let myDouble: Double = try config[Constants.floatKey].decoded()
      XCTAssertEqual(myDouble, Constants.doubleValue)
      let myTrue: Bool = try config[Constants.trueKey].decoded()
      XCTAssertEqual(myTrue, true)
      let myFalse: Bool = try config[Constants.falseKey].decoded()
      XCTAssertEqual(myFalse, false)
      let myData: Data = try config[Constants.stringKey].decoded()
      XCTAssertEqual(myData, Constants.stringValue.data(using: .utf8))
    }

    func testStringFails() {
      XCTAssertEqual(config[decodedValue: "UndefinedKey"], "")
    }

    func testJSONFails() {
      XCTAssertNil(config[jsonValue: "UndefinedKey"])
      XCTAssertNil(config[jsonValue: Constants.stringKey])
    }

    func testDateDecodingNotYetSupported() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      do {
        let _: Date = try config[Constants.stringKey].decoded()
      } catch let RemoteConfigValueCodableError.unsupportedType(message) {
        XCTAssertEqual(message,
                       "Date type is not currently supported for  Remote Config Value decoding. " +
                         "Please file a feature request")
        return
      }
      XCTFail("Failed to throw unsupported Date error.")
    }
  }
#endif
