/*
* Copyright 2020 Google LLC
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*      http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
import FirebaseAuth
import GTMSessionFetcher
import XCTest

class FacebookTests: TestsBase {
  func testSignInWithFacebook() {
    let auth = Auth.auth()
    let userInfoDict = self.createFacebookTestingAccount()
    guard let facebookAccessToken = userInfoDict["access_token"] as! String? else {
      XCTAssertTrue(false, "Failed to get facebookAccessToken")
      return
    }
    guard let facebookAccountID = userInfoDict["id"] as! String? else {
      XCTAssertTrue(false, "Failed to get facebookAccountID")
      return
    }
    let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)
    let expectation = self.expectation(description: "Signing in with Facebook finished.")
    auth.signIn(with: credential) { (result, error) in
      if let error = error {
        XCTAssertTrue(false, "Signing in with Facebook had error: \(error)")
      } else {
        XCTAssertEqual(auth.currentUser?.displayName, Credentials.kFacebookUserName)
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout:TestsBase.kExpectationsTimeout)

    // Clean up the created Firebase/Facebook user for future runs.
    self.deleteCurrentUser()
    self.deleteFacebookTestingAccountbyID(facebookAccountID)
  }

  func testLinkAnonymousAccountToFacebookAccount() {
    let auth = Auth.auth()
    self.signInAnonymously()
    let userInfoDict = self.createFacebookTestingAccount()
    guard let facebookAccessToken = userInfoDict["access_token"] as! String? else {
      XCTAssertTrue(false, "Failed to get facebookAccessToken")
      return
    }
    guard let facebookAccountID = userInfoDict["id"] as! String? else {
      XCTAssertTrue(false, "Failed to get facebookAccountID")
      return
    }
    let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)
    let expectation = self.expectation(description: "Facebook linking finished.")
    auth.currentUser?.link(with: credential, completion: { (result, error) in
      if let error = error {
        XCTAssertTrue(false, "Link to Firebase error: \(error)")
      } else {
        guard let providers = (auth.currentUser?.providerData) else {
          XCTAssertTrue(false, "Failed to get providers")
          return
        }
        XCTAssertEqual(providers.count, 1)
        XCTAssertEqual(providers[0].providerID, "facebook.com")
      }
      expectation.fulfill()
    })
    waitForExpectations(timeout:TestsBase.kExpectationsTimeout)

    // Clean up the created Firebase/Facebook user for future runs.
    self.deleteCurrentUser()
    self.deleteFacebookTestingAccountbyID(facebookAccountID)
  }

  ///** Creates a Facebook testing account using Facebook Graph API and return a dictionary that
  // * constains "id", "access_token", "login_url", "email" and "password" of the created account.
  // */
  func createFacebookTestingAccount() -> Dictionary<String, Any> {
    var returnValue : Dictionary<String, Any> = [:]
    let urltoCreateTestUser = "https://graph.facebook.com/\(Credentials.kFacebookAppID)" +
      "/accounts/test-users"
    let bodyString = "installed=true&name=\(Credentials.kFacebookUserName)" +
      "&permissions=read_stream&access_token=\(Credentials.kFacebookAppAccessToken)"
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService.init()
    let fetcher = service.fetcher(withURLString: urltoCreateTestUser)
    fetcher.bodyData = postData
    fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
    let expectation = self.expectation(description: "Creating Facebook account finished.")
    fetcher.beginFetch { (data, error) in
      if let error = error {
        let error = error as NSError
        if let message = String.init(data: error.userInfo["data"] as! Data, encoding: .utf8) {
          // May get transient errors here for too many api calls when tests run frequently.
          XCTAssertTrue(false, "Creating Facebook account failed with error: \(message)")
        } else {
          XCTAssertTrue(false, "Creating Facebook account failed with error: \(error)")
        }
      } else {
        do {
          let data = try XCTUnwrap(data)
          guard let userInfo = String.init(data: data, encoding: .utf8) else {
            XCTAssertTrue(false, "Failed to convert data to string")
            return
          }
          print("The created Facebook testing account info is: \(String(describing: userInfo))")
          returnValue = try JSONSerialization.jsonObject(with: data, options: [])
            as! Dictionary<String, Any>
        } catch (let error) {
          XCTAssertTrue(false, "Failed to unwrap data \(error)")
        }
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout:TestsBase.kExpectationsTimeout)
    return returnValue
  }

  //** Delete a Facebook testing account by account Id using Facebook Graph API. */
  func deleteFacebookTestingAccountbyID(_ accountID: String) {
    let urltoDeleteTestUser = "https://graph.facebook.com/\(accountID)"
    let bodyString = "method=delete&access_token=\(Credentials.kFacebookAppAccessToken)"
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService.init()
    let fetcher = service.fetcher(withURLString: urltoDeleteTestUser)
    fetcher.bodyData = postData
    fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
    let expectation = self.expectation(description: "Deleting Facebook account finished.")
    fetcher.beginFetch { (data, error) in
      if let error = error {
        XCTAssertTrue(false, "Deleting Facebook account failed with error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout:TestsBase.kExpectationsTimeout)
  }
}
