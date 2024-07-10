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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SecureTokenTests: RPCBaseTests {
  private let kEmulatorHostAndPort = "emulatorhost:12345"

  /** @fn testRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs.
   */
  func testRequestURL() throws {
    let kExpectedAPIURL = "https://securetoken.googleapis.com/v1/token?key=\(kTestAPIKey)"
    let request = makeSecureTokenRequest()
    XCTAssertEqual(request.requestURL().absoluteString, kExpectedAPIURL)
  }

  /** @fn testRequestURLUseEmulator
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when using the emulator.
   */
  func testRequestURLUseEmulator() throws {
    let kExpectedAPIURL =
      "http://\(kEmulatorHostAndPort)/securetoken.googleapis.com/v1/token?key=\(kTestAPIKey)"
    let request = makeSecureTokenRequest(useEmulator: true)
    XCTAssertEqual(request.requestURL().absoluteString, kExpectedAPIURL)
  }

  private func makeSecureTokenRequest(useEmulator: Bool = false) -> SecureTokenRequest {
    let requestConfiguration = makeRequestConfiguration()
    if useEmulator {
      requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort
    }
    return SecureTokenRequest.refreshRequest(refreshToken: kRefreshToken,
                                             requestConfiguration: requestConfiguration)
  }
}
