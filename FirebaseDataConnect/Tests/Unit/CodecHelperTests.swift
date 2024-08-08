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

import Foundation
import XCTest

@testable import FirebaseDataConnect

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class CodecHelperTests: XCTestCase {
  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testNoDashUUIDString() throws {
    let uuidStr = "B7ACD615-1140-48F6-A522-26260D5C9367"
    let uuid = UUID(uuidString: uuidStr)

    // lowercase this for test since the UUID class converts uuid to lowercase
    let uuidNoDashStr = "B7ACD615114048F6A52226260D5C9367".lowercased()

    let uuidConverter = UUIDCodableConverter()
    let convertedUuid = try uuidConverter.encode(input: uuid)

    XCTAssertEqual(convertedUuid, uuidNoDashStr)
  }

  func testConvertToSystemUUIDType() throws {
    let uuidStr = "B7ACD615-1140-48F6-A522-26260D5C9367"
    let uuid = UUID(uuidString: uuidStr)

    let uuidNoDashStr = "B7ACD615114048F6A52226260D5C9367"

    let uuidConverter = UUIDCodableConverter()
    let uuidConverted = try uuidConverter.decode(input: uuidNoDashStr)

    XCTAssertEqual(uuid, uuidConverted)
  }

  func testConvertUUIDToNil() throws {
    let uuidConverter = UUIDCodableConverter()
    let uuid: UUID? = nil
    let uuidString = try uuidConverter.encode(input: uuid)

    XCTAssertNil(uuidString)
  }

  func testConvertUUIDFromNil() throws {
    let uuidConverter = UUIDCodableConverter()
    let uuidString: String? = nil
    let uuid: UUID? = try uuidConverter.decode(input: uuidString)
    XCTAssertNil(uuid)
  }

  func testInt64ToString() throws {
    let int64Converter = Int64CodableConverter()
    let int64Val: Int64 = 9_223_372_036_854_775_807
    let expectedVal = "9223372036854775807"

    let convertedVal = try int64Converter.encode(input: int64Val)
    XCTAssertEqual(convertedVal, expectedVal)
  }

  func testStringToInt64() throws {
    let int64Converter = Int64CodableConverter()
    let expectedVal: Int64 = 9_223_372_036_854_775_807
    let stringVal = "9223372036854775807"

    let convertedVal = try int64Converter.decode(input: stringVal)
    XCTAssertEqual(convertedVal, expectedVal)
  }

  func testCodecHelper() throws {
    let codecVals = TestCodecValues()

    let jsonEncoder = JSONEncoder()
    let jsonData = try jsonEncoder.encode(codecVals)

    let jsonDecoder = JSONDecoder()
    let codecValsDecoded = try jsonDecoder.decode(TestCodecValues.self, from: jsonData)

    XCTAssertEqual(codecVals, codecValsDecoded)
  }

  struct TestCodecValues: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
      case largeVal
      case uuidVal
    }

    var largeVal: Int64 = 9_223_372_036_854_775_807
    var uuidVal: UUID = .init()

    init() {}

    init(from decoder: any Decoder) throws {
      var container = try decoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      largeVal = try codecHelper.decode(Int64.self, forKey: .largeVal, container: &container)
      uuidVal = try codecHelper.decode(UUID.self, forKey: .uuidVal, container: &container)
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(largeVal, forKey: .largeVal, container: &container)
      try codecHelper.encode(uuidVal, forKey: .uuidVal, container: &container)
    }
  }
}
