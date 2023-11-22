// Copyright 2021 Google LLC
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

import Combine
import FirebaseAuth
import Foundation
import XCTest

class OAuthProviderTests: XCTestCase {
  override class func setUp() {
    FirebaseApp.configureForTests()
    Bundle.mock(with: MockBundle.self)
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { success in
      if success {
        print("Shut down app successfully.")
      } else {
        print("💥 There was a problem when shutting down the app..")
      }
    }
  }

  static let encodedFirebaseAppID = "app-1-1085102361755-ios-f790a919483d5bdf"
  static let reverseClientID = "com.googleusercontent.apps.123456"
  static let providerID = "fakeProviderID"
  static let authorizedDomain = "test.firebaseapp.com"
  static let oauthResponseURL = "fakeOAuthResponseURL"
  static let redirectURLResponseURL =
    "://firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%3DsignInWithRedirect%26link%3D"
  static let redirectURLBaseErrorString =
    "com.googleusercontent.apps.123456://firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3f"
  static let networkRequestFailedErrorString =
    "firebaseError%3D%257B%2522code%2522%253A%2522auth%252Fnetwork-request-failed%2522%252C%2522message%2522%253A%2522The%2520network%2520request%2520failed%2520.%2522%257D%26authType%3DsignInWithRedirect"
  static let internalErrorString =
    "firebaseError%3D%257B%2522code%2522%253A%2522auth%252Finternal-error%2522%252C%2522message%2522%253A%2522Internal%2520error%2520.%2522%257D%26authType%3DsignInWithRedirect"
  static let invalidClientIDString =
    "firebaseError%3D%257B%2522code%2522%253A%2522auth%252Finvalid-oauth-client-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%26authType%3DsignInWithRedirect"
  static let unknownErrorString =
    "firebaseError%3D%257B%2522code%2522%253A%2522auth%252Funknown-error-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%26authType%3DsignInWithRedirect"

  class MockAuth: Auth {
    private var _authURLPresenter: FIRAuthURLPresenter!

    override class func auth() -> Auth {
      let auth = MockAuth(
        apiKey: Credentials.apiKey,
        appName: "app1",
        appID: Credentials.googleAppID
      )!
      auth._authURLPresenter = MockAuthURLPresenter()
      return auth
    }

    override var app: FirebaseApp? {
      FirebaseApp.appForAuthUnitTestsWithName(name: "app1")
    }

    override var authURLPresenter: FIRAuthURLPresenter { _authURLPresenter }

    override var requestConfiguration: FIRAuthRequestConfiguration {
      MockRequestConfiguration(apiKey: Credentials.apiKey, appID: Credentials.googleAppID)!
    }
  }

  class MockRequestConfiguration: FIRAuthRequestConfiguration {}

  class MockUIDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController,
                 animated flag: Bool, completion: (() -> Void)? = nil) {}

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {}
  }

  class MockAuthURLPresenter: FIRAuthURLPresenter {
    var authURLPresentationResult: Result<URL, Error>?
    var redirectURL = reverseClientID + redirectURLResponseURL + oauthResponseURL
    override func present(_ URL: URL, uiDelegate UIDelegate: AuthUIDelegate?,
                          callbackMatcher: @escaping FIRAuthURLCallbackMatcher,
                          completion: @escaping FIRAuthURLPresentationCompletion) {
      XCTAssertEqual(URL.scheme, "https")
      XCTAssertEqual(URL.host, OAuthProviderTests.authorizedDomain)
      XCTAssertEqual(URL.path, "/__/auth/handler")

      do {
        let query = try XCTUnwrap(URL.query)
        let params = FIRAuthWebUtils.dictionary(withHttpArgumentsString: query)
        let ibi = try XCTUnwrap(params["ibi"] as? String)
        XCTAssertEqual(ibi, Credentials.bundleID)
        let clientId = try XCTUnwrap(params["clientId"] as? String)
        XCTAssertEqual(clientId, Credentials.clientID)
        let apiKey = try XCTUnwrap(params["apiKey"] as? String)
        XCTAssertEqual(apiKey, Credentials.apiKey)
        let authType = try XCTUnwrap(params["authType"] as? String)
        XCTAssertEqual(authType, "signInWithRedirect")
        XCTAssertNotNil(params["v"])

        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher(Foundation.URL(string: redirectURL)))
        redirectURL.append("%26eventId%3D")
        let eventId = try XCTUnwrap(params["eventId"] as? String)
        redirectURL.append(eventId)
        let originalComponents = URLComponents(string: redirectURL)
        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        XCTAssertTrue(callbackMatcher(originalComponents?.url))
        var components = originalComponents
        components?.query = "https"
        XCTAssertFalse(callbackMatcher(components?.url))
        components = originalComponents
        components?.host = "badhost"
        XCTAssertFalse(callbackMatcher(components?.url))
        components = originalComponents
        components?.path = "badpath"
        XCTAssertFalse(callbackMatcher(components?.url))
        components = originalComponents
        components?.query = "badquery"
        XCTAssertFalse(callbackMatcher(components?.url))

        FIRAuthGlobalWorkQueue().async { [weak self] in
          switch self?.authURLPresentationResult {
          case let .success(url):
            completion(url, nil)
          case let .failure(error):
            completion(nil, error)
          default:
            completion(originalComponents?.url, nil)
          }
        }
      } catch {
        XCTFail("💥 Expect non-nil: \(error)")
      }
    }
  }

  class MockGetProjectConfigResponse: FIRGetProjectConfigResponse {
    override var authorizedDomains: [Any]? { [authorizedDomain] }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func getProjectConfig(_ request: FIRGetProjectConfigRequest,
                                   callback: @escaping FIRGetProjectConfigResponseCallback) {
      XCTAssertNotNil(request)
      FIRAuthGlobalWorkQueue().async {
        callback(MockGetProjectConfigResponse(), nil)
      }
    }
  }

  class MockBundle: Bundle {
    override class var main: Bundle { MockBundle() }
    override var bundleIdentifier: String? { Credentials.bundleID }
    override func object(forInfoDictionaryKey key: String) -> Any? {
      switch key {
      case "CFBundleURLTypes":
        return [["CFBundleURLSchemes": [reverseClientID]]]
      default:
        return nil
      }
    }
  }

  func testGetCredentialWithUIDelegateWithClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { credential in
        do {
          XCTAssertTrue(Thread.isMainThread)
          let oauthCredential = try XCTUnwrap(credential as? OAuthCredential)
          XCTAssertEqual(Self.oauthResponseURL, oauthCredential.oAuthResponseURLString)

        } catch {
          XCTFail("💥 Expect non-nil OAuth credential: \(error)")
        }

        getCredentialExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialWithUIDelegateUserCancellationWithClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let authURLPresenter = auth.authURLPresenter as? MockAuthURLPresenter
    let cancelError = FIRAuthErrorUtils.webContextCancelledError(withMessage: nil)
    authURLPresenter?.authURLPresentationResult = .failure(cancelError)
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.webContextCancelled.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialWithUIDelegateNetworkRequestFailedWithClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let authURLPresenter = auth.authURLPresenter as? MockAuthURLPresenter
    authURLPresenter?.redirectURL = Self.redirectURLBaseErrorString + Self
      .networkRequestFailedErrorString
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.webNetworkRequestFailed.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialWithUIDelegateInternalErrorWithClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let authURLPresenter = auth.authURLPresenter as? MockAuthURLPresenter
    authURLPresenter?.redirectURL = Self.redirectURLBaseErrorString + Self.internalErrorString
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.webInternalError.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialWithUIDelegateInvalidClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let authURLPresenter = auth.authURLPresenter as? MockAuthURLPresenter
    authURLPresenter?.redirectURL = Self.redirectURLBaseErrorString
    authURLPresenter?.redirectURL.append(Self.invalidClientIDString)
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.invalidClientID.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialWithUIDelegateUnknownErrorWithClientID() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    let uiDelegate = MockUIDelegate()
    let auth = MockAuth.auth()
    let authURLPresenter = auth.authURLPresenter as? MockAuthURLPresenter
    authURLPresenter?.redirectURL = Self.redirectURLBaseErrorString
    authURLPresenter?.redirectURL.append(Self.unknownErrorString)
    let provider = OAuthProvider(providerID: Self.providerID, auth: auth)

    provider.getCredentialWith(uiDelegate)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(
            error.code,
            AuthErrorCode.webSignInUserInteractionFailure.rawValue
          )

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }
}
