// Copyright 2023 Google LLC
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
import XCTest

@testable import FirebaseAuth

/** @class SecureTokenRequestTests
    @brief Tests for @c SecureTokenRequest
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SecureTokenRequestTests: XCTestCase {
  let kAPIKey = "APIKey"
  let kEmulatorHostAndPort = "emulatorhost:12345"

  /** @fn testRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs.
   */
  func testRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = SecureTokenRequest.refreshRequest(refreshToken: "Token",
                                                    requestConfiguration: requestConfiguration)
    let expectedURL = "https://securetoken.googleapis.com/v1/token?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testRequestURLUseEmulator
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when using the emulator.
   */
  func testRequestURLUseEmulator() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = SecureTokenRequest.refreshRequest(refreshToken: "Token",
                                                    requestConfiguration: requestConfiguration)
    requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort
    let expectedURL =
      "http://\(kEmulatorHostAndPort)/securetoken.googleapis.com/v1/token?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }
}
