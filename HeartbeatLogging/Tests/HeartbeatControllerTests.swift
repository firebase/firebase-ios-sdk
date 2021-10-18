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
@testable import HeartbeatLogging

class HeartbeatControllerTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the
    // invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the
    // invocation of each test method in the class.
  }

  // TODO: Add ObjC interop in the future.
  func testExample() throws {
    let (appID, userAgent) = ("AppID-123456789", "user_agent")
    let logger = HeartbeatController(id: appID)

    // Logging
    logger.log(userAgent)

    // Flushing
    let flushed: HeartbeatInfo? = logger.flush()
    _ /* flushedHeader */ = flushed?.headerValue()
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    measure {
      // Put the code you want to measure the time of here.
    }
  }
}
