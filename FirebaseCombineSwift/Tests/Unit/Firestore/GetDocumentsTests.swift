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

import Combine
import FirebaseCombineSwift
import FirebaseFirestoreTestingSupport
import Foundation
import XCTest

class GetDocumentsTests: XCTestCase {
  let expectationTimeout: TimeInterval = 2
  class MockQuery: QueryFake {
    var mockGetDocuments: () throws -> QuerySnapshot = {
      fatalError("You need to implement \(#function) in your mock.")
    }

    var verifySource: ((_ source: FirestoreSource) -> Void)?

    override func getDocuments(source: FirestoreSource,
                               completion: @escaping (QuerySnapshot?, Error?) -> Void) {
      do {
        verifySource?(source)
        let snapshot = try mockGetDocuments()
        completion(snapshot, nil)
      } catch {
        completion(nil, error)
      }
    }
  }

  override class func setUp() {
    FirebaseApp.configureForTests()
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { success in
      if success {
        print("Shut down app successfully.")
      } else {
        print("💥 There was a problem when shutting down the app..")
      }
    }
  }

  func testGetDocumentsFailure() {
    // given
    var cancellables = Set<AnyCancellable>()

    let getDocumentsWasCalledExpectation = expectation(description: "getDocuments was called")
    let getDocumentsFailureExpectation = expectation(description: "getDocuments failed")

    let query = MockQuery()
    let source: FirestoreSource = .server

    query.mockGetDocuments = {
      getDocumentsWasCalledExpectation.fulfill()
      throw NSError(domain: FirestoreErrorDomain,
                    code: FirestoreErrorCode.unknown.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Dummy Error"])
    }

    query.verifySource = {
      XCTAssertTrue(source == $0, "💥 Something went wrong: source changed")
    }

    // when
    query.getDocuments(source: source)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error as NSError):
          XCTAssertEqual(error.code, FirestoreErrorCode.unknown.rawValue)
          getDocumentsFailureExpectation.fulfill()
        }
      } receiveValue: { _ in
        XCTFail("💥 Something went wrong")
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [getDocumentsWasCalledExpectation, getDocumentsFailureExpectation],
      timeout: expectationTimeout
    )
  }
}
