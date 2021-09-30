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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseStorageSwift
import XCTest

class StorageIntegrationCommon: XCTestCase {
  var app: FirebaseApp!
  var auth: Auth!
  var storage: Storage!
  static var configured = false
  static var once = false
  static var signedIn = false

  override class func setUp() {
    if !StorageIntegrationCommon.configured {
      StorageIntegrationCommon.configured = true
      FirebaseApp.configure()
    }
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    auth = Auth.auth(app: app)
    storage = Storage.storage(app: app!)

    if !StorageIntegrationCommon.signedIn {
      signInAndWait()
    }

    if !StorageIntegrationCommon.once {
      StorageIntegrationCommon.once = true
      let setupExpectation = expectation(description: "setUp")

      let largeFiles = ["ios/public/1mb", "ios/public/1mb2"]
      let emptyFiles =
        ["ios/public/empty", "ios/public/list/a", "ios/public/list/b", "ios/public/list/prefix/c"]
      setupExpectation.expectedFulfillmentCount = largeFiles.count + emptyFiles.count

      do {
        let bundle = Bundle(for: StorageIntegrationCommon.self)
        let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                     "Failed to get filePath")
        let data = try XCTUnwrap(try Data(contentsOf: URL(fileURLWithPath: filePath)),
                                 "Failed to load file")

        for largeFile in largeFiles {
          let ref = storage.reference().child(largeFile)
          ref.putData(data) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        for emptyFile in emptyFiles {
          let ref = storage.reference().child(emptyFile)
          ref.putData(data) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        waitForExpectations()
      } catch {
        XCTFail("Error thrown setting up files in setUp")
      }
    }
  }

  override func tearDown() {
    app = nil
    storage = nil
    super.tearDown()
  }

  private func signInAndWait() {
    let expectation = self.expectation(description: #function)
    auth.signIn(withEmail: Credentials.kUserName,
                password: Credentials.kPassword) { result, error in
      XCTAssertNil(error)
      StorageIntegrationCommon.signedIn = true
      print("Successfully signed in")
      expectation.fulfill()
    }
    waitForExpectations()
  }

  private func waitForExpectations() {
    let kTestTimeout = 60.0
    waitForExpectations(timeout: kTestTimeout,
                        handler: { (error) -> Void in
                          if let error = error {
                            print(error)
                          }
                        })
  }

  private func assertResultSuccess<T>(_ result: Result<T, Error>,
                                      file: StaticString = #file, line: UInt = #line) {
    switch result {
    case let .success(value):
      XCTAssertNotNil(value, file: file, line: line)
    case let .failure(error):
      XCTFail("Unexpected error \(error)")
    }
  }
}
