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

class GoogleTests: TestsBase {

  func testSignInWithGoogle() {
    let auth = Auth.auth()
    let userInfoDict = self.getGoogleAccessToken()
    guard let googleAccessToken = userInfoDict["access_token"] as! String? else {
      XCTAssertTrue(false, "Failed to get googleAccessToken")
      return
    }
    guard let googleIDToken = userInfoDict["id_token"] as! String? else {
      XCTAssertTrue(false, "Failed to get googleIDToken")
      return
    }
    let credential = GoogleAuthProvider.credential(withIDToken: googleIDToken,
                                                   accessToken: googleAccessToken)
    let expectation = self.expectation(description: "Signing in with Google finished.")
    auth.signIn(with: credential) { (result, error) in
      if let error = error {
        print("Signing in with Google had error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout:TestsBase.kExpectationsTimeout)
  }

  ///** Sends http request to Google OAuth2 token server to use refresh token to exchange for Google
  // * access token. Returns a dictionary that constains "access_token", "token_type", "expires_in" and
  // * sometimes the "id_token". (The id_token is not guaranteed to be returned during a refresh
  // * exchange; see https://openid.net/specs/openid-connect-core-1_0.html#RefreshTokenResponse)
  // */
  func getGoogleAccessToken() -> Dictionary<String, Any> {
    var returnValue : Dictionary<String, Any> = [:]
    let googleOauth2TokenServerUrl = "https://www.googleapis.com/oauth2/v4/token"
    let bodyString = "client_id=\(Credentials.kGoogleClientID)&grant_type=refresh_token" +
      "&refresh_token=\(Credentials.kGoogleTestAccountRefreshToken)"
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService.init()
    let fetcher = service.fetcher(withURLString: googleOauth2TokenServerUrl)
    fetcher.bodyData = postData
    fetcher.setRequestValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let expectation = self.expectation(description: "Exchanging Google account tokens finished.")
    fetcher.beginFetch { (data, error) in
      if let error = error {
        XCTAssertTrue(false, "Exchanging Google account tokens finished with error: \(error)")
      } else {
        do {
          let data = try XCTUnwrap(data)
          let userInfo = String.init(data: data, encoding: .utf8)
          print("The info of exchanged result is: \(String(describing: userInfo))")
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
}
