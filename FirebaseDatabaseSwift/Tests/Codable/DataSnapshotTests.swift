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

import FirebaseDatabase
import FirebaseDatabaseSwift
import FirebaseDatabaseTestingSupport
import Foundation
import XCTest

class DataSnapshotTests: XCTestCase {
  struct Model: Codable, Equatable {
    var a: String
    var b: Int
  }

  func testGetValue() throws {
    let fake = DataSnapshotFake()
    fake.fakeValue = ["a": "hello", "b": 42]

    let expected = Model(a: "hello", b: 42)

    let actual = try fake.data(as: Model.self)

    XCTAssertEqual(actual, expected)
  }

  // Test that if we ask for an `Optional`, then it's
  // still ok to decode an actual value
  func testGetValueOptional() throws {
    let fake = DataSnapshotFake()
    fake.fakeValue = ["a": "hello", "b": 42]

    let expected = Model(a: "hello", b: 42)

    let actual = try fake.data(as: Model?.self)

    XCTAssertEqual(actual, expected)
  }

  // Test that if we ask for an `Optional`, then it's
  // ok to decode a `nil` value
  func testGetNonExistingValueOptional() throws {
    let fake = DataSnapshotFake()
    fake.fakeValue = nil

    let actual = try fake.data(as: Model?.self)

    XCTAssertNil(actual)
  }

  // Test that if we do NOT ask for an `Optional`, then it's
  // an error
  func testGetNonExistingValueFailure() throws {
    let fake = DataSnapshotFake()
    fake.fakeValue = nil

    do {
      _ = try fake.data(as: Model.self)
    } catch let error as DecodingError {
      switch error {
      case let .valueNotFound(_, context):
        XCTAssertEqual(
          context.debugDescription,
          "Cannot get keyed decoding container -- found null value instead."
        )
      default:
        XCTFail("Unexpected error")
      }
    } catch {
      XCTFail("Unexpected error")
    }
  }
}
