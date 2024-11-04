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

import Foundation
import XCTest

@testable import FirebaseAuth

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RPCBaseTests: XCTestCase {
  let kEmail = "user@company.com"
  let kFakePassword = "!@#$%^"
  let kDisplayName = "User Doe"
  let kLocalID = "testLocalId"
  let kFakeOobCode = "fakeOobCode"
  let kRefreshToken = "fakeRefreshToken"
  let kCustomToken = "CUSTOM_TOKEN"
  let kFakeEmailSignInLink = "https://test.app.goo.gl/?link=https://test.firebase" +
    "app.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueU" +
    "rl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/" +
    "action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://" +
    "test.apps.com"
  let kFakeEmailSignInDeeplink =
    "https://example.domain.com/?apiKey=testAPIKey&oobCode=testoobcode&mode=signIn"
  let kContinueURL = "continueURL"
  let kIosBundleID = "testBundleID"
  let kAndroidPackageName = "androidpackagename"
  let kAndroidMinimumVersion = "3.0"
  let kDynamicLinkDomain = "test.page.link"
  let kTestPhotoURL = "https://host.domain/image"
  let kCreationDateTimeIntervalInSeconds = 1_505_858_500.0
  let kLastSignInDateTimeIntervalInSeconds = 1_505_858_583.0
  let kTestPhoneNumber = "415-555-1234"
  static let kOAuthSessionID = "sessionID"
  static let kOAuthRequestURI = "requestURI"
  let kGoogleIDToken = "GOOGLE_ID_TOKEN"
  let kGoogleAccessToken = "GOOGLE_ACCESS_TOKEN"
  let kGoogleID = "GOOGLE_ID"
  let kGoogleEmail = "usergmail.com"
  let kGoogleDisplayName = "Google Doe"
  let kGoogleProfile = ["email": "usergmail.com", "given_name": "MyFirst", "family_name": "MyLast"]
  let kUserName = "User Doe"

  /** @var kTestAPIKey
      @brief Fake API key used for testing.
   */
  let kTestAPIKey = "APIKey"

  /** @var kTestFirebaseAppID
      @brief Fake Firebase app ID used for testing.
   */
  let kTestFirebaseAppID = "appID"

  /** @var kTestIdentifier
      @brief Fake identifier key used for testing.
   */
  let kTestIdentifier = "Identifier"

  var rpcIssuer: FakeBackendRPCIssuer!

  override func setUp() {
    rpcIssuer = FakeBackendRPCIssuer()
    AuthBackend.setTestRPCIssuer(issuer: rpcIssuer)
  }

  override func tearDown() {
    rpcIssuer = nil
    AuthBackend.resetRPCIssuer()
  }

  /** @fn checkRequest
      @brief Tests the encoding of a request.
   */
  func checkRequest(request: any AuthRPCRequest,
                    expected: String,
                    key: String,
                    value: String?,
                    checkPostBody: Bool = false) async throws {
    rpcIssuer.respondBlock = {
      XCTAssertEqual(self.rpcIssuer.requestURL?.absoluteString, expected)
      if checkPostBody {
        XCTAssertFalse(request.containsPostBody)
      } else if let requestDictionary = self.rpcIssuer.decodedRequest as? [String: AnyHashable] {
        XCTAssertEqual(requestDictionary[key], value)
      } else {
        XCTFail("decodedRequest is not a dictionary")
      }
      // Dummy response to unblock await.
      let _ = try self.rpcIssuer?.respond(withJSON: [:])
    }
    let _ = try await AuthBackend.call(with: request)
  }

  /** @fn checkBackendError
      @brief This test checks error messages from the backend map to the expected error codes
   */
  func checkBackendError(request: any AuthRPCRequest,
                         message: String = "",
                         reason: String? = nil,
                         json: [String: AnyHashable]? = nil,
                         errorCode: AuthErrorCode,
                         errorReason: String? = nil,
                         underlyingErrorKey: String? = nil,
                         checkLocalizedDescription: String? = nil) async throws {
    rpcIssuer.respondBlock = {
      if let json = json {
        _ = try self.rpcIssuer.respond(withJSON: json)
      } else if let reason = reason {
        _ = try self.rpcIssuer.respond(underlyingErrorMessage: reason, message: message)
      } else {
        _ = try self.rpcIssuer.respond(serverErrorMessage: message)
      }
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Did not throw expected error")
      return
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.code, errorCode.rawValue)
      if errorCode == .internalError {
        let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
        XCTAssertNotNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      }
      if let errorReason {
        XCTAssertEqual(errorReason, rpcError.userInfo[NSLocalizedFailureReasonErrorKey] as? String)
      }
      if let checkLocalizedDescription {
        let localizedDescription = try XCTUnwrap(rpcError
          .userInfo[NSLocalizedDescriptionKey] as? String)
        XCTAssertEqual(checkLocalizedDescription, localizedDescription)
      }
    }
  }

  func makeRequestConfiguration() -> AuthRequestConfiguration {
    return AuthRequestConfiguration(
      apiKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
  }

  static let kFakeAccessToken =
    "eyJhbGciOimnuzI1NiIsImtpZCI6ImY1YjE4Mjc2YTQ4NjYxZDBhODBiYzh" +
    "jM2U5NDM0OTc0ZDFmMWRiNTEifQ." +
    "eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZmItc2EtdXBncm" +
    "FkZWQiLCJhdWQiOiJ0ZXN0X2F1ZCIsImF1dGhfdGltZSI6MTUyMjM2MDU0OSwidXNlcl9pZCI6InRlc3RfdXNlcl9pZCIs" +
    "InN1YiI6InRlc3Rfc3ViIiwiaWF0IjoxNTIyMzYwNTU3LCJleHAiOjE1MjIzNjQxNTcsImVtYWlsIjoiYXVuaXRlc3R1c2" +
    "VyQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6" +
    "WyJhdW5pdGVzdHVzZXJAZ21haWwuY29tIl19LCJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0=." +
    "WFQqSrpVnxx7m" +
    "UrdKZA517Sp4ZBt-l2xQzGKNMVE90JB3vuNa-NyWZC-aTYMvND3-4aS3qRnN2kvk9KJAaF3eI_" +
    "BKkcbZuq8O7iDVpOvqKC" +
    "3QcW0PnwqSPChL3XqoDF322FcBEgemwwgaEVZMuo7GhJvHw-" +
    "XtBt1KRXOoGHcr3P6RsvoulUouKQmqt6TP27eZtrgH7jjN" +
    "hHm7gjX_WaRmgTOvYsuDbBBGdE15yIVZ3acI4cFUgwMRhaW-" +
    "dDV7jTOqZGYJlTsI5oRMehphoVnYnEedJga28r4mqVkPbW" +
    "lddL4dVVm85FYmQcRc0b2CLMnSevBDlwu754ZUZmRgnuvDA"

  static let kFakeAccessTokenLength415 =
    "eyJhbGciOimnuzI1NiIsImtpZCI6ImY1YjE4Mjc2YTQ4NjYxZD" +
    "BhODBiYzhjM2U5NDM0OTc0ZDFmMWRiNTEifQ." +
    "eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vdGVzd" +
    "CIsImF1ZCI6InRlc3RfYXVkIiwiYXV0aF90aW1lIjoxNTIyMzYwNTQ5LCJ1c2VyX2lkIjoidGVzdF91c2VyX2lkIiwic3V" +
    "iIjoidGVzdF9zdWIiLCJpYXQiOjE1MjIzNjA1NTcsImV4cCI6MTUyMjM2NDE1NywiZW1haWwiOiJhdW5pdGVzdHVzZXJAZ" +
    "21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7ImVtYWlsIjpbImF" +
    "1bml0ZXN0dXNlckBnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ=.WFQqSrpVnxx7m" +
    "UrdKZA517Sp4ZBt-l2xQzGKNMVE90JB3vuNa-NyWZC-aTYMvND3-4aS3qRnN2kvk9KJAaF3eI_" +
    "BKkcbZuq8O7iDVpOvqKC" +
    "3QcW0PnwqSPChL3XqoDF322FcBEgemwwgaEVZMuo7GhJvHw-" +
    "XtBt1KRXOoGHcr3P6RsvoulUouKQmqt6TP27eZtrgH7jjN" +
    "hHm7gjX_WaRmgTOvYsuDbBBGdE15yIVZ3acI4cFUgwMRhaW-" +
    "dDV7jTOqZGYJlTsI5oRMehphoVnYnEedJga28r4mqVkPbW" +
    "lddL4dVVm85FYmQcRc0b2CLMnSevBDlwu754ZUZmRgnuvDA"

  static let kFakeAccessTokenLength416 =
    "eyJhbGciOimnuzI1NiIsImtpZCI6ImY1YjE4Mjc2YTQ4NjYxZD" +
    "BhODBiYzhjM2U5NDM0OTc0ZDFmMWRiNTEifQ." +
    "eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vdGVzd" +
    "DIiLCJhdWQiOiJ0ZXN0X2F1ZCIsImF1dGhfdGltZSI6MTUyMjM2MDU0OSwidXNlcl9pZCI6InRlc3RfdXNlcl9pZCIsInN" +
    "1YiI6InRlc3Rfc3ViIiwiaWF0IjoxNTIyMzYwNTU3LCJleHAiOjE1MjIzNjQxNTcsImVtYWlsIjoiYXVuaXRlc3R1c2VyQ" +
    "GdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJ" +
    "hdW5pdGVzdHVzZXJAZ21haWwuY29tIl19LCJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0=.WFQqSrpVnxx7m" +
    "UrdKZA517Sp4ZBt-l2xQzGKNMVE90JB3vuNa-NyWZC-aTYMvND3-4aS3qRnN2kvk9KJAaF3eI_" +
    "BKkcbZuq8O7iDVpOvqKC" +
    "3QcW0PnwqSPChL3XqoDF322FcBEgemwwgaEVZMuo7GhJvHw-" +
    "XtBt1KRXOoGHcr3P6RsvoulUouKQmqt6TP27eZtrgH7jjN" +
    "hHm7gjX_WaRmgTOvYsuDbBBGdE15yIVZ3acI4cFUgwMRhaW-" +
    "dDV7jTOqZGYJlTsI5oRMehphoVnYnEedJga28r4mqVkPbW" +
    "lddL4dVVm85FYmQcRc0b2CLMnSevBDlwu754ZUZmRgnuvDA"

  static let kFakeAccessTokenLength523 =
    "eyJhbGciOimnuzI1NiIsImtpZCI6ImY1YjE4Mjc2YTQ4NjYxZD" +
    "BhODBiYzhjM2U5NDM0OTc0ZDFmMWRiNTEifQ." +
    "eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vdGVzd" +
    "DQiLCJhdWQiOiJ0ZXN0X2F1ZCIsImF1dGhfdGltZSI6MTUyMjM2MDU0OSwidXNlcl9pZCI6InRlc3RfdXNlcl9pZF81NDM" +
    "yIiwic3ViIjoidGVzdF9zdWIiLCJpYXQiOjE1MjIzNjA1NTcsImV4cCI6MTUyMjM2NDE1OSwiZW1haWwiOiJhdW5pdGVzd" +
    "HVzZXI0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7ImVtYWl" +
    "sIjpbImF1bml0ZXN0dXNlckBnbWFpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ=." +
    "WFQqSrpVn" +
    "xx7mUrdKZA517Sp4ZBt-l2xQzGKNMVE90JB3vuNa-NyWZC-aTYMvND3-4aS3qRnN2kvk9KJAaF3eI_" +
    "BKkcbZuq8O7iDVpO" +
    "vqKC3QcW0PnwqSPChL3XqoDF322FcBEgemwwgaEVZMuo7GhJvHw-" +
    "XtBt1KRXOoGHcr3P6RsvoulUouKQmqt6TP27eZtrgH" +
    "7jjNhHm7gjX_WaRmgTOvYsuDbBBGdE15yIVZ3acI4cFUgwMRhaW-" +
    "dDV7jTOqZGYJlTsI5oRMehphoVnYnEedJga28r4mqV" +
    "kPbWlddL4dVVm85FYmQcRc0b2CLMnSevBDlwu754ZUZmRgnuvDA"

  static let kFakeAccessTokenWithBase64 =
    "ey?hbGciOimnuzI1NiIsImtpZCI6ImY1YjE4M" +
    "jc2YTQ4NjYxZDBhODBiYzhjM2U5NDM0OTc0ZDFmMWRiNTEifQ." +
    "eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2ds" +
    "ZS5jb20vZmItc2EtdXBncmFkZWQiLCJhdWQiOiI_Pz8_Pz8_Pz8_Pj4-Pj4-Pj4-" +
    "PiIsImF1dGhfdGltZSI6MTUyMjM2MD" +
    "U0OSwidXNlcl9pZCI6InRlc3RfdXNlcl9pZCIsInN1YiI6InRlc3Rfc3ViIiwiaWF0IjoxNTIyMzYwNTU3LCJleHAiOjE1" +
    "MjIzNjQxNTcsImVtYWlsIjoiPj4-Pj4-Pj4_Pz8_Pz8_" +
    "P0BnbWFpbC5jb20iLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsIm" +
    "ZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZW1haWwiOlsiYXVuaXRlc3R1c2VyQGdtYWlsLmNvbSJdfSwic2lnbl9pbl9w" +
    "cm92aWRlciI6IlBhc3N3b3JkIn19.WFQqSrpVnxx7mUrdKZA517Sp4ZBt-l2xQzGKNMVE90JB3vuNa-NyWZC-" +
    "aTYMvND3-" +
    "4aS3qRnN2kvk9KJAaF3eI_BKkcbZuq8O7iDVpOvqKC3QcW0PnwqSPChL3XqoDF322FcBEgemwwgaEVZMuo7GhJvHw-" +
    "XtBt" +
    "1KRXOoGHcr3P6RsvoulUouKQmqt6TP27eZtrgH7jjNhHm7gjX_WaRmgTOvYsuDbBBGdE15yIVZ3acI4cFUgwMRhaW-" +
    "dDV7" +
    "jTOqZGYJlTsI5oRMehphoVnYnEedJga28r4mqVkPbWlddL4dVVm85FYmQcRc0b2CLMnSevBDlwu754ZUZmRgnuvDA"

  func setFakeSecureTokenService(fakeAccessToken: String = RPCBaseTests.kFakeAccessToken) {
    rpcIssuer?.fakeSecureTokenServiceJSON = ["access_token": fakeAccessToken,
                                             "expires_in": "3600"]
  }

  func setFakeGetAccountProvider(withNewDisplayName displayName: String = "User Doe",
                                 withLocalID localID: String = "testLocalId",
                                 withProviderID providerID: String = "testProviderID",
                                 withFederatedID federatedID: String = "testFederatedId",
                                 withEmail email: String = "user@company.com",
                                 withPasswordHash passwordHash: String? = nil) {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = passwordHash
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: [[
        kProviderIDkey: providerID,
        kDisplayNameKey: displayName,
        kPhotoUrlKey: kTestPhotoURL,
        kFederatedIDKey: federatedID,
        kEmailKey: email,
      ]],
      kLocalIDKey: localID,
      kDisplayNameKey: displayName,
      kEmailKey: email,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
      "phoneNumber": kTestPhoneNumber,
    ]]
  }

  func setFakeGoogleGetAccountProvider() {
    setFakeGetAccountProvider(withNewDisplayName: kGoogleDisplayName,
                              withProviderID: GoogleAuthProvider.id,
                              withFederatedID: kGoogleID,
                              withEmail: kGoogleEmail)
  }

  func setFakeGetAccountProviderAnonymous() {
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kLocalIDKey: kLocalID,
      kPasswordHashKey: kTestPasswordHash,
    ]]
  }

  func fakeActionCodeSettings() -> ActionCodeSettings {
    let settings = ActionCodeSettings()
    settings.iOSBundleID = kIosBundleID
    settings.setAndroidPackageName(kAndroidPackageName,
                                   installIfNotAvailable: true,
                                   minimumVersion: kAndroidMinimumVersion)
    settings.handleCodeInApp = true
    settings.url = URL(string: kContinueURL)
    settings.dynamicLinkDomain = kDynamicLinkDomain
    return settings
  }

  func assertUserGoogle(_ user: User?) throws {
    let user = try XCTUnwrap(user)
    XCTAssertEqual(user.uid, kLocalID)
    XCTAssertEqual(user.displayName, kGoogleDisplayName)
    XCTAssertEqual(user.providerData.count, 1)
    let googleUserInfo = user.providerData[0]
    XCTAssertEqual(googleUserInfo.providerID, GoogleAuthProvider.id)
    XCTAssertEqual(googleUserInfo.uid, kGoogleID)
    XCTAssertEqual(googleUserInfo.displayName, kGoogleDisplayName)
    XCTAssertEqual(googleUserInfo.email, kGoogleEmail)
  }

  /// Sleep long enough for pending async task to start.
  static func waitSleep() {
    usleep(10000)
  }
}
