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
class AdditionalUserInfoTests: XCTestCase {
  let kFakeProfile = ["email": "user@mail.com", "given_name": "User", "family_name": "Doe"]
  let kUserName = "User Doe"
  let kProviderID = "PROVIDER_ID"

  /** @fn testAdditionalUserInfoCreation
      @brief Tests successful creation of @c FIRAdditionalUserInfo with
          @c initWithProviderID:profile:username: call.
   */
  func testAdditionalUserInfoCreation() {
    let userInfo = AdditionalUserInfo(providerID: kProviderID,
                                      profile: kFakeProfile,
                                      username: kUserName,
                                      isNewUser: true)
    XCTAssertEqual(userInfo.providerID, kProviderID)
    XCTAssertEqual(userInfo.profile as? [String: String], kFakeProfile)
    XCTAssertEqual(userInfo.username, kUserName)
    XCTAssertTrue(userInfo.isNewUser)
  }

  /** @fn testAdditionalUserInfoCoding
      @brief Tests successful archiving and unarchiving of @c FIRAdditionalUserInfo.
   */
  func testAdditionalUserInfoCoding() throws {
    let userInfo = AdditionalUserInfo(providerID: kProviderID,
                                      profile: kFakeProfile,
                                      username: kUserName,
                                      isNewUser: true)
    XCTAssertTrue(AdditionalUserInfo.supportsSecureCoding)
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: userInfo,
      requiringSecureCoding: true
    )
    let unarchivedUserInfo = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
      ofClass: AdditionalUserInfo.self, from: data
    ))
    XCTAssertEqual(unarchivedUserInfo.providerID, kProviderID)
    XCTAssertEqual(unarchivedUserInfo.profile as? [String: String], kFakeProfile)
    XCTAssertEqual(unarchivedUserInfo.username, kUserName)
    XCTAssertTrue(unarchivedUserInfo.isNewUser)
  }
}
