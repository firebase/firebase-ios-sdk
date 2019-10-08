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

import XCTest
import FirebaseInstallations
@testable import FirebaseCore

class FIRInstallationsInvalidConfigIntegrationTests: XCTestCase {

  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDown() {
    FirebaseApp.reset
  }

  func testInvalidFirebaseConfig() {
    assertGetIDSuccessThenFail()
  }

  func assertGetIDSuccessThenFail() {
    let getFIDExpectation1 = expectation(description: "getFIDExpectation1")
    Installations.installations().installationID { (FID, error) in
      XCTAssertNil(error)
      XCTAssertNotNil(FID)
      getFIDExpectation1.fulfill()
    }
    wait(for: [getFIDExpectation1], timeout: 10)

    let getFIDExpectation2 = expectation(description: "getFIDExpectation2")
    Installations.installations().installationID { (FID, error) in
      XCTAssertNotNil(error)
      XCTAssertNil(FID)
      getFIDExpectation2.fulfill()
    }

    wait(for: [getFIDExpectation2], timeout: 10)
  }

  func configureInvalidApp() {

  }

}
