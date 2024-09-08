// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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
import FirebaseCore

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class UserTests: RPCBaseTests {
  static let kFakeAPIKey = "FAKE_API_KEY"
  let kFacebookAccessToken = "FACEBOOK_ACCESS_TOKEN"
  let kFacebookID = "FACEBOOK_ID"
  let kFacebookEmail = "user@facebook.com"
  let kFacebookDisplayName = "Facebook Doe"
  let kFacebookIDToken: String? = nil // Facebook id Token is always nil.
  let kNewEmail = "newuser@company.com"
  let kNewPassword = "newpassword"
  let kNewDisplayName = "New User Doe"
  let kVerificationCode = "12345678"
  let kVerificationID = "55432"
  let kPhoneNumber = "555-1234"

  static var auth: Auth?

  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = kFakeAPIKey
    options.projectID = "myUserProjectID"
    FirebaseApp.configure(name: "test-UserTests", options: options)
    #if (os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN) || SWIFT_PACKAGE
      let keychainStorageProvider = FakeAuthKeychainStorage()
    #else
      let keychainStorageProvider = AuthKeychainStorageReal()
    #endif // (os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN) || SWIFT_PACKAGE
    auth = Auth(
      app: FirebaseApp.app(name: "test-UserTests")!,
      keychainStorageProvider: keychainStorageProvider
    )
  }

  override func tearDown() {
    // Verifies that no tasks are left suspended on the AuthSerialTaskQueue.
    try? UserTests.auth?.signOut()
  }

  /** @fn testUserPropertiesAndNSSecureCoding
      @brief Tests properties of the @c User instance before and after being
          serialized/deserialized.
   */
  func testUserPropertiesAndNSSecureCoding() throws {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"
    let kGoogleID = "GOOGLE_ID"
    let kGoogleDisplayName = "Google Doe"
    let kGoogleEmail = "user@gmail.com"
    let kGooglePhotoURL = "https://googleusercontents.com/user/profile"
    let kFacebookID = "FACEBOOK_ID"
    let kFacebookEmail = "user@facebook.com"
    let kEnrollmentID = "fakeEnrollment"
    let kPhoneInfo = "+15555555555"
    let kEnrolledAt = "2022-08-01T18:31:15.426458Z"
    let kEnrolledAtMatch = "2022-08-01 18:31:15 +0000"
    let kTwitterID = "TwitterID"
    let kGitHubID = "GitHubID"
    let kGameCenterID = "GameCenterID"

    var providerUserInfos = [[
      kProviderIDkey: EmailAuthProvider.id,
      kFederatedIDKey: kEmail,
      kEmailKey: kEmail,
    ],
    [
      kProviderIDkey: GoogleAuthProvider.id,
      kDisplayNameKey: kGoogleDisplayName,
      kPhotoUrlKey: kGooglePhotoURL,
      kFederatedIDKey: kGoogleID,
      kEmailKey: kGoogleEmail,
    ],
    [
      kProviderIDkey: FacebookAuthProvider.id,
      kFederatedIDKey: kFacebookID,
      kEmailKey: kFacebookEmail,
    ],
    [
      kProviderIDkey: GitHubAuthProvider.id,
      kFederatedIDKey: kGitHubID,
      kEmailKey: kGoogleEmail,
    ],
    [
      kProviderIDkey: TwitterAuthProvider.id,
      kFederatedIDKey: kTwitterID,
      kEmailKey: kFacebookEmail,
    ]]

    #if !os(watchOS)
      providerUserInfos.append([
        kProviderIDkey: GameCenterAuthProvider.id,
        kFederatedIDKey: kGameCenterID,
        kEmailKey: kFacebookEmail,
      ])
    #endif

    #if os(iOS)
      providerUserInfos.append([
        kProviderIDkey: PhoneAuthProvider.id,
        kFederatedIDKey: kPhoneNumber,
        "phoneNumber": kPhoneNumber,
      ])
    #endif

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: providerUserInfos,
      kLocalIDKey: kLocalID,
      kDisplayNameKey: kDisplayName,
      kEmailKey: kEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
      "phoneNumber": kPhoneNumber,
      "createdAt": String(Int(kCreationDateTimeIntervalInSeconds) * 1000), // to nanoseconds
      "lastLoginAt": String(Int(kLastSignInDateTimeIntervalInSeconds) * 1000),
      "mfaInfo": [
        [
          "phoneInfo": kPhoneInfo,
          "mfaEnrollmentId": kEnrollmentID,
          "displayName": kDisplayName,
          "enrolledAt": kEnrolledAt,
        ],
        [
          // In practice, this will be an empty dictionary.
          "totpInfo": [AnyHashable: AnyHashable](),
          "mfaEnrollmentId": kEnrollmentID,
          "displayName": kDisplayName,
          "enrolledAt": kEnrolledAt,
        ] as [AnyHashable: AnyHashable],
      ],
    ]]

    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        XCTAssertEqual(user.providerID, "Firebase")
        XCTAssertEqual(user.uid, self.kLocalID)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.photoURL, URL(string: self.kTestPhotoURL))
        XCTAssertEqual(user.email, self.kEmail)
        XCTAssertEqual(user.metadata.creationDate, Date(timeIntervalSince1970:
          self.kCreationDateTimeIntervalInSeconds))
        XCTAssertEqual(user.metadata.lastSignInDate,
                       Date(timeIntervalSince1970: self.kLastSignInDateTimeIntervalInSeconds))

        // Verify FIRUser properties besides providerData contents.
        XCTAssertFalse(user.isAnonymous)
        XCTAssertTrue(user.isEmailVerified)
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertEqual(user.providerData.count, providerUserInfos.count)

        let providerMap = user.providerData.reduce(into: [String: UserInfo]()) {
          $0[$1.providerID] = $1
        }

        // Verify FIRUserInfo properties from email/password.
        let passwordUserInfo = try XCTUnwrap(providerMap[EmailAuthProvider.id])
        XCTAssertEqual(passwordUserInfo.uid, self.kEmail)
        XCTAssertNil(passwordUserInfo.displayName)
        XCTAssertNil(passwordUserInfo.photoURL)
        XCTAssertEqual(passwordUserInfo.email, self.kEmail)

        // Verify FIRUserInfo properties from the Google auth provider.
        let googleUserInfo = try XCTUnwrap(providerMap[GoogleAuthProvider.id])
        XCTAssertEqual(googleUserInfo.uid, kGoogleID)
        XCTAssertEqual(googleUserInfo.displayName, kGoogleDisplayName)
        XCTAssertEqual(googleUserInfo.photoURL, URL(string: kGooglePhotoURL))
        XCTAssertEqual(googleUserInfo.email, kGoogleEmail)

        // Verify FIRUserInfo properties from the Facebook auth provider.
        let facebookUserInfo = try XCTUnwrap(providerMap[FacebookAuthProvider.id])
        XCTAssertEqual(facebookUserInfo.uid, kFacebookID)
        XCTAssertNil(facebookUserInfo.displayName)
        XCTAssertNil(facebookUserInfo.photoURL)
        XCTAssertEqual(facebookUserInfo.email, kFacebookEmail)

        // Verify FIRUserInfo properties from the GitHub auth provider.
        let gitHubUserInfo = try XCTUnwrap(providerMap[GitHubAuthProvider.id])
        XCTAssertEqual(gitHubUserInfo.uid, kGitHubID)
        XCTAssertNil(gitHubUserInfo.displayName)
        XCTAssertNil(gitHubUserInfo.photoURL)
        XCTAssertEqual(gitHubUserInfo.email, kGoogleEmail)

        // Verify FIRUserInfo properties from the Twitter auth provider.
        let twitterUserInfo = try XCTUnwrap(providerMap[TwitterAuthProvider.id])
        XCTAssertEqual(twitterUserInfo.uid, kTwitterID)
        XCTAssertNil(twitterUserInfo.displayName)
        XCTAssertNil(twitterUserInfo.photoURL)
        XCTAssertEqual(twitterUserInfo.email, kFacebookEmail)

        #if os(iOS)
          // Verify UserInfo properties from the phone auth provider.
          let phoneUserInfo = try XCTUnwrap(providerMap[PhoneAuthProvider.id])
          XCTAssertEqual(phoneUserInfo.phoneNumber, self.kPhoneNumber)
        #endif

        #if !os(watchOS)
          // Verify FIRUserInfo properties from the Game Center auth provider.
          let gameCenterUserInfo = try XCTUnwrap(providerMap[GameCenterAuthProvider.id])
          XCTAssertEqual(gameCenterUserInfo.uid, kGameCenterID)
          XCTAssertNil(gameCenterUserInfo.displayName)
          XCTAssertNil(gameCenterUserInfo.photoURL)
          XCTAssertEqual(gameCenterUserInfo.email, kFacebookEmail)
        #endif

        // Test NSSecureCoding
        XCTAssertTrue(User.supportsSecureCoding)

        let data = try NSKeyedArchiver.archivedData(
          withRootObject: user,
          requiringSecureCoding: true
        )

        var encodedClasses = [User.self, NSDictionary.self, NSURL.self, SecureTokenService.self,
                              UserInfoImpl.self, NSDate.self, UserMetadata.self, NSString.self,
                              NSArray.self]
        #if os(iOS)
          encodedClasses.append(MultiFactor.self)
          encodedClasses.append(PhoneMultiFactorInfo.self)
        #endif

        let unarchivedUser = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
          ofClasses: encodedClasses, from: data
        )
          as? User)

        // Verify NSSecureCoding for FIRUser
        XCTAssertEqual(unarchivedUser.providerID, user.providerID)
        XCTAssertEqual(unarchivedUser.uid, user.uid)
        XCTAssertEqual(unarchivedUser.email, user.email)
        XCTAssertEqual(unarchivedUser.photoURL, user.photoURL)
        XCTAssertEqual(unarchivedUser.displayName, user.displayName)

        // Verify NSSecureCoding properties besides providerData contents.
        XCTAssertEqual(unarchivedUser.isAnonymous, user.isAnonymous)
        XCTAssertEqual(unarchivedUser.isEmailVerified, user.isEmailVerified)
        XCTAssertEqual(unarchivedUser.refreshToken, user.refreshToken)
        XCTAssertEqual(unarchivedUser.metadata.creationDate, user.metadata.creationDate)
        XCTAssertEqual(unarchivedUser.metadata.lastSignInDate, user.metadata.lastSignInDate)
        XCTAssertEqual(unarchivedUser.providerData.count, user.providerData.count)

        let unarchivedProviderMap = unarchivedUser.providerData.reduce(into: [String: UserInfo]()) {
          $0[$1.providerID] = $1
        }

        // Verify NSSecureCoding properties for AuthDataResult
        let kFakeProfile = ["email": "user@mail.com", "given_name": "User", "family_name": "Doe"]
        let kUserName = "User Doe"
        let kProviderID = "PROVIDER_ID"
        let userInfo = AdditionalUserInfo(providerID: kProviderID,
                                          profile: kFakeProfile,
                                          username: kUserName,
                                          isNewUser: true)
        let authDataResult = AuthDataResult(withUser: user, additionalUserInfo: userInfo)
        XCTAssertTrue(AuthDataResult.supportsSecureCoding)
        let authDataResultData = try NSKeyedArchiver.archivedData(
          withRootObject: authDataResult,
          requiringSecureCoding: true
        )
        encodedClasses.append(AuthDataResult.self)
        encodedClasses.append(AdditionalUserInfo.self)
        let unarchivedDataResult = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
          ofClasses: encodedClasses, from: authDataResultData
        ) as? AuthDataResult)
        XCTAssertEqual(unarchivedDataResult.user.providerID, user.providerID)
        XCTAssertEqual(unarchivedDataResult.user.uid, user.uid)
        XCTAssertEqual(unarchivedDataResult.user.email, user.email)
        XCTAssertEqual(unarchivedDataResult.user.photoURL, user.photoURL)
        XCTAssertEqual(unarchivedDataResult.user.displayName, user.displayName)
        XCTAssertEqual(unarchivedDataResult.additionalUserInfo?.providerID, kProviderID)
        XCTAssertEqual(unarchivedDataResult.additionalUserInfo?.profile as? [String: String],
                       kFakeProfile)
        XCTAssertEqual(unarchivedDataResult.additionalUserInfo?.username, kUserName)

        // Verify NSSecureCoding properties from email/password.
        let unarchivedPasswordUserInfo = try XCTUnwrap(unarchivedProviderMap[EmailAuthProvider.id])
        XCTAssertEqual(unarchivedPasswordUserInfo.uid, passwordUserInfo.uid)
        XCTAssertEqual(unarchivedPasswordUserInfo.displayName, passwordUserInfo.displayName)
        XCTAssertEqual(unarchivedPasswordUserInfo.photoURL, passwordUserInfo.photoURL)
        XCTAssertEqual(unarchivedPasswordUserInfo.email, passwordUserInfo.email)

        // Verify NSSecureCoding properties from the Google auth provider.
        let unarchivedGoogleUserInfo = try XCTUnwrap(unarchivedProviderMap[GoogleAuthProvider.id])
        XCTAssertEqual(unarchivedGoogleUserInfo.uid, googleUserInfo.uid)
        XCTAssertEqual(unarchivedGoogleUserInfo.displayName, googleUserInfo.displayName)
        XCTAssertEqual(unarchivedGoogleUserInfo.photoURL, googleUserInfo.photoURL)
        XCTAssertEqual(unarchivedGoogleUserInfo.email, googleUserInfo.email)

        // Verify NSSecureCoding properties from the Facebook auth provider.
        let unarchivedFacebookUserInfo =
          try XCTUnwrap(unarchivedProviderMap[FacebookAuthProvider.id])
        XCTAssertEqual(unarchivedFacebookUserInfo.uid, facebookUserInfo.uid)
        XCTAssertEqual(unarchivedFacebookUserInfo.displayName, facebookUserInfo.displayName)
        XCTAssertEqual(unarchivedFacebookUserInfo.photoURL, facebookUserInfo.photoURL)
        XCTAssertEqual(unarchivedFacebookUserInfo.email, facebookUserInfo.email)

        #if !os(watchOS)
          // Verify NSSecureCoding properties from the GameCenter auth provider.
          let unarchivedGameCenterUserInfo =
            try XCTUnwrap(unarchivedProviderMap[GameCenterAuthProvider.id])
          XCTAssertEqual(unarchivedGameCenterUserInfo.uid, gameCenterUserInfo.uid)
          XCTAssertEqual(unarchivedGameCenterUserInfo.displayName, gameCenterUserInfo.displayName)
          XCTAssertEqual(unarchivedGameCenterUserInfo.photoURL, gameCenterUserInfo.photoURL)
          XCTAssertEqual(unarchivedGameCenterUserInfo.email, gameCenterUserInfo.email)
        #endif

        // Verify NSSecureCoding properties from the GitHub auth provider.
        let unarchivedGitHubUserInfo =
          try XCTUnwrap(unarchivedProviderMap[GitHubAuthProvider.id])
        XCTAssertEqual(unarchivedGitHubUserInfo.uid, gitHubUserInfo.uid)
        XCTAssertEqual(unarchivedGitHubUserInfo.displayName, gitHubUserInfo.displayName)
        XCTAssertEqual(unarchivedGitHubUserInfo.photoURL, gitHubUserInfo.photoURL)
        XCTAssertEqual(unarchivedGitHubUserInfo.email, gitHubUserInfo.email)

        // Verify NSSecureCoding properties from the Twitter auth provider.
        let unarchivedTwitterUserInfo =
          try XCTUnwrap(unarchivedProviderMap[TwitterAuthProvider.id])
        XCTAssertEqual(unarchivedTwitterUserInfo.uid, twitterUserInfo.uid)
        XCTAssertEqual(unarchivedTwitterUserInfo.displayName, twitterUserInfo.displayName)
        XCTAssertEqual(unarchivedTwitterUserInfo.photoURL, twitterUserInfo.photoURL)
        XCTAssertEqual(unarchivedTwitterUserInfo.email, twitterUserInfo.email)

        #if os(iOS)
          // Verify NSSecureCoding properties from the phone auth provider.
          let unarchivedPhoneUserInfo = try XCTUnwrap(unarchivedProviderMap[PhoneAuthProvider.id])
          XCTAssertEqual(unarchivedPhoneUserInfo.phoneNumber, phoneUserInfo.phoneNumber)

          // Verify MultiFactorInfo properties.
          let enrolledFactors = try XCTUnwrap(user.multiFactor.enrolledFactors)
          XCTAssertEqual(enrolledFactors.count, 2)
          XCTAssertEqual(enrolledFactors[0].factorID, PhoneMultiFactorInfo.PhoneMultiFactorID)
          XCTAssertEqual(enrolledFactors[1].factorID, PhoneMultiFactorInfo.TOTPMultiFactorID)
          for enrolledFactor in enrolledFactors {
            XCTAssertEqual(enrolledFactor.uid, kEnrollmentID)
            XCTAssertEqual(enrolledFactor.displayName, self.kDisplayName)
            let date = try XCTUnwrap(enrolledFactor.enrollmentDate)
            XCTAssertEqual("\(date)", kEnrolledAtMatch)
          }
        #endif
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailSuccess
      @brief Tests the flow of a successful @c updateEmail:completion: call.
   */
  func testUpdateEmailSuccess() {
    setFakeGetAccountProvider(withPasswordHash: kFakePassword)
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      self.changeUserEmail(user: user, changeEmail: true, expectation: expectation)
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailWithAuthLinkAccountSuccess
      @brief Tests a successful @c updateEmail:completion: call updates provider info.
   */
  func testUpdateEmailWithAuthLinkAccountSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUserLink { user in
      self.changeUserEmail(user: user, expectation: expectation)
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailFailure
      @brief Tests the flow of a failed @c updateEmail:completion: call.
   */
  func testUpdateEmailFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_EMAIL")
        }
        user.updateEmail(to: self.kNewEmail) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.invalidEmail.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailAutoSignOut
      @brief Tests the flow of a failed @c updateEmail:completion: call that automatically signs out.
   */
  func testUpdateEmailAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_ID_TOKEN")
        }
        user.updateEmail(to: self.kNewEmail) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.invalidUserToken.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is no longer signed in..
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if os(iOS)

    /** @fn testUpdatePhoneSuccess
        @brief Tests the flow of a successful @c updatePhoneNumberCredential:completion: call.
     */
    func testUpdatePhoneSuccess() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        do {
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                   "refreshToken": self.kRefreshToken])
          }
          self.expectVerifyPhoneNumberRequest()
          self.rpcIssuer?.fakeGetAccountProviderJSON = [[
            "phoneNumber": self.kPhoneNumber,
          ]]

          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )

          user.updatePhoneNumber(credential) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            XCTAssertEqual(auth.currentUser?.phoneNumber, self.kPhoneNumber)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testUpdatePhoneNumberFailure
        @brief Tests the flow of a failed @c updatePhoneNumberCredential:completion: call.
     */
    func testUpdatePhoneNumberFailure() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        do {
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_PHONE_NUMBER")
          }
          self.expectVerifyPhoneNumberRequest()

          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )

          user.updatePhoneNumber(credential) { rawError in
            XCTAssertTrue(Thread.isMainThread)
            let error = try! XCTUnwrap(rawError)
            XCTAssertEqual((error as NSError).code, AuthErrorCode.invalidPhoneNumber.rawValue)
            XCTAssertEqual(auth.currentUser, user)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testUpdatePhoneNumberFailureAutoSignOut
        @brief Tests the flow of a failed @c updatePhoneNumberCredential:completion: call that
            automatically signs out.
     */
    func testUpdatePhoneNumberFailureAutoSignOut() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        do {
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")
          }
          self.expectVerifyPhoneNumberRequest()

          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )
          user.updatePhoneNumber(credential) { rawError in
            XCTAssertTrue(Thread.isMainThread)
            let error = try! XCTUnwrap(rawError)
            XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
            // User is no longer signed in.
            XCTAssertNil(UserTests.auth?.currentUser)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }
  #endif

  /** @fn testUpdatePasswordSuccess
      @brief Tests the flow of a successful @c updatePassword:completion: call.
   */
  func testUpdatePasswordSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      self.changeUserEmail(user: user, expectation: expectation)
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdatePasswordFailure
      @brief Tests the flow of a failed @c updatePassword:completion: call.
   */
  func testUpdatePasswordFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "CREDENTIAL_TOO_OLD_LOGIN_AGAIN")
        }
        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.requiresRecentLogin.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmptyPasswordFailure
      @brief Tests the flow of a failed @c updatePassword:completion: call due to an empty password.
   */
  func testUpdateEmptyPasswordFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "WEAK_PASSWORD")
        }
        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.weakPassword.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdatePasswordFailureAutoSignOut
      @brief Tests the flow of a failed @c updatePassword:completion: call that automatically signs
          out.
   */
  func testUpdatePasswordFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")
        }
        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userDisabled.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileSuccess
      @brief Tests a successful user profile change flow.
   */
  func testChangeProfileSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken])
        }
        let profileChange = user.createProfileChangeRequest()
        profileChange.photoURL = URL(string: self.kTestPhotoURL)
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertEqual(user.photoURL, URL(string: self.kTestPhotoURL))
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileFailure
      @brief Tests a failed user profile change flow.
   */
  func testChangeProfileFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "TOO_MANY_ATTEMPTS_TRY_LATER")
        }
        let profileChange = user.createProfileChangeRequest()
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.tooManyRequests.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          XCTAssertEqual(user.displayName, self.kDisplayName)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileFailureAutoSignOut
      @brief Tests a failed user profile change flow that automatically signs out.
   */
  func testChangeProfileFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "USER_NOT_FOUND")
        }
        let profileChange = user.createProfileChangeRequest()
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userNotFound.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testGetIDTokenResultSuccess
      @brief Tests the flow of a successful @c getIDTokenResultWithCompletion: call.
   */
  func testGetIDTokenResultSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessToken, forceRefresh: false)
  }

  /** @fn testGetIDTokenResultForcingRefreshSameAccessTokenSuccess
      @brief Tests the flow of a successful @c getIDTokenResultForcingRefresh:completion: call when
          the returned access token is the same as the stored access token.
   */
  func testGetIDTokenResultForcingRefreshSameAccessTokenSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessToken)
  }

  /** @fn testGetIDTokenResultForcingRefreshSuccess
      @brief Tests the flow successful @c getIDTokenResultForcingRefresh:completion: calls.
   */
  func testGetIDTokenResultForcingRefreshSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength415)
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength416)
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength523,
                             emailMatch: "aunitestuser4@gmail.com")
  }

  /** @fn testGetIDTokenResultSuccessWithBase64EncodedURL
      @brief Tests the flow of a successful @c getIDTokenResultWithCompletion: call using a base64 url
          encoded string.
   */
  func testGetIDTokenResultSuccessWithBase64EncodedURL() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenWithBase64,
                             emailMatch: ">>>>>>>>????????@gmail.com",
                             audMatch: "??????????>>>>>>>>>>")
  }

  /** @fn testGetIDTokenResultForcingRefreshFailure
      @brief Tests the flow of a failed @c getIDTokenResultForcingRefresh:completion: call.
   */
  func testGetIDTokenResultForcingRefreshFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser(fakeAccessToken: RPCBaseTests.kFakeAccessToken) { user in
      let underlying = NSError(domain: "Test Error", code: 1)
      self.rpcIssuer?.secureTokenNetworkError =
        AuthErrorUtils.networkError(underlyingError: underlying) as NSError
      user.getIDTokenResult(forcingRefresh: true) { tokenResult, rawError in
        do {
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(tokenResult)
          let error = try XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.networkError.rawValue)
        } catch {
          XCTFail("Caught an error in \(#function): \(error)")
        }
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadSuccess
      @brief Tests the flow of a successful @c reloadWithCompletion: call.
   */
  func testReloadSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      user.reload { error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.email, self.kEmail)
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadFailure
      @brief Tests the flow of a failed @c reloadWithCompletion: call.
   */
  func testReloadFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "QUOTA_EXCEEDED")
        }
        // Clear fake so we can inject error
        self.rpcIssuer?.fakeGetAccountProviderJSON = nil

        user.reload { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.quotaExceeded.rawValue)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadFailureAutoSignOut
      @brief Tests the flow of a failed @c reloadWithCompletion: call that automtatically signs out.
   */
  func testReloadFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")
        }
        // Clear fake so we can inject error
        self.rpcIssuer?.fakeGetAccountProviderJSON = nil

        user.reload { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
          // User is no longer signed in.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateSuccess
      @brief Tests the flow of a successful @c reauthenticateWithCredential:completion: call.
   */
  func testReauthenticateSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken])
        }
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.reauthenticate(with: emailCredential) { rawResult, error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          let result = try! XCTUnwrap(rawResult)
          XCTAssertEqual(result.user.uid, user.uid)
          XCTAssertEqual(result.user.email, user.email)
          XCTAssertEqual(result.additionalUserInfo?.isNewUser, false)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateWithCredentialSuccess
      @brief Tests the flow of a successful @c reauthenticateWithCredential call.
   */
  func testReauthenticateWithCredentialSuccess() throws {
    let expectation = self.expectation(description: #function)
    signInWithGoogleCredential { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken,
                                                 "federatedId": self.kGoogleID,
                                                 "providerId": GoogleAuthProvider.id,
                                                 "localId": self.kLocalID,
                                                 "displayName": self.kGoogleDisplayName,
                                                 "rawUserInfo": self.kGoogleProfile,
                                                 "username": self.kUserName])
        }
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.reauthenticate(with: googleCredential) { reauthenticatedAuthResult, error in
          XCTAssertTrue(Thread.isMainThread)
          do {
            try self.assertUserGoogle(reauthenticatedAuthResult?.user)
          } catch {
            XCTFail("\(error)")
          }
          XCTAssertNil(error)
          // Verify that the current user is unchanged.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          // Verify that the current user and reauthenticated user are not same pointers.
          XCTAssertNotEqual(user, reauthenticatedAuthResult?.user)
          // Verify that anyway the current user and reauthenticated user have same IDs.
          XCTAssertEqual(reauthenticatedAuthResult?.user.uid, user.uid)
          XCTAssertEqual(reauthenticatedAuthResult?.user.email, user.email)
          XCTAssertEqual(reauthenticatedAuthResult?.user.displayName, user.displayName)
          XCTAssertEqual(reauthenticatedAuthResult?.additionalUserInfo?.username, self.kUserName)
          XCTAssertEqual(reauthenticatedAuthResult?.additionalUserInfo?.providerID,
                         GoogleAuthProvider.id)
          XCTAssertEqual(
            reauthenticatedAuthResult?.additionalUserInfo?.profile as? [String: String],
            self.kGoogleProfile
          )
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
    try assertUserGoogle(UserTests.auth?.currentUser)
  }

  /** @fn testReauthenticateFailure
      @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call.
   */
  func testReauthenticateFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken])
        }
        self.setFakeGetAccountProvider(withLocalID: "A different Local ID")
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.reauthenticate(with: emailCredential) { reauthenticatedAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userMismatch.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateUserMismatchFailure
      @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call due to trying
          to reauthenticate a user that does not exist.
   */
  func testReauthenticateUserMismatchFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "USER_NOT_FOUND")
        }
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.reauthenticate(with: googleCredential) { reauthenticatedAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userMismatch.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkAndRetrieveDataSuccess (and old testLinkCredentialSuccess)
      @brief Tests the flow of a successful @c linkWithCredential call.
   */
  func testLinkAndRetrieveDataSuccess() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    let auth = try XCTUnwrap(UserTests.auth)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.setFakeGoogleGetAccountProvider()
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken,
                                                 "federatedId": self.kGoogleID,
                                                 "providerId": GoogleAuthProvider.id,
                                                 "localId": self.kLocalID,
                                                 "displayName": self.kGoogleDisplayName,
                                                 "rawUserInfo": self.kGoogleProfile,
                                                 "username": self.kUserName])
        }
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.link(with: googleCredential) { linkAuthResult, error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          // Verify that the current user is unchanged.
          XCTAssertEqual(auth.currentUser, user)
          // Verify that the current user and reauthenticated user are the same pointers.
          XCTAssertEqual(user, linkAuthResult?.user)
          // Verify that anyway the current user and reauthenticated user have same IDs.
          XCTAssertEqual(linkAuthResult?.user.uid, user.uid)
          XCTAssertEqual(linkAuthResult?.user.email, user.email)
          XCTAssertEqual(linkAuthResult?.user.displayName, user.displayName)
          XCTAssertEqual(linkAuthResult?.additionalUserInfo?.username, self.kUserName)
          XCTAssertEqual(linkAuthResult?.additionalUserInfo?.providerID,
                         GoogleAuthProvider.id)
          XCTAssertEqual(
            linkAuthResult?.additionalUserInfo?.profile as? [String: String],
            self.kGoogleProfile
          )
          XCTAssertEqual(linkAuthResult?.user.providerData.first?.providerID, GoogleAuthProvider.id)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
    try assertUserGoogle(auth.currentUser)
  }

  /** @fn testLinkAndRetrieveDataError
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          call with an error from the backend.
   */
  func testLinkAndRetrieveDataError() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.setFakeGetAccountProvider()
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "CREDENTIAL_TOO_OLD_LOGIN_AGAIN")
        }
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.link(with: googleCredential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.requiresRecentLogin.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kFacebookEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkAndRetrieveDataProviderAlreadyLinked and old testLinkCredentialProviderAlreadyLinkedError
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          call with FIRAuthErrorCodeProviderAlreadyLinked, which is a client side error.
   */
  func testLinkAndRetrieveDataProviderAlreadyLinked() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.setFakeGetAccountProvider()
        let facebookCredential =
          FacebookAuthProvider.credential(withAccessToken: self.kFacebookAccessToken)
        user.link(with: facebookCredential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          do {
            let error = try XCTUnwrap(rawError)
            XCTAssertEqual((error as NSError).code, AuthErrorCode.providerAlreadyLinked.rawValue)
          } catch {
            XCTFail("Expected to throw providerAlreadyLinked error.")
          }
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkAndRetrieveDataErrorAutoSignOut (and old testLinkCredentialError)
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          call that automatically signs out.
   */
  func testLinkAndRetrieveDataErrorAutoSignOut() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.setFakeGetAccountProvider()
        self.rpcIssuer.respondBlock = {
          try self.rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")
        }
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.link(with: googleCredential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userDisabled.rawValue)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkEmailAndRetrieveDataSuccess
      @brief Tests the flow of a successful @c linkWithCredential:completion:
          invocation for email credential.
   */
  func testLinkEmailAndRetrieveDataSuccess() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    let auth = try XCTUnwrap(UserTests.auth)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.rpcIssuer.respondBlock = {
          let request = self.rpcIssuer?.request as? SignUpNewUserRequest
          XCTAssertNotNil(request)
          XCTAssertEqual(request?.email, self.kEmail)
          XCTAssertEqual(request?.password, self.kFakePassword)
          XCTAssertNil(request?.displayName)
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken])
          self.setFakeGetAccountProvider(withProviderID: EmailAuthProvider.id)
        }
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.link(with: emailCredential) { linkAuthResult, error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          // Verify that the current user is unchanged.
          XCTAssertEqual(auth.currentUser, user)
          // Verify that the current user and reauthenticated user are the same pointers.
          XCTAssertEqual(user, linkAuthResult?.user)
          // Verify that anyway the current user and reauthenticated user have same IDs.
          XCTAssertEqual(linkAuthResult?.user.uid, user.uid)
          XCTAssertEqual(linkAuthResult?.user.email, user.email)
          XCTAssertEqual(linkAuthResult?.user.displayName, user.displayName)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn tesLlinkEmailProviderAlreadyLinkedError
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          invocation for email credential and FIRAuthErrorCodeProviderAlreadyLinked which is a client
          side error.
   */
  func testLinkEmailProviderAlreadyLinkedError() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.rpcIssuer.respondBlock = {
          let request = self.rpcIssuer?.request as? SignUpNewUserRequest
          XCTAssertNotNil(request)
          XCTAssertEqual(request?.email, self.kEmail)
          XCTAssertEqual(request?.password, self.kFakePassword)
          try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                 "refreshToken": self.kRefreshToken])
          self.setFakeGetAccountProvider(withProviderID: EmailAuthProvider.id)
        }
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.link(with: emailCredential) { linkAuthResult, error in
          XCTAssertEqual(user, linkAuthResult?.user)
          linkAuthResult?.user.link(with: emailCredential) { linkLinkAuthResult, rawError in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(linkLinkAuthResult)
            do {
              let error = try XCTUnwrap(rawError)
              XCTAssertEqual((error as NSError).code, AuthErrorCode.providerAlreadyLinked.rawValue)
            } catch {
              XCTFail("Expected to throw providerAlreadyLinked error.")
            }
            // User is still signed in.
            XCTAssertEqual(UserTests.auth?.currentUser, user)
            expectation.fulfill()
          }
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkEmailAndRetrieveDataError
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          invocation for email credential and an error from the backend.
   */
  func testLinkEmailAndRetrieveDataError() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.rpcIssuer.respondBlock = {
          let request = self.rpcIssuer?.request as? SignUpNewUserRequest
          XCTAssertNotNil(request)
          XCTAssertEqual(request?.email, self.kEmail)
          XCTAssertEqual(request?.password, self.kFakePassword)
          try self.rpcIssuer?.respond(serverErrorMessage: "TOO_MANY_ATTEMPTS_TRY_LATER")
        }
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.link(with: emailCredential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.tooManyRequests.rawValue)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testLinkEmailAndRetrieveDataErrorAutoSignOut
      @brief Tests the flow of an unsuccessful @c linkWithCredential:completion:
          invocation that automatically signs out.
   */
  func testLinkEmailAndRetrieveDataErrorAutoSignOut() throws {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithFacebookCredential { user in
      XCTAssertNotNil(user)
      do {
        self.rpcIssuer.respondBlock = {
          XCTAssertNotNil(self.rpcIssuer?.request as? SignUpNewUserRequest)
          try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")
        }
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.link(with: emailCredential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if os(iOS)
    private class FakeOAuthProvider: OAuthProvider {
      override func getCredentialWith(_ UIDelegate: AuthUIDelegate?,
                                      completion: ((AuthCredential?, Error?) -> Void)? = nil) {
        if let completion {
          let credential = OAuthCredential(
            withProviderID: GoogleAuthProvider.id,
            sessionID: UserTests.kOAuthSessionID,
            OAuthResponseURLString: UserTests.kOAuthRequestURI
          )
          completion(credential, nil)
        }
      }
    }

    /** @fn testLinkProviderFailure
        @brief Tests the flow of a failed @c linkWithProvider:completion:
            call.
     */
    func testLinkProviderFailure() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithFacebookCredential { user in
        XCTAssertNotNil(user)
        do {
          self.setFakeGetAccountProvider()
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")
          }
          user.link(with: FakeOAuthProvider(providerID: "foo", auth: auth),
                    uiDelegate: nil) { linkAuthResult, rawError in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(linkAuthResult)
            let error = try! XCTUnwrap(rawError)
            XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
            // User is signed out.
            XCTAssertNil(UserTests.auth?.currentUser)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testReauthenticateWithProviderFailure
        @brief Tests the flow of a failed @c reauthenticateWithProvider:completion: call.
     */
    func testReauthenticateWithProviderFailure() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithFacebookCredential { user in
        XCTAssertNotNil(user)
        do {
          self.setFakeGetAccountProvider()
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")
          }
          user.reauthenticate(with: FakeOAuthProvider(providerID: "foo", auth: auth),
                              uiDelegate: nil) { linkAuthResult, rawError in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(linkAuthResult)
            let error = try! XCTUnwrap(rawError)
            XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
            // User is still signed in.
            XCTAssertEqual(UserTests.auth?.currentUser, user)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testLinkPhoneAuthCredentialSuccess
        @brief Tests the flow of a successful @c linkWithCredential call using a phoneAuthCredential.
     */
    func testLinkPhoneAuthCredentialSuccess() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        XCTAssertNotNil(user)
        self.expectVerifyPhoneNumberRequest(isLink: true)
        do {
          self.setFakeGetAccountProvider(withProviderID: PhoneAuthProvider.id)
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                   "refreshToken": self.kRefreshToken])
          }
          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )
          user.link(with: credential) { linkAuthResult, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            // Verify that the current user is unchanged.
            XCTAssertEqual(auth.currentUser, user)
            // Verify that the current user and reauthenticated user are the same pointers.
            XCTAssertEqual(user, linkAuthResult?.user)
            // Verify that anyway the current user and reauthenticated user have same IDs.
            XCTAssertEqual(linkAuthResult?.user.uid, user.uid)
            XCTAssertEqual(linkAuthResult?.user.email, user.email)
            XCTAssertEqual(linkAuthResult?.user.displayName, user.displayName)
            XCTAssertEqual(auth.currentUser?.providerData.first?.providerID, PhoneAuthProvider.id)
            XCTAssertEqual(
              linkAuthResult?.user.providerData.first?.providerID,
              PhoneAuthProvider.id
            )
            XCTAssertEqual(auth.currentUser?.phoneNumber, self.kTestPhoneNumber)
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testUnlinkPhoneAuthCredentialSuccess
        @brief Tests the flow of a successful @c unlinkFromProvider:completion: call using a
            @c FIRPhoneAuthProvider.
     */
    func testUnlinkPhoneAuthCredentialSuccess() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        XCTAssertNotNil(user)
        self.expectVerifyPhoneNumberRequest(isLink: true)
        do {
          self.setFakeGetAccountProvider(withProviderID: PhoneAuthProvider.id)
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                   "refreshToken": self.kRefreshToken])
          }
          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )
          user.link(with: credential) { linkAuthResult, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            // Verify that the current user is unchanged.
            XCTAssertEqual(auth.currentUser, user)
            // Verify that the current user and reauthenticated user are the same pointers.
            XCTAssertEqual(user, linkAuthResult?.user)
            // Verify that anyway the current user and reauthenticated user have same IDs.
            XCTAssertEqual(linkAuthResult?.user.uid, user.uid)
            XCTAssertEqual(linkAuthResult?.user.email, user.email)
            XCTAssertEqual(linkAuthResult?.user.displayName, user.displayName)
            XCTAssertEqual(auth.currentUser?.providerData.first?.providerID, PhoneAuthProvider.id)
            XCTAssertEqual(
              linkAuthResult?.user.providerData.first?.providerID,
              PhoneAuthProvider.id
            )
            XCTAssertEqual(auth.currentUser?.phoneNumber, self.kTestPhoneNumber)

            // Immediately unlink the phone auth provider.
            self.rpcIssuer.respondBlock = {
              let request = try XCTUnwrap(self.rpcIssuer?.request as? SetAccountInfoRequest)
              XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
              XCTAssertEqual(request.accessToken, RPCBaseTests.kFakeAccessToken)
              XCTAssertNil(request.email)
              XCTAssertNil(request.password)
              XCTAssertNil(request.localID)
              XCTAssertNil(request.displayName)
              XCTAssertNil(request.photoURL)
              XCTAssertNil(request.providers)
              XCTAssertNil(request.deleteAttributes)
              XCTAssertEqual(try XCTUnwrap(request.deleteProviders?.first), PhoneAuthProvider.id)
              try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                     "refreshToken": self.kRefreshToken])
            }
            user.unlink(fromProvider: PhoneAuthProvider.id) { user, error in
              XCTAssertNil(error)
              XCTAssertEqual(auth.currentUser, user)
              XCTAssertNil(auth.currentUser?.phoneNumber)
              expectation.fulfill()
            }
          }
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testlinkPhoneAuthCredentialFailure
        @brief Tests the flow of a failed call to @c linkWithCredential:completion: due
            to a phone provider already being linked.
     */
    func testlinkPhoneAuthCredentialFailure() throws {
      setFakeGetAccountProvider(withPasswordHash: kFakePassword)
      let expectation = self.expectation(description: #function)
      signInWithEmailPasswordReturnFakeUser { user in
        XCTAssertNotNil(user)
        self.expectVerifyPhoneNumberRequest(isLink: true)
        self.setFakeGetAccountProvider(withProviderID: PhoneAuthProvider.id)

        let credential = EmailAuthCredential(withEmail: self.kEmail, password: self.kFakePassword)

        user.link(with: credential) { linkAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(linkAuthResult)
          if let error = try? XCTUnwrap(rawError) {
            XCTAssertEqual((error as NSError).code, AuthErrorCode.providerAlreadyLinked.rawValue)
          } else {
            XCTFail("Did not throw expected error")
          }
          expectation.fulfill()
        }
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testlinkPhoneCredentialAlreadyExistsError
        @brief Tests the flow of @c linkWithCredential:completion:
            call using a phoneAuthCredential and a credential already exists error. In this case we
            should get a AuthCredential in the error object.
     */
    func testlinkPhoneCredentialAlreadyExistsError() throws {
      setFakeGetAccountProvider()
      let expectation = self.expectation(description: #function)
      let auth = try XCTUnwrap(UserTests.auth)
      signInWithEmailPasswordReturnFakeUser { user in
        XCTAssertNotNil(user)
        self.expectVerifyPhoneNumberRequest(isLink: true)
        do {
          self.setFakeGetAccountProvider(withProviderID: PhoneAuthProvider.id)
          self.rpcIssuer.respondBlock = {
            try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                                   "refreshToken": self.kRefreshToken,
                                                   "phoneNumber": self.kTestPhoneNumber,
                                                   "temporaryProof": "Fake Temporary Proof"])
          }
          let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: self.kVerificationID,
            verificationCode: self.kVerificationCode
          )
          user.link(with: credential) { linkAuthResult, rawError in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(linkAuthResult)
            do {
              let error = try XCTUnwrap(rawError)
              XCTAssertEqual((error as NSError).code, AuthErrorCode.credentialAlreadyInUse.rawValue)
              let credential = try XCTUnwrap((error as NSError)
                .userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? PhoneAuthCredential)
              switch credential.credentialKind {
              case let .phoneNumber(phoneNumber, temporaryProof):
                XCTAssertEqual(temporaryProof, "Fake Temporary Proof")
                XCTAssertEqual(phoneNumber, self.kTestPhoneNumber)
              case .verification: XCTFail("Should be phoneNumber case")
              }
            } catch {
              XCTFail("Did not throw expected error \(error)")
            }
            expectation.fulfill()
          }
        }
      }
      waitForExpectations(timeout: 5)
    }
  #endif

  // MARK: Private helper functions

  private func expectVerifyPhoneNumberRequest(isLink: Bool = false) {
    rpcIssuer?.verifyPhoneNumberRequester = { request in
      XCTAssertEqual(request.verificationID, self.kVerificationID)
      XCTAssertEqual(request.verificationCode, self.kVerificationCode)
      XCTAssertEqual(request.accessToken, RPCBaseTests.kFakeAccessToken)
      if isLink {
        XCTAssertEqual(request.operation, AuthOperationType.link)
      } else {
        XCTAssertEqual(request.operation, AuthOperationType.update)
      }
    }
  }

  private func internalGetIDTokenResult(token: String, forceRefresh: Bool = true,
                                        emailMatch: String = "aunitestuser@gmail.com",
                                        audMatch: String = "test_aud") {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser(fakeAccessToken: token) { user in
      user.getIDTokenResult(forcingRefresh: forceRefresh) { rawTokenResult, error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.email, self.kEmail)
        let tokenResult = try! XCTUnwrap(rawTokenResult)
        XCTAssertEqual(tokenResult.token, token)
        XCTAssertNotNil(tokenResult.issuedAtDate)
        XCTAssertNotNil(tokenResult.authDate)
        XCTAssertNotNil(tokenResult.expirationDate)
        XCTAssertNotNil(tokenResult.signInProvider)

        // The lowercased is for the base64 test which seems to be an erroneously uppercased
        // "Password"?
        XCTAssertEqual(tokenResult.signInProvider.lowercased(), EmailAuthProvider.id)
        XCTAssertEqual(tokenResult.claims["email"] as! String, emailMatch)
        XCTAssertEqual(tokenResult.claims["aud"] as! String, audMatch)
        XCTAssertEqual(tokenResult.signInSecondFactor, "")
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  private func changeUserEmail(user: User, changeEmail: Bool = false,
                               expectation: XCTestExpectation) {
    do {
      XCTAssertEqual(user.providerID, "Firebase")
      XCTAssertEqual(user.uid, kLocalID)
      XCTAssertEqual(user.displayName, kDisplayName)
      XCTAssertEqual(user.photoURL, URL(string: kTestPhotoURL))
      XCTAssertEqual(user.email, kEmail)

      // Pretend that the display name on the server has been changed since the original signin.
      setFakeGetAccountProvider(withNewDisplayName: kNewDisplayName)

      rpcIssuer.respondBlock = {
        let request = try XCTUnwrap(self.rpcIssuer?.request as? SetAccountInfoRequest)
        XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
        XCTAssertEqual(request.accessToken, RPCBaseTests.kFakeAccessToken)
        if changeEmail {
          XCTAssertEqual(request.email, self.kNewEmail)
          XCTAssertNil(request.password)
        } else {
          XCTAssertEqual(request.password, self.kNewPassword)
          XCTAssertNil(request.email)
        }
        XCTAssertNil(request.localID)
        XCTAssertNil(request.displayName)
        XCTAssertNil(request.photoURL)
        XCTAssertNil(request.providers)
        XCTAssertNil(request.deleteAttributes)
        XCTAssertNil(request.deleteProviders)

        try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                               "email": self.kNewEmail,
                                               "refreshToken": self.kRefreshToken])
      }
      if changeEmail {
        user.updateEmail(to: kNewEmail) { error in
          XCTAssertNil(error)
          XCTAssertEqual(user.email, self.kNewEmail)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertFalse(user.isAnonymous)
          expectation.fulfill()
        }
      } else {
        user.updatePassword(to: kNewPassword) { error in
          XCTAssertNil(error)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertFalse(user.isAnonymous)
          expectation.fulfill()
        }
      }
    }
  }

  private func signInWithEmailPasswordReturnFakeUser(fakeAccessToken: String = RPCBaseTests
    .kFakeAccessToken,
    completion: @escaping (User) -> Void) {
    let kRefreshToken = "fakeRefreshToken"
    setFakeSecureTokenService(fakeAccessToken: fakeAccessToken)

    rpcIssuer?.verifyPasswordRequester = { request in
      // 2. Validate the created Request instance.
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.password, self.kFakePassword)
      XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)
      do {
        // 3. Send the response from the fake backend.
        try self.rpcIssuer?.respond(withJSON: ["idToken": fakeAccessToken,
                                               "isNewUser": true,
                                               "refreshToken": kRefreshToken])
      } catch {
        XCTFail("Failure sending response: \(error)")
      }
    }
    // 1. After setting up fakes, sign out and sign in.
    do {
      try UserTests.auth?.signOut()
    } catch {
      XCTFail("Sign out failed: \(error)")
      return
    }
    UserTests.auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      guard let additionalUserInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertFalse(additionalUserInfo.isNewUser)
      XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
      XCTAssertNil(error)
      // Clear the password Requester to avoid being called again by reauthenticate tests.
      self.rpcIssuer?.verifyPasswordRequester = nil
      completion(user)
    }
  }

  private func signInWithGoogleCredential(completion: @escaping (User) -> Void) {
    setFakeSecureTokenService(fakeAccessToken: RPCBaseTests.kFakeAccessToken)
    setFakeGoogleGetAccountProvider()

    rpcIssuer.respondBlock = {
      try self.verifyGoogleAssertionRequest(
        XCTUnwrap(self.rpcIssuer?.request as? VerifyAssertionRequest)
      )

      // 3. Send the response from the fake backend.
      try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                             "providerId": GoogleAuthProvider.id,
                                             "refreshToken": self.kRefreshToken,
                                             "localId": self.kLocalID,
                                             "displayName": self.kDisplayName,
                                             "rawUserInfo": self.kGoogleProfile,
                                             "username": self.kUserName])
    }

    do {
      try UserTests.auth?.signOut()
      let googleCredential = GoogleAuthProvider.credential(withIDToken: kGoogleIDToken,
                                                           accessToken: kGoogleAccessToken)
      UserTests.auth?.signIn(with: googleCredential) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user else {
          XCTFail("authResult.user is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.email, self.kGoogleEmail)
        guard let additionalUserInfo = authResult?.additionalUserInfo,
              let profile = additionalUserInfo.profile as? [String: String] else {
          XCTFail("authResult.additionalUserInfo and/or profile is missing")
          return
        }
        XCTAssertEqual(profile, self.kGoogleProfile)
        XCTAssertFalse(additionalUserInfo.isNewUser)
        XCTAssertEqual(additionalUserInfo.providerID, GoogleAuthProvider.id)
        XCTAssertEqual(additionalUserInfo.username, self.kUserName)
        XCTAssertNil(error)
        completion(user)
      }
    } catch {
      XCTFail("Throw in \(#function): \(error)")
    }
  }

  private func verifyGoogleAssertionRequest(_ request: VerifyAssertionRequest) {
    XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
    XCTAssertEqual(request.providerIDToken, kGoogleIDToken)
    XCTAssertEqual(request.providerAccessToken, kGoogleAccessToken)
    XCTAssertTrue(request.returnSecureToken)
    XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
    XCTAssertTrue(request.returnSecureToken)
  }

  private func signInWithFacebookCredential(completion: @escaping (User) -> Void) {
    setFakeSecureTokenService(fakeAccessToken: RPCBaseTests.kFakeAccessToken)
    setFakeGetAccountProvider(withNewDisplayName: kFacebookDisplayName,
                              withProviderID: FacebookAuthProvider.id,
                              withFederatedID: kFacebookID,
                              withEmail: kFacebookEmail)

    rpcIssuer.respondBlock = {
      let request = try XCTUnwrap(self.rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.providerID, FacebookAuthProvider.id)
      XCTAssertEqual(request.providerIDToken, self.kFacebookIDToken)
      XCTAssertEqual(request.providerAccessToken, self.kFacebookAccessToken)
      XCTAssertTrue(request.returnSecureToken)
      XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                             "refreshToken": self.kRefreshToken,
                                             "federatedId": self.kFacebookID,
                                             "providerId": FacebookAuthProvider.id,
                                             "localId": self.kLocalID,
                                             "displayName": self.kDisplayName,
                                             "rawUserInfo": self.kGoogleProfile,
                                             "username": self.kUserName])
    }

    do {
      try UserTests.auth?.signOut()
      let facebookCredential = FacebookAuthProvider
        .credential(withAccessToken: kFacebookAccessToken)
      UserTests.auth?.signIn(with: facebookCredential) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user else {
          XCTFail("authResult.user is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.email, self.kFacebookEmail)
        XCTAssertEqual(user.displayName, self.kFacebookDisplayName)
        XCTAssertEqual(user.providerData.count, 1)
        guard let additionalUserInfo = authResult?.additionalUserInfo,
              let facebookUserInfo = user.providerData.first,
              let profile = additionalUserInfo.profile as? [String: String] else {
          XCTFail("authResult.additionalUserInfo and/or profile is missing")
          return
        }
        XCTAssertEqual(facebookUserInfo.providerID, FacebookAuthProvider.id)
        XCTAssertEqual(facebookUserInfo.uid, self.kFacebookID)
        XCTAssertEqual(facebookUserInfo.displayName, self.kFacebookDisplayName)
        XCTAssertEqual(facebookUserInfo.email, self.kFacebookEmail)
        XCTAssertEqual(profile, self.kGoogleProfile)
        XCTAssertFalse(additionalUserInfo.isNewUser)
        XCTAssertEqual(additionalUserInfo.providerID, FacebookAuthProvider.id)
        XCTAssertEqual(additionalUserInfo.username, self.kUserName)
        XCTAssertNil(error)
        completion(user)
      }
    } catch {
      XCTFail("Throw in \(#function): \(error)")
    }
  }

  private func signInWithEmailPasswordReturnFakeUserLink(completion: @escaping (User) -> Void) {
    let kRefreshToken = "fakeRefreshToken"
    setFakeSecureTokenService()

    rpcIssuer.respondBlock = {
      let request = try XCTUnwrap(self.rpcIssuer?.request as? EmailLinkSignInRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.apiKey, UserTests.kFakeAPIKey)
      XCTAssertEqual(request.oobCode, "aCode")
      XCTAssertNil(request.idToken)

      // Send the response from the fake backend.
      try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                             "isNewUser": true,
                                             "refreshToken": kRefreshToken])
    }

    do {
      try UserTests.auth?.signOut()
      UserTests.auth?.signIn(
        withEmail: kEmail,
        link: "https://www.google.com?oobCode=aCode&mode=signIn"
      ) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user else {
          XCTFail("authResult.user is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.email, self.kEmail)
        guard let additionalUserInfo = authResult?.additionalUserInfo else {
          XCTFail("authResult.additionalUserInfo is missing")
          return
        }
        XCTAssertTrue(additionalUserInfo.isNewUser)
        XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
        XCTAssertNil(error)
        completion(user)
      }
    } catch {
      XCTFail("Throw in \(#function): \(error)")
    }
  }
}
