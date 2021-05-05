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
import XCTest
@testable import FirebaseStorage

class StorageReferenceTests: XCTestCase {
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

  var storage: Storage?

  override func setUp() {
    let app = FirebaseApp.appForStorageUnitTestsWithName(name: "App")
    storage = Storage.storage(app: app)
  }

  func testReferenceWithNonExistentFileFails() {
    // Given
    var cancellables = Set<AnyCancellable>()
    let putFileExpectation = expectation(description: "Put file expectation")

    let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let tempFilePath = tempFileURL.appendingPathComponent("temp.data").absoluteString

    let ref = storage?.reference(withPath: tempFilePath)

    let dummyFileURL = URL(fileURLWithPath: "some_non_existing-folder/file.data")

    // When
    ref?.putFile(from: dummyFileURL, metadata: nil)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          putFileExpectation.fulfill()

          XCTAssertEqual(error.domain, StorageErrorDomain)
          XCTAssertEqual(error.code, StorageErrorCode.unknown.rawValue)

          let expectedDescription =
            "File at URL: \(dummyFileURL.absoluteString) is not reachable. Ensure file URL is not" +
            " a directory, symbolic link, or invalid url."
          XCTAssertEqual(error.localizedDescription, expectedDescription)
        }
      } receiveValue: { metadata in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [putFileExpectation], timeout: expectationTimeout)
  }
}
