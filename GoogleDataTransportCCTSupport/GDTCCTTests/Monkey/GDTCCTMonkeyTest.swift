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

#if os(iOS)
  import GoogleDataTransportCCTSupport_iOS_TestApp
#elseif os(macOS)
  import GoogleDataTransportCCTSupport_macOS_TestApp
#elseif os(tvOS)
  import GoogleDataTransportCCTSupport_tvOS_TestApp
#endif

class GDTMonkeyTest: XCTestCase {
  func testGDTCCTAndFLL() {
    let viewController: ViewController? = Globals.SharedViewController
    XCTAssertNotNil(viewController)

    let expectation: XCTestExpectation = self.expectation(description: "Runs without crashing")
    viewController?.beginMonkeyTest {
      expectation.fulfill()
    }
    waitForExpectations(timeout: Globals.MonkeyTestLengthPlusBuffer, handler: nil)
  }
}
