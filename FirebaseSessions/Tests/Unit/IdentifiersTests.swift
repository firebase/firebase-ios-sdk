//
// Copyright 2022 Google LLC
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

@testable import FirebaseSessions
@testable import FirebaseInstallations

var installations = MockInstallationsProtocol()
var identifiers = Identifiers(installations: installations)

class IdentifiersTests: XCTestCase {
  override func setUpWithError() throws {
    // Clear all UserDefaults
    if let appDomain = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: appDomain)
    }

    installations = MockInstallationsProtocol()
    identifiers = Identifiers(installations: installations)
  }

  func isValidSessionID(_ sessionID: String) -> Bool {
    if sessionID.count != 32 {
      assertionFailure("Session ID isn't 32 characters long")
      return false
    }
    if sessionID.contains("-") {
      assertionFailure("Session ID contains a dash")
      return false
    }
    if sessionID.lowercased().compare(sessionID) != ComparisonResult.orderedSame {
      assertionFailure("Session ID is not lowercase")
      return false
    }
    return true
  }

  func testInitialSessionIDGeneration() throws {
    identifiers.generateNewSessionID()
    assert(isValidSessionID(identifiers.sessionID))
    assert(identifiers.lastSessionID.count == 0)
  }

  func testRotateSessionID() throws {
    identifiers.generateNewSessionID()

    let firstSessionID = identifiers.sessionID
    assert(isValidSessionID(identifiers.sessionID))
    assert(identifiers.lastSessionID.count == 0)

    identifiers.generateNewSessionID()

    assert(isValidSessionID(identifiers.sessionID))
    assert(isValidSessionID(identifiers.lastSessionID))

    // Ensure the new lastSessionID is equal to the sessionID from earlier
    assert(identifiers.lastSessionID.compare(firstSessionID) == ComparisonResult.orderedSame)
  }

  // Fetching FIIDs requires that we are on a background thread.
  func testSuccessfulFIID() throws {
    // Make our mock return an ID
    let testID = "testID"
    installations.result = .success(testID)

    let expectation = XCTestExpectation(description: "Get the Installation ID Asynchronously")

    DispatchQueue.global().async {
      XCTAssertEqual(identifiers.installationID, testID)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testFailedFIID() throws {
    // Make our mock return an error
    installations.result = .failure(NSError(domain: "FestFailedFIIDErrorDomain", code: 0))

    let expectation = XCTestExpectation(description: "Get the Installation ID Asynchronously")

    DispatchQueue.global().async {
      XCTAssertEqual(identifiers.installationID, "")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }
}
