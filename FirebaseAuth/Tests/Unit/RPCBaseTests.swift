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

class RPCBaseTests: XCTestCase {
  let kEmail = "user@company.com"
  let kFakePassword = "!@#$%^"
  let kDisplayName = "Google Doe"
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
  let kAndroidPackageName = "adroidpackagename"
  let kAndroidMinimumVersion = "3.0"
  let kDynamicLinkDomain = "test.page.link"
  let kTestPhotoURL = "https://host.domain/image"
  let kCreationDateTimeIntervalInSeconds = 1_505_858_500.0
  let kLastSignInDateTimeIntervalInSeconds = 1_505_858_583.0

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

  var rpcIssuer: FakeBackendRPCIssuer?
  var rpcImplementation: AuthBackendImplementation?

  override func setUp() {
    rpcIssuer = FakeBackendRPCIssuer()
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: rpcIssuer)
    rpcImplementation = AuthBackend.implementation()
  }

  override func tearDown() {
    rpcIssuer = nil
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: nil)
  }

  /** @fn checkRequest
      @brief Tests the encoding of a request.
   */
  @discardableResult func checkRequest(request: AuthRPCRequest,
                                       expected: String,
                                       key: String,
                                       value: String?,
                                       checkPostBody: Bool = false) throws -> FakeBackendRPCIssuer {
    AuthBackend.post(withRequest: request) { response, error in
      XCTFail("No explicit response from the fake backend.")
    }
    let rpcIssuer = try XCTUnwrap(rpcIssuer)
    XCTAssertEqual(rpcIssuer.requestURL?.absoluteString, expected)
    if checkPostBody,
       let containsPostBody = request.containsPostBody?() {
      XCTAssertFalse(containsPostBody)
    } else if let requestDictionary = rpcIssuer.decodedRequest as? [String: AnyHashable] {
      XCTAssertEqual(requestDictionary[key], value)
    } else {
      XCTFail("decodedRequest is not a dictionary")
    }
    return rpcIssuer
  }

  /** @fn checkBackendError
      @brief This test checks error messagess from the backend map to the expected error codes
   */
  func checkBackendError(request: AuthRPCRequest,
                         message: String = "",
                         reason: String? = nil,
                         json: [String: AnyHashable]? = nil,
                         errorCode: AuthErrorCode,
                         errorReason: String? = nil,
                         underlyingErrorKey: String? = nil,
                         checkLocalizedDescription: String? = nil) throws {
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    if let json = json {
      _ = try rpcIssuer?.respond(withJSON: json)
    } else if let reason = reason {
      _ = try rpcIssuer?.respond(underlyingErrorMessage: reason, message: message)
    } else {
      _ = try rpcIssuer?.respond(serverErrorMessage: message)
    }

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.code, errorCode.rawValue)
    if errorCode == .internalError {
      let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertNotNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    }
    if let errorReason {
      XCTAssertEqual(errorReason, rpcError?.userInfo[NSLocalizedFailureReasonErrorKey] as? String)
    }
    if let checkLocalizedDescription {
      let localizedDescription = try XCTUnwrap(rpcError?
        .userInfo[NSLocalizedDescriptionKey] as? String)
      XCTAssertEqual(checkLocalizedDescription, localizedDescription)
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
    rpcIssuer?.fakeSecureTokenServiceJSON = ["access_token": fakeAccessToken]
  }

  func setFakeGetAccountProvider(withNewDisplayName displayName: String = "Google Doe") {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kTestFederatedID = "testFederatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kTestProviderID = "testProviderID"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: [[
        kProviderIDkey: kTestProviderID,
        kDisplayNameKey: kDisplayName,
        kPhotoUrlKey: kTestPhotoURL,
        kFederatedIDKey: kTestFederatedID,
        kEmailKey: kEmail,
      ]],
      kLocalIDKey: kLocalID,
      kDisplayNameKey: displayName,
      kEmailKey: kEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
    ]]
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

  func createGroup() -> DispatchGroup {
    let group = DispatchGroup()
    rpcIssuer?.group = group
    group.enter()
    return group
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
}
