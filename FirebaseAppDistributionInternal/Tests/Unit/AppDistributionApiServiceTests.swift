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
  
  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000", gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    options.apiKey = "AIzaSyByd9FGaZjtoILTq6Ff--zm8EyIoJsu3bg"
    FirebaseApp.configure(name: "__FIRAPP_DEFAULT", options: options)
    let _ = FirebaseApp.app()
  }
  
  func testFindRelease() {
    
    class MockFIRInstallation: FirebaseInstallations.Installations {
      override func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void) {
        let authTokenResult = InstallationsAuthTokenResult.init(withToken:"abcde" expirationDate)
        authTokenResult.authToken = "abcde"
        authTokenResult.expirationDate = Date()
        completion(
      }
      
    }
    
    AppDistributionApiService.findRelease(displayVersion: "1.0", buildVersion: "1.0", codeHash: "1234", completion: { releaseName,error in
      XCTAssertNotNil(error)
    })
  }
}
