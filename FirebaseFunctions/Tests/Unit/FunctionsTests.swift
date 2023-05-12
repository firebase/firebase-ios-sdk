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

import XCTest
import SharedTestUtilities

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

  func testURLWithName() throws {
    let url = try XCTUnwrap(functions?.urlWithName("my-endpoint"))
    XCTAssertEqual(url, "https://my-region-my-project.cloudfunctions.net/my-endpoint")
  }

  func testRegionWithEmulator() throws {
    functionsCustomDomain?.useEmulator(withHost: "localhost", port: 5005)
    let url = try XCTUnwrap(functionsCustomDomain?.urlWithName("my-endpoint"))
    XCTAssertEqual(url, "http://localhost:5005/my-project/my-region/my-endpoint")
  }

  func testRegionWithEmulatorWithScheme() throws {
    functionsCustomDomain?.useEmulator(withHost: "http://localhost", port: 5005)
    let url = try XCTUnwrap(functionsCustomDomain?.urlWithName("my-endpoint"))
    XCTAssertEqual(url, "http://localhost:5005/my-project/my-region/my-endpoint")
  }

  func testCustomDomain() throws {
    let url = try XCTUnwrap(functionsCustomDomain?.urlWithName("my-endpoint"))
    XCTAssertEqual(url, "https://mydomain.com/my-endpoint")
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

  func testCallFunctionWhenAppCheckIsInstalledAndFACTokenSuccess() {
    appCheckFake.tokenResult = FIRAppCheckTokenResultFake(token: "valid_token", error: nil)

    let networkError = NSError(
      domain: "testCallFunctionWhenAppCheckIsInstalled",
      code: -1,
      userInfo: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertEqual(appCheckTokenHeader, "valid_token")
      testResponse(nil, nil, networkError)
      httpRequestExpectation.fulfill()
    }

    let completionExpectation = expectation(description: "completionExpectation")
    functions?
      .callFunction(name: "fake_func", withObject: nil, options: nil, timeout: 10) { result in
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
      name: "fake_func",
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
