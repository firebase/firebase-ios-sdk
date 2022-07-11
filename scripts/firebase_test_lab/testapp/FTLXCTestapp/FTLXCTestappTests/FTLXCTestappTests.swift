/*
 * Copyright 2022 Google LLC
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
@testable import FTLXCTestapp

class FTLXCTestappTests: XCTestCase {
  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testExample() throws {
    XCTAssert(true)
  }

  func testFailedExample() throws {
    // Set the test to fail intentionally to test failed test cases on FTL.
    XCTAssert(false)
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    measure {
      sleep(5)
      // Put the code you want to measure the time of here.
    }
  }
}
