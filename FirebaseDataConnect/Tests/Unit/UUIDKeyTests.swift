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

import FirebaseDataConnect
import Foundation

final class UUIDKeyTests: XCTestCase {
  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testConversionToUUID() throws {
    let uuidString = "f9a1061f-97a6-4557-b755-774b5f5d1ff6"
    let originalUUID = UUID(uuidString: uuidString)

    let uuidKeyString = "f9a1061f97a64557b755774b5f5d1ff6"
    let uuidKey = UUIDKey(uuidKeyString: uuidKeyString)

    if let originalUUID,
       let uuidKey {
      XCTAssertEqual(uuidKey.id, originalUUID)
    } else {
      XCTFail("UUIDs failed to initialize \(originalUUID) \(uuidKey)")
    }
  }

  func testJSONCodec() throws {
    let uuidKeyString = "f9a1061f97a64557b755774b5f5d1ff6"
    let uuidKey = UUIDKey(uuidKeyString: uuidKeyString)

    let jsonEnc = JSONEncoder()
    let data = try jsonEnc.encode(uuidKey)

    let jsonDec = JSONDecoder()
    let decKey = try jsonDec.decode(UUIDKey.self, from: data)

    XCTAssertEqual(uuidKey, decKey)
  }
}
