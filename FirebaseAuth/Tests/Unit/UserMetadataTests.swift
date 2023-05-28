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

/** @class FIRUserMetadataTests
    @brief Tests for @c FIRUserMetadata.
 */
class UserMetadataTests: XCTestCase {
  let kCreationDateTimeIntervalInSeconds: TimeInterval = 1_505_858_500
  let kLastSignInDateTimeIntervalInSeconds: TimeInterval = 1_505_858_583

  /** @fn testUserMetadataCreation
      @brief Tests successful creation of a @c FIRUserMetadata object.
   */
  func testUserMetadataCreation() {
    let creationDate = Date(timeIntervalSince1970: kCreationDateTimeIntervalInSeconds)
    let lastSignInDate = Date(timeIntervalSince1970: kLastSignInDateTimeIntervalInSeconds)
    let userMetadata = UserMetadata(withCreationDate: creationDate, lastSignInDate: lastSignInDate)
    XCTAssertEqual(creationDate, userMetadata.creationDate)
    XCTAssertEqual(lastSignInDate, userMetadata.lastSignInDate)
  }

  /** @fn testUserMetadataCoding
      @brief Tests successful archiving and unarchiving of a @c FIRUserMetadata object.
   */
  func testUserMetadataCoding() throws {
    let creationDate = Date(timeIntervalSince1970: kCreationDateTimeIntervalInSeconds)
    let lastSignInDate = Date(timeIntervalSince1970: kLastSignInDateTimeIntervalInSeconds)
    let userMetadata = UserMetadata(withCreationDate: creationDate, lastSignInDate: lastSignInDate)

    let data = NSKeyedArchiver.archivedData(withRootObject: userMetadata)
    let unarchivedUserMetadata = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: data)
      as? UserMetadata)
    XCTAssertEqual(creationDate, unarchivedUserMetadata.creationDate)
    XCTAssertEqual(lastSignInDate, unarchivedUserMetadata.lastSignInDate)
  }
}
