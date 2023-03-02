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

@testable import FirebaseAppDistributionInternal
@testable import FirebaseInstallations

class AppDistributionApiServiceTests: XCTestCase {
  
  static let mockReleases = [
    "releases" : [
      [
        "displayVersion" : "1.0.0",
        "buildVersion" : "111",
        "releaseNotes" : "This is a release",
        "downloadURL" : "http://faketyfakefake.download"
      ],
      [
        "latest" : true,
        "displayVersion" : "1.0.1",
        "buildVersion" : "112",
        "releaseNotes" : "This is a release too",
        "downloadURL" : "http://faketyfakefake.download"
      ]
    ]
  ];
  
  
  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000", gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    options.apiKey = "AIzaSyByd9FGaZjtoILTq6Ff--zm8EyIoJsu3bg"
    FirebaseApp.configure(name: "__FIRAPP_DEFAULT", options: options)
    let _ = FirebaseApp.app()
    
  }
  
  func generateFakeFIRInstallation() -> InstallationsProtocol {
    class FakeFIRInstallation: InstallationsProtocol {
      func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void) {
        let authToken = InstallationsAuthTokenResult(token: "abcde", expirationDate: Date())
        completion(authToken, nil)
      }

      func installationID(completion: @escaping (String?, Error?) -> Void) {
        let installationID = "abcde"

        completion(installationID, nil)
      }
    }
    
    return FakeFIRInstallation()
  }
  
  func generateFakeURLSession() -> URLSession {
    class FakeURLSession: URLSession {
      override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        // TODO input
        let data = try! JSONSerialization.data(withJSONObject: AppDistributionApiServiceTests.mockReleases)
        
        // TODO input.
        let urlResponse = HTTPURLResponse(url: URL(string: "https://google.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        completionHandler(data, urlResponse, nil)
        return URLSessionDataTask()
      }
    }
    
    return FakeURLSession()
  }
  
  func testFetchReleasesWithCompletionSuccess() {
    let firInstallation = generateFakeFIRInstallation()
    let urlSession = generateFakeURLSession()
    
    let expectation = XCTestExpectation(description: "testFetchReleasesWithCompletionSuccess")
    
    AppDistributionApiService.fetchReleases(firInstallation: firInstallation, urlSession: urlSession, completion: { releases,error in
      XCTAssertNotNil(releases)
      XCTAssertNil(error)
      XCTAssertEqual(releases?.count, 2)
      expectation.fulfill()
    })
    
    wait(for: [expectation], timeout: 5)
  }
}
