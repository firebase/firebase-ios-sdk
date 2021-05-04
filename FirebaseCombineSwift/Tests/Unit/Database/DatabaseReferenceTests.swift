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

import Foundation
import Combine
import FirebaseDatabaseTestingSupport
import XCTest
@testable import FirebaseDatabaseCombineSwift

class DatabaseReferenceTests: XCTestCase {
  var cancellable: AnyCancellable?
  struct Model: Codable, Equatable {
    var a: String
    var b: Int
  }

  func testSetValueFuture() throws {
    let fake = DatabaseReferenceFake()
    let model = Model(a: "hello", b: 42)
    let future = fake.setValue(from: model)

    let valueExpectation = expectation(description: "Future sends void value")
    let completionExpectation = expectation(description: "Future completes")

    cancellable = future.sink { completion in
      completionExpectation.fulfill()
    } receiveValue: { _ in
      valueExpectation.fulfill()
    }

    wait(for: [completionExpectation, valueExpectation], timeout: 0.1)

    let decoder = Database.Decoder()
    let decoded = try decoder.decode(Model.self, from: fake.value as Any)
    XCTAssertEqual(decoded, model)
  }

  func testObserveSingleValue() throws {
    let fake = DatabaseReferenceFake()
    let model = Model(a: "hello", b: 42)
    try fake.setValue(from: model, completion: nil)

    let future = fake.observeSingleEvent(of: .value, as: Model.self)

    let valueExpectation = expectation(description: "Future sends value")
    let completionExpectation = expectation(description: "Future completes")

    cancellable = future.sink { completion in
      completionExpectation.fulfill()
    } receiveValue: { received in
      XCTAssertEqual(model, received)
      valueExpectation.fulfill()
    }

    wait(for: [completionExpectation, valueExpectation], timeout: 0.1)
  }

  func testObserve() throws {
    let fake = DatabaseReferenceFake()

    let publisher = fake.observe(.value, as: Model.self)

    let valueExpectation = expectation(description: "Future sends values")

    let models = [
      Model(a: "hello 1", b: 42),
      Model(a: "hello 2", b: 41),
      Model(a: "hello 3", b: 40),
    ]

    var expected = models
    cancellable = publisher.sink { _ in
      // No completion is expected
    } receiveValue: { received in
      let model = expected[0]
      XCTAssertEqual(model, received)
      expected.removeFirst()
      if expected.isEmpty {
        valueExpectation.fulfill()
      }
    }

    for model in models {
      try fake.setValue(from: model, completion: nil)
    }

    wait(for: [valueExpectation], timeout: 0.1)
  }

  func testObserveSnapshots() throws {
    let fake = DatabaseReferenceFake()

    let publisher = fake.snapshotPublisher(.value)

    let valueExpectation = expectation(description: "Future sends values")

    let models = [
      Model(a: "hello 1", b: 42),
      Model(a: "hello 2", b: 41),
      Model(a: "hello 3", b: 40),
    ]

    var expected = models
    cancellable = publisher.sink { _ in
      // No completion is expected
    } receiveValue: { snapshot in
      let model = expected[0]

      XCTAssert(snapshot.value is [String: Any])

      // Unpack value to test for equality
      let dict = snapshot.value as! [String: Any]
      XCTAssertEqual(dict["a"] as? String, model.a)
      XCTAssertEqual(dict["b"] as? Int, model.b)

      // And also test roundtripping
      let decoder = Database.Decoder()
      XCTAssertEqual(model, try! decoder.decode(Model.self, from: snapshot.value as Any))

      expected.removeFirst()
      if expected.isEmpty {
        valueExpectation.fulfill()
      }
    }

    for model in models {
      try fake.setValue(from: model, completion: nil)
    }

    wait(for: [valueExpectation], timeout: 0.1)
  }
}
