/*
 * Copyright 2019 Google
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

import XCTest

class GoogleAuthTestsSwift: FIRAuthApiTestsBase {
  let kGoogleCliendId = KGOOGLE_CLIENT_ID

  let kGoogleTestAccountName = KGOOGLE_USER_NAME

  let kGoogleTestAccountRefreshToken = KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN

  func testSignInWithGoogle() {
    let auth = Auth.auth()
    let userInfoDictOptional = getGoogleAccessToken()
    if userInfoDictOptional == nil {
      XCTFail("Could not obtain Google access token.")
    }
    let userInfoDict = userInfoDictOptional!
    let googleAccessToken = userInfoDict["access_token"] as! String
    let googleIdToken = userInfoDict["id_token"] as! String
    let credential = GoogleAuthProvider.credential(withIDToken: googleIdToken, accessToken: googleAccessToken)

    let expectation = self.expectation(description: "Signing in with Google finished.")
    auth.signIn(with: credential) { _, error in
      if error != nil {
        print("Signing in with Google had error: %@", error!)
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: kExpectationsTimeout) { error in
      if error != nil {
        XCTFail(String(format: "Failed to wait for expectations in Signing in with Google. Error: %@", error!.localizedDescription))
      }
    }

    XCTAssertEqual(auth.currentUser?.displayName, kGoogleTestAccountName)

    deleteCurrentUser()
  }

  func getGoogleAccessToken() -> [String: Any]? {
    let googleOauth2TokenServerUrl = "https://www.googleapis.com/oauth2/v4/token"
    let bodyString = String(format: "client_id=%@&grant_type=refresh_token&refresh_token=%@", kGoogleCliendId, kGoogleTestAccountRefreshToken)
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService()
    let fetcher = service.fetcher(withURLString: googleOauth2TokenServerUrl)
    fetcher.bodyData = postData
    fetcher.setRequestValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let expectation = self.expectation(description: "Exchanging Google account tokens finished.")
    var data: Data?
    fetcher.beginFetch { receivedData, error in
      if error != nil {
        print("Exchanging Google account tokens finished with error: %@", error!)
        return
      }
      data = receivedData
      expectation.fulfill()
    }

    waitForExpectations(timeout: kExpectationsTimeout) { error in
      if error != nil {
        XCTFail(String(format: "Failed to wait for expectations in exchanging Google account tokens. Error: %@", error!.localizedDescription))
      }
    }

    let userInfo = String(data: data!, encoding: .utf8)
    print("The info of exchanged result is: \(userInfo ?? "<userInfo>")")
    let rawJsonObject = try? JSONSerialization.jsonObject(with: data!, options: [])
    if let userInfoDict = rawJsonObject as? [String: Any] {
      return userInfoDict
    } else {
      return nil
    }
  }
}
