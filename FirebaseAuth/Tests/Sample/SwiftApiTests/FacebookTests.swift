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
  func testSignInWithFacebook() throws {
    let auth = Auth.auth()
    let userInfoDict = createFacebookTestingAccount()
    let facebookAccessToken: String = try XCTUnwrap(userInfoDict["access_token"] as? String)
    let facebookAccountID: String = try XCTUnwrap(userInfoDict["id"] as? String)
    let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)
    let expectation = self.expectation(description: "Signing in with Facebook finished.")
    auth.signIn(with: credential) { result, error in
      if let error = error {
        XCTFail("Signing in with Facebook had error: \(error)")
      } else {
        XCTAssertEqual(auth.currentUser?.displayName, Credentials.kFacebookUserName)
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)

    // Clean up the created Firebase/Facebook user for future runs.
    deleteCurrentUser()
    deleteFacebookTestingAccountbyID(facebookAccountID)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testSignInWithFacebookAsync() async throws {
      let auth = Auth.auth()
      let userInfoDict = try await createFacebookTestingAccountAsync()
      let facebookAccessToken: String = try XCTUnwrap(userInfoDict["access_token"] as? String)
      let facebookAccountID: String = try XCTUnwrap(userInfoDict["id"] as? String)
      let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)

      try await auth.signIn(with: credential)
      XCTAssertEqual(auth.currentUser?.displayName, Credentials.kFacebookUserName)

      // Clean up the created Firebase/Facebook user for future runs.
      try await deleteCurrentUserAsync()
      try await deleteFacebookTestingAccountbyIDAsync(facebookAccountID)
    }
  #endif

  func testLinkAnonymousAccountToFacebookAccount() throws {
    let auth = Auth.auth()
    signInAnonymously()
    let userInfoDict = createFacebookTestingAccount()
    let facebookAccessToken: String = try XCTUnwrap(userInfoDict["access_token"] as? String)
    let facebookAccountID: String = try XCTUnwrap(userInfoDict["id"] as? String)
    let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)
    let expectation = self.expectation(description: "Facebook linking finished.")
    auth.currentUser?.link(with: credential, completion: { result, error in
      if let error = error {
        XCTFail("Link to Firebase error: \(error)")
      } else {
        guard let providers = (auth.currentUser?.providerData) else {
          XCTFail("Failed to get providers")
          return
        }
        XCTAssertEqual(providers.count, 1)
        XCTAssertEqual(providers[0].providerID, "facebook.com")
      }
      expectation.fulfill()
    })
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)

    // Clean up the created Firebase/Facebook user for future runs.
    deleteCurrentUser()
    deleteFacebookTestingAccountbyID(facebookAccountID)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testLinkAnonymousAccountToFacebookAccountAsync() async throws {
      let auth = Auth.auth()
      try await signInAnonymouslyAsync()
      let userInfoDict = try await createFacebookTestingAccountAsync()
      let facebookAccessToken: String = try XCTUnwrap(userInfoDict["access_token"] as? String)
      let facebookAccountID: String = try XCTUnwrap(userInfoDict["id"] as? String)
      let credential = FacebookAuthProvider.credential(withAccessToken: facebookAccessToken)
      try await auth.currentUser?.link(with: credential)
      guard let providers = (auth.currentUser?.providerData) else {
        XCTFail("Failed to get providers")
        return
      }
      XCTAssertEqual(providers.count, 1)
      XCTAssertEqual(providers[0].providerID, "facebook.com")

      // Clean up the created Firebase/Facebook user for future runs.
      try await deleteCurrentUserAsync()
      try await deleteFacebookTestingAccountbyIDAsync(facebookAccountID)
    }
  #endif

  /// ** Creates a Facebook testing account using Facebook Graph API and return a dictionary that
  // * constains "id", "access_token", "login_url", "email" and "password" of the created account.
  // */
  func createFacebookTestingAccount() -> [String: Any] {
    var returnValue: [String: Any] = [:]
    let urltoCreateTestUser = "https://graph.facebook.com/\(Credentials.kFacebookAppID)" +
      "/accounts/test-users"
    let bodyString = "installed=true&name=\(Credentials.kFacebookUserName)" +
      "&permissions=read_stream&access_token=\(Credentials.kFacebookAppAccessToken)"
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService()
    let fetcher = service.fetcher(withURLString: urltoCreateTestUser)
    fetcher.bodyData = postData
    fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
    let expectation = self.expectation(description: "Creating Facebook account finished.")
    fetcher.beginFetch { data, error in
      if let error = error {
        let error = error as NSError
        if let message = String(data: error.userInfo["data"] as! Data, encoding: .utf8) {
          // May get transient errors here for too many api calls when tests run frequently.
          XCTFail("Creating Facebook account failed with error: \(message)")
        } else {
          XCTFail("Creating Facebook account failed with error: \(error)")
        }
      } else {
        do {
          let data = try XCTUnwrap(data)
          returnValue = try JSONSerialization.jsonObject(with: data, options: [])
            as! [String: Any]
        } catch {
          XCTFail("Failed to unwrap data \(error)")
        }
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
    return returnValue
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    /// ** Creates a Facebook testing account using Facebook Graph API and return a dictionary that
    // * constains "id", "access_token", "login_url", "email" and "password" of the created account.
    // */
    func createFacebookTestingAccountAsync() async throws -> [String: Any] {
      let urltoCreateTestUser = "https://graph.facebook.com/\(Credentials.kFacebookAppID)" +
        "/accounts/test-users"
      let bodyString = "installed=true&name=\(Credentials.kFacebookUserName)" +
        "&permissions=read_stream&access_token=\(Credentials.kFacebookAppAccessToken)"
      let postData = bodyString.data(using: .utf8)
      let service = GTMSessionFetcherService()
      let fetcher = service.fetcher(withURLString: urltoCreateTestUser)
      fetcher.bodyData = postData
      fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
      let data = try await fetcher.beginFetch()
      guard let returnValue = try JSONSerialization.jsonObject(with: data, options: [])
        as? [String: Any] else {
        XCTFail("Failed to serialize userInfo as a Dictionary")
        fatalError()
      }
      return returnValue
    }
  #endif

  // ** Delete a Facebook testing account by account Id using Facebook Graph API. */
  func deleteFacebookTestingAccountbyID(_ accountID: String) {
    let urltoDeleteTestUser = "https://graph.facebook.com/\(accountID)"
    let bodyString = "method=delete&access_token=\(Credentials.kFacebookAppAccessToken)"
    let postData = bodyString.data(using: .utf8)
    let service = GTMSessionFetcherService()
    let fetcher = service.fetcher(withURLString: urltoDeleteTestUser)
    fetcher.bodyData = postData
    fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
    let expectation = self.expectation(description: "Deleting Facebook account finished.")
    fetcher.beginFetch { data, error in
      if let error = error {
        XCTFail("Deleting Facebook account failed with error: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    // ** Delete a Facebook testing account by account Id using Facebook Graph API. */
    func deleteFacebookTestingAccountbyIDAsync(_ accountID: String) async throws {
      let urltoDeleteTestUser = "https://graph.facebook.com/\(accountID)"
      let bodyString = "method=delete&access_token=\(Credentials.kFacebookAppAccessToken)"
      let postData = bodyString.data(using: .utf8)
      let service = GTMSessionFetcherService()
      let fetcher = service.fetcher(withURLString: urltoDeleteTestUser)
      fetcher.bodyData = postData
      fetcher.setRequestValue("text/plain", forHTTPHeaderField: "Content-Type")
      try await fetcher.beginFetch()
    }
  #endif
}
