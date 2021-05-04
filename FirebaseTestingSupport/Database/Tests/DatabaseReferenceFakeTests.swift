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

class DatabaseReferenceFakeTests: XCTestCase {
  func testDatabaseReferenceFakeConstructor() throws {
    let fakeReference = DatabaseReferenceFake()
    XCTAssertNotNil(fakeReference)
    XCTAssertTrue(fakeReference.isKind(of: DatabaseReference.self))
  }

  func testDatabaseReferenceFakeSetValue() {
    let fakeReference = DatabaseReferenceFake()
    let value = "test"
    fakeReference.setValue(value)

    XCTAssertEqual(fakeReference.value as? String, value)
  }

  func testDatabaseReferenceFakeSetValueWithCompletion() {
    let fakeReference = DatabaseReferenceFake()
    let value = "test"

    let completionExpectation = expectation(description: "Completion called")
    fakeReference.setValue(value, withCompletionBlock: { error, reference in
      XCTAssertNil(error)
      XCTAssertEqual(reference, fakeReference)

      completionExpectation.fulfill()
    })

    wait(for: [completionExpectation], timeout: 0.1)

    XCTAssertEqual(fakeReference.value as? String, value)
  }
}
