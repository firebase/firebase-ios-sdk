// Copyright 2022 Google LLC
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

import FirebaseCore
@testable import FirebaseFunctions
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

import SharedTestUtilities
import XCTest

class FunctionsTests: XCTestCase {
  var functions: Functions?
  var functionsCustomDomain: Functions?
  let fetcherService = GTMSessionFetcherService()
  let appCheckFake = FIRAppCheckFake()

  override func setUp() {
    super.setUp()
    functions = Functions(
      projectID: "my-project",
      region: "my-region",
      customDomain: nil,
      auth: nil,
      messaging: nil,
      appCheck: appCheckFake,
      fetcherService: fetcherService
    )
    functionsCustomDomain = Functions(projectID: "my-project", region: "my-region",
                                      customDomain: "https://mydomain.com", auth: nil,
                                      messaging: nil, appCheck: nil,
                                      fetcherService: fetcherService)
  }

  override func tearDown() {
    functions = nil
    functionsCustomDomain = nil
    super.tearDown()
  }

  func testFunctionsInstanceIsStablePerApp() throws {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    FirebaseApp.configure(options: options)
    var functions1 = Functions.functions()
    var functions2 = Functions.functions(app: FirebaseApp.app()!)
    XCTAssertEqual(functions1, functions2)

    FirebaseApp.configure(name: "test", options: options)
    let app2 = try XCTUnwrap(FirebaseApp.app(name: "test"))
    functions2 = Functions.functions(app: app2, region: "us-central2")
    XCTAssertNotEqual(functions1, functions2)

    functions1 = Functions.functions(app: app2, region: "us-central2")
    XCTAssertEqual(functions1, functions2)

    functions1 = Functions.functions(customDomain: "test_domain")
    functions2 = Functions.functions(region: "us-central1")
    XCTAssertNotEqual(functions1, functions2)

    functions2 = Functions.functions(app: FirebaseApp.app()!, customDomain: "test_domain")
    XCTAssertEqual(functions1, functions2)
  }

  func testFunctionURLForName() throws {
    XCTAssertEqual(
      functions?.functionURL(for: "my-endpoint")?.absoluteString,
      "https://my-region-my-project.cloudfunctions.net/my-endpoint"
    )
  }

  func testFunctionURLForNameEmulator() throws {
    functionsCustomDomain?.useEmulator(withHost: "localhost", port: 5005)
    XCTAssertEqual(
      functionsCustomDomain?.functionURL(for: "my-endpoint")?.absoluteString,
      "http://localhost:5005/my-project/my-region/my-endpoint"
    )
  }

  func testFunctionURLForNameRegionWithEmulatorWithScheme() throws {
    functionsCustomDomain?.useEmulator(withHost: "http://localhost", port: 5005)
    XCTAssertEqual(
      functionsCustomDomain?.functionURL(for: "my-endpoint")?.absoluteString,
      "http://localhost:5005/my-project/my-region/my-endpoint"
    )
  }

  func testFunctionURLForNameCustomDomain() throws {
    XCTAssertEqual(
      functionsCustomDomain?.functionURL(for: "my-endpoint")?.absoluteString,
      "https://mydomain.com/my-endpoint"
    )
  }

  func testSetEmulatorSettings() throws {
    functions?.useEmulator(withHost: "localhost", port: 1000)
    XCTAssertEqual("http://localhost:1000", functions?.emulatorOrigin)
  }

  /// Test that Functions instances get deallocated.
  func testFunctionsLifecycle() throws {
    weak var weakApp: FirebaseApp?
    weak var weakFunctions: Functions?
    try autoreleasepool {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "myProjectID"
      let app1 = FirebaseApp(instanceWithName: "transitory app", options: options)
      weakApp = try XCTUnwrap(app1)
      let functions = Functions(app: app1, region: "transitory-region", customDomain: nil)
      weakFunctions = functions
      XCTAssertNotNil(weakFunctions)
    }
    XCTAssertNil(weakApp)
    XCTAssertNil(weakFunctions)
  }

  // MARK: - App Check Integration

  func testCallFunctionWhenUsingLimitedUseAppCheckTokenThenTokenSuccess() {
    // Given
    // Stub returns of two different kinds of App Check tokens. Only the
    // limited use token should be present in Functions's request header.
    appCheckFake.tokenResult = FIRAppCheckTokenResultFake(token: "shared_valid_token", error: nil)
    appCheckFake.limitedUseTokenResult = FIRAppCheckTokenResultFake(
      token: "limited_use_valid_token",
      error: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      // Assert that header contains limited use token.
      XCTAssertEqual(appCheckTokenHeader, "limited_use_valid_token")
      testResponse(nil, "{\"data\":\"May the force be with you!\"}".data(using: .utf8), nil)
      httpRequestExpectation.fulfill()
    }

    // When
    let options = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: true)

    // Then
    let completionExpectation = expectation(description: "completionExpectation")
    functions?
      .httpsCallable("fake_func", options: options)
      .call { result, error in
        guard let result = result else {
          return XCTFail("Unexpected error: \(error!).")
        }

        XCTAssertEqual(result.data as! String, "May the force be with you!")

        completionExpectation.fulfill()
      }

    waitForExpectations(timeout: 1.5)
  }

  func testCallFunctionWhenLimitedUseAppCheckTokenDisabledThenCallWithoutToken() {
    // Given
    let limitedUseDummyToken = "limited use dummy token"
    appCheckFake.limitedUseTokenResult = FIRAppCheckTokenResultFake(
      token: limitedUseDummyToken,
      error: NSError(domain: #function, code: -1)
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      // Assert that header does not contain an AppCheck token.
      fetcherToTest.request?.allHTTPHeaderFields?.forEach { key, value in
        if key == "X-Firebase-AppCheck" {
          XCTAssertNotEqual(value, limitedUseDummyToken)
        }
      }

      testResponse(nil, "{\"data\":\"May the force be with you!\"}".data(using: .utf8), nil)
      httpRequestExpectation.fulfill()
    }

    // When
    let options = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: false)

    // Then
    let completionExpectation = expectation(description: "completionExpectation")
    functions?
      .httpsCallable("fake_func", options: options)
      .call { result, error in
        guard let result = result else {
          return XCTFail("Unexpected error: \(error!).")
        }

        XCTAssertEqual(result.data as! String, "May the force be with you!")

        completionExpectation.fulfill()
      }

    waitForExpectations(timeout: 1.5)
  }

  func testCallFunctionWhenLimitedUseAppCheckTokenCannotBeGeneratedThenCallWithoutToken() {
    // Given
    appCheckFake.limitedUseTokenResult = FIRAppCheckTokenResultFake(
      token: "dummy token",
      error: NSError(domain: #function, code: -1)
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      // Assert that header does not contain an AppCheck token.
      fetcherToTest.request?.allHTTPHeaderFields?.forEach { key, _ in
        XCTAssertNotEqual(key, "X-Firebase-AppCheck")
      }

      testResponse(nil, "{\"data\":\"May the force be with you!\"}".data(using: .utf8), nil)
      httpRequestExpectation.fulfill()
    }

    // When
    let options = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: true)

    // Then
    let completionExpectation = expectation(description: "completionExpectation")
    functions?
      .httpsCallable("fake_func", options: options)
      .call { result, error in
        guard let result = result else {
          return XCTFail("Unexpected error: \(error!).")
        }

        XCTAssertEqual(result.data as! String, "May the force be with you!")

        completionExpectation.fulfill()
      }

    waitForExpectations(timeout: 1.5)
  }

  func testCallFunctionWhenAppCheckIsInstalledAndFACTokenSuccess() {
    // Stub returns of two different kinds of App Check tokens. Only the
    // shared use token should be present in Functions's request header.
    appCheckFake.tokenResult = FIRAppCheckTokenResultFake(token: "shared_valid_token", error: nil)
    appCheckFake.limitedUseTokenResult = FIRAppCheckTokenResultFake(
      token: "limited_use_valid_token",
      error: nil
    )

    let networkError = NSError(
      domain: "testCallFunctionWhenAppCheckIsInstalled",
      code: -1,
      userInfo: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertEqual(appCheckTokenHeader, "shared_valid_token")
      testResponse(nil, nil, networkError)
      httpRequestExpectation.fulfill()
    }

    let completionExpectation = expectation(description: "completionExpectation")
    functions?
      .httpsCallable("fake_func")
      .call { result, error in
        guard let error = error else {
          return XCTFail("Unexpected success: \(result!).")
        }

        XCTAssertEqual(error as NSError, networkError)

        completionExpectation.fulfill()
      }

    waitForExpectations(timeout: 1.5)
  }

  func testAsyncCallFunctionWhenAppCheckIsNotInstalled() async {
    let networkError = NSError(
      domain: "testCallFunctionWhenAppCheckIsInstalled",
      code: -1,
      userInfo: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertNil(appCheckTokenHeader)
      testResponse(nil, nil, networkError)
      httpRequestExpectation.fulfill()
    }

    do {
      _ = try await functionsCustomDomain?
        .callFunction(
          at: URL(string: "https://example.com/fake_func")!,
          withObject: nil,
          options: nil,
          timeout: 10
        )
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as NSError, networkError)
    }

    await fulfillment(of: [httpRequestExpectation], timeout: 1.5)
  }

  func testCallFunctionWhenAppCheckIsNotInstalled() {
    let networkError = NSError(
      domain: "testCallFunctionWhenAppCheckIsInstalled",
      code: -1,
      userInfo: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertNil(appCheckTokenHeader)
      testResponse(nil, nil, networkError)
      httpRequestExpectation.fulfill()
    }

    let completionExpectation = expectation(description: "completionExpectation")
    functionsCustomDomain?.callFunction(
      at: URL(string: "https://example.com/fake_func")!,
      withObject: nil,
      options: nil,
      timeout: 10
    ) { result in
      switch result {
      case .success:
        XCTFail("Unexpected success from functions?.callFunction")
      case let .failure(error as NSError):
        XCTAssertEqual(error, networkError)
      }
      completionExpectation.fulfill()
    }
    waitForExpectations(timeout: 1.5)
  }
}
