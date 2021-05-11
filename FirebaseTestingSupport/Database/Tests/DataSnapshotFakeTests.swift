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

import XCTest
@testable import FirebaseDatabaseTestingSupport

class DataSnapshotFakeTests: XCTestCase {
  func testDataSnapshotFakeConstructor() throws {
    let fakeSnapshot = DataSnapshotFake()
    XCTAssertNotNil(fakeSnapshot)
    XCTAssertTrue(fakeSnapshot.isKind(of: DataSnapshot.self))
  }

  func testDataSnapshotFakeGetSetValue() {
    let fakeSnapshot = DataSnapshotFake()
    let value = "test"
    fakeSnapshot.fakeValue = value

    XCTAssertEqual(fakeSnapshot.value as? String, value)
  }
}
