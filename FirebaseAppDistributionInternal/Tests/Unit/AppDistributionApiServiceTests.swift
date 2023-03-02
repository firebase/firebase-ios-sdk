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

import XCTest
import FirebaseCore

@testable import FirebaseInstallations
@testable import FirebaseAppDistributionInternal

class AppDistributionApiServiceTests: XCTestCase {
  
  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000", gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    options.apiKey = "api-key"
    FirebaseApp.configure(name: "__FIRAPP_DEFAULT", options: options)
    let _ = FirebaseApp.app()
  }
  
  // MARK: - Test generateAuthToken
  
  func testGenerateAuthTokenWithCompletionSuccess() {
    let installations = FakeInstallations.installations()
    
    let expectation = XCTestExpectation(description: "Generate auth token succeeds")
    
    AppDistributionApiService.generateAuthToken(installations: installations, completion: { identifier,authTokenResult,error in
      XCTAssertNotNil(identifier)
      XCTAssertNotNil(authTokenResult)
      XCTAssertNil(error)
      expectation.fulfill()
    })
    
    wait(for: [expectation], timeout: 5)
  }
  
  // MARK: - Test fetchReleases
  
  func testFetchReleasesWithCompletionSuccess() {
    let installations = FakeInstallations.installations()
    let urlSession = URLSessionMock(testCase: .success)
    
    let expectation = XCTestExpectation(description: "Fetch releases succeeds with two releases.")
    
    AppDistributionApiService.fetchReleases(installations: installations, urlSession: urlSession, completion: { releases,error in
      XCTAssertNotNil(releases)
      XCTAssertNil(error)
      XCTAssertEqual(releases?.count, 2)
      expectation.fulfill()
    })
    
    wait(for: [expectation], timeout: 5)
  }
  
  func testFetchReleasesWithCompletionUnknownFailure() {
    let installations = FakeInstallations.installations()
    let urlSession = URLSessionMock(testCase: .unknownFailure)
    
    let expectation = XCTestExpectation(description: "Fetch releases fails with unknown error.")
    
    AppDistributionApiService.fetchReleases(installations: installations, urlSession: urlSession, completion: { releases, error in
      let nserror = error as? NSError
      XCTAssertNil(releases)
      XCTAssertNotNil(nserror)
      XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnknownFailure.rawValue)
      expectation.fulfill()
    })
    
    wait(for: [expectation], timeout: 5)
  }
  
  func testFetchReleasesWithCompletionUnauthenticatedFailure() {
    let installations = FakeInstallations.installations()
    let urlSession = URLSessionMock(testCase: .unauthenticatedFailure)
    
    let expectation = XCTestExpectation(description: "Fetch releases fails with unauthenticated error.")
    
    AppDistributionApiService.fetchReleases(installations: installations, urlSession: urlSession, completion: { releases, error in
      let nserror = error as? NSError
      XCTAssertNil(releases)
      XCTAssertNotNil(nserror)
      XCTAssertEqual(nserror?.code, AppDistributionApiError.ApiErrorUnauthenticated.rawValue)
      expectation.fulfill()
    })
    
    wait(for: [expectation], timeout: 5)
  }
  
  // TODO: Add more cases for testFetchReleases
}
