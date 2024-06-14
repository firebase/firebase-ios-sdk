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

import FirebaseCore
@testable import FirebaseDataConnect
import Foundation

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class TimestampTests: XCTestCase {
  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testEncodingDecodingJSON() throws {
    try verifyEncodeDecodeRoundTrip(Timestamp(seconds: 0, nanoseconds: 0))
  }

  func testEncodingDecodingJSONwithNano() throws {
    try verifyEncodeDecodeRoundTrip(Timestamp(seconds: 130_804, nanoseconds: 642))
  }

  func testDecode() throws {
    try XCTAssertEqual(
      decodeTimestamp("2006-01-02T15:04:05-05:10"),
      decodeTimestamp("2006-01-02T09:54:05Z")
    )
  }

  func verifyEncodeDecodeRoundTrip(_ timestamp: Timestamp) throws {
    do {
      let jsonEncoder = JSONEncoder()
      let jsonData = try jsonEncoder.encode(timestamp)

      let jsonDecoder = JSONDecoder()
      let decodedTimestamp = try jsonDecoder.decode(Timestamp.self, from: jsonData)

      XCTAssertEqual(timestamp, decodedTimestamp)
    }
  }

  func decodeTimestamp(_ text: String) throws -> Timestamp {
    let jsonEncoder = JSONEncoder()
    let jsonData = try jsonEncoder.encode(text)

    let jsonDecoder = JSONDecoder()
    let decodedTimestamp = try jsonDecoder.decode(Timestamp.self, from: jsonData)
    return decodedTimestamp
  }
}
