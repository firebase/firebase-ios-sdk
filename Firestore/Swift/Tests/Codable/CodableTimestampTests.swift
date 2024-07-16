/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import class FirebaseCore.Timestamp
import FirebaseFirestore
import Foundation
import XCTest

class CodableTimestampTests: XCTestCase {
  func testTimestampEncodes() {
    let timestamp = Timestamp(seconds: 37, nanoseconds: 123)

    do {
      let jsonData = try JSONEncoder().encode(timestamp)
      let json = String(data: jsonData, encoding: .utf8)!

      // The ordering of attributes in the JSON output is not guaranteed, so just verify that
      // each required property is present.
      XCTAssert(json.contains("\"seconds\":37"))
      XCTAssert(json.contains("\"nanoseconds\":123"))
    } catch {
      XCTFail("Error: \(error)")
    }
  }

  func testTimestampDecodes() {
    let json = """
    {
      "seconds": 37,
      "nanoseconds": 122
    }
    """
    let jsonData: Data = json.data(using: .utf8)!

    let timestamp = try! JSONDecoder().decode(Timestamp.self, from: jsonData)
    XCTAssertEqual(37, timestamp.seconds)
    XCTAssertEqual(122, timestamp.nanoseconds)
  }
}
