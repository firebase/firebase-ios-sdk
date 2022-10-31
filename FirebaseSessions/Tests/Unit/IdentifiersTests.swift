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

class IdentifiersTests: XCTestCase {
  var installations: MockInstallationsProtocol!
  var identifiers: Identifiers!

  override func setUp() {
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

  // This test case isn't important behavior. When Crash and Perf integrate
  // with the Sessions SDK, we may want to move to a lazy solution where
  // sessionID can never be empty
  func test_sessionID_beforeGenerateReturnsNothing() throws {
    XCTAssert(identifiers.sessionID.count == 0)
    XCTAssertNil(identifiers.previousSessionID)
  }

  func test_generateNewSessionID_generatesValidID() throws {
    identifiers.generateNewSessionID()
    XCTAssert(isValidSessionID(identifiers.sessionID))
    XCTAssertNil(identifiers.previousSessionID)
  }

  /// Ensures that generating a Session ID multiple times results in the last Session ID being set in the previousSessionID field
  func test_generateNewSessionID_rotatesPreviousID() throws {
    identifiers.generateNewSessionID()

    let firstSessionID = identifiers.sessionID
    XCTAssert(isValidSessionID(identifiers.sessionID))
    XCTAssertNil(identifiers.previousSessionID)

    identifiers.generateNewSessionID()

    XCTAssert(isValidSessionID(identifiers.sessionID))
    XCTAssert(isValidSessionID(identifiers.previousSessionID ?? ""))

    // Ensure the new lastSessionID is equal to the sessionID from earlier
    XCTAssert((identifiers.previousSessionID ?? "").compare(firstSessionID) == ComparisonResult.orderedSame)
  }

  // Fetching FIIDs requires that we are on a background thread.
  func test_installationID_getsValidID() throws {
    // Make our mock return an ID
    let testID = "testID"
    installations.result = .success(testID)

    let expectation = XCTestExpectation(description: "Get the Installation ID Asynchronously")

    DispatchQueue.global().async { [self] in
      XCTAssertEqual(self.identifiers.installationID, testID)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func test_installationID_handlesFailedFetch() throws {
    // Make our mock return an error
    installations.result = .failure(NSError(domain: "FestFailedFIIDErrorDomain", code: 0))

    let expectation = XCTestExpectation(description: "Get the Installation ID Asynchronously")

    DispatchQueue.global().async { [self] in
      XCTAssertEqual(self.identifiers.installationID, "")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }
}
