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

class DatabaseReferenceTests: XCTestCase {
  struct Model: Codable, Equatable {
    var a: String
    var b: Int
  }

  func testSetValueEncodable() throws {
    let model = Model(a: "hello", b: 42)
    let fake = DatabaseReferenceFake()
    try fake.setValue(from: model)

    let decoder = Database.Decoder()
    let decoded = try decoder.decode(Model.self, from: fake.value as Any)
    XCTAssertEqual(decoded, model)
  }

  func testSetValueEncodableWithCompletion() throws {
    let model = Model(a: "hello", b: 42)
    let fake = DatabaseReferenceFake()

    let completionExpectation = expectation(description: "Completion called")

    try fake.setValue(from: model, completion: { error in
      XCTAssertNil(error)
      completionExpectation.fulfill()
    })

    wait(for: [completionExpectation], timeout: 0.5)

    let decoder = Database.Decoder()
    let decoded = try decoder.decode(Model.self, from: fake.value as Any)
    XCTAssertEqual(decoded, model)
  }
}
