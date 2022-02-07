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
@testable import FirebaseFunctionsSwift
import GTMSessionFetcherCore

import XCTest
import SharedTestUtilities

// #import <XCTest/XCTest.h>
//
// #import "FirebaseFunctions/Sources/FIRFunctions+Internal.h"
// #import "FirebaseFunctions/Sources/Public/FirebaseFunctions/FIRFunctions.h"
//
// #import "SharedTestUtilities/AppCheckFake/FIRAppCheckFake.h"
// #import "SharedTestUtilities/AppCheckFake/FIRAppCheckTokenResultFake.h"
//
// #import <FirebaseCore/FirebaseCore.h>
//
// #if SWIFT_PACKAGE
// @import GTMSessionFetcherCore;
// #else
// #import <GTMSessionFetcher/GTMSessionFetcherService.h>
// #endif
//
// @interface FIRFunctions (Test)
//
// @property(nonatomic, readonly) NSString *emulatorOrigin;
//
// - (instancetype)initWithProjectID:(NSString *)projectID
//                           region:(NSString *)region
//                     customDomain:(nullable NSString *)customDomain
//                             auth:(nullable id<FIRAuthInterop>)auth
//                        messaging:(nullable id<FIRMessagingInterop>)messaging
//                         appCheck:(nullable id<FIRAppCheckInterop>)appCheck
//                   fetcherService:(GTMSessionFetcherService *)fetcherService;
//
// @end
//
// @interface FIRFunctionsTests : XCTestCase
//
// @end

class FunctionsTests: XCTestCase {
//
  // @implementation FIRFunctionsTests {
//  FIRFunctions *_functions;
//  FIRFunctions *_functionsCustomDomain;
//
//  GTMSessionFetcherService *_fetcherService;
//  FIRAppCheckFake *_appCheckFake;
  // }
//
  // - (void)setUp {
//  [super setUp];
//  _fetcherService = [[GTMSessionFetcherService alloc] init];
//  _appCheckFake = [[FIRAppCheckFake alloc] init];
//
//  _functions = [[FIRFunctions alloc] initWithProjectID:@"my-project"
//                                                region:@"my-region"
//                                          customDomain:nil
//                                                  auth:nil
//                                             messaging:nil
//                                              appCheck:_appCheckFake
//                                        fetcherService:_fetcherService];
//
//  _functionsCustomDomain = [[FIRFunctions alloc] initWithProjectID:@"my-project"
//                                                            region:@"my-region"
//                                                      customDomain:@"https://mydomain.com"
//                                                              auth:nil
//                                                         messaging:nil
//                                                          appCheck:nil
//                                                    fetcherService:_fetcherService];
  // }
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

//
  // - (void)tearDown {
//  _functionsCustomDomain = nil;
//  _functions = nil;
//  _fetcherService = nil;
//  [super tearDown];
  // }

  // TODO: Finish porting this test when components are done.
  func SKIPtestFunctionsInstanceIsStablePerApp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    FirebaseApp.configure(options: options)

    let functions1 = Functions.functions()
    let functions2 = Functions
      .functions(app: FirebaseApp.app()!, region: "") // (app:FirebaseApp.app)
    XCTAssertEqual(functions1, functions2)
  }

//
  // - (void)testFunctionsInstanceIsStablePerApp {
//  FIROptions *options =
//      [[FIROptions alloc] initWithGoogleAppID:@"0:0000000000000:ios:0000000000000000"
//                                  GCMSenderID:@"00000000000000000-00000000000-000000000"];
//  [FIRApp configureWithOptions:options];
//
//  FIRFunctions *functions1 = [FIRFunctions functions];
//  FIRFunctions *functions2 = [FIRFunctions functionsForApp:[FIRApp defaultApp]];
//
//  XCTAssertEqualObjects(functions1, functions2);
//
//  [FIRApp configureWithName:@"test" options:options];
//  FIRApp *app2 = [FIRApp appNamed:@"test"];
//
//  functions2 = [FIRFunctions functionsForApp:app2 region:@"us-central2"];
//
//  XCTAssertNotEqualObjects(functions1, functions2);
//
//  functions1 = [FIRFunctions functionsForApp:app2 region:@"us-central2"];
//
//  XCTAssertEqualObjects(functions1, functions2);
//
//  functions1 = [FIRFunctions functionsForCustomDomain:@"test_domain"];
//  functions2 = [FIRFunctions functionsForRegion:@"us-central1"];
//
//  XCTAssertNotEqualObjects(functions1, functions2);
//
//  functions2 = [FIRFunctions functionsForApp:[FIRApp defaultApp] customDomain:@"test_domain"];
//  XCTAssertEqualObjects(functions1, functions2);
  // }

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

  // MARK: - App Check integration

  func testCallFunctionWhenAppCheckIsInstalledAndFACTokenSuccess() {
    appCheckFake.tokenResult = FIRAppCheckTokenResultFake(token: "valid_token", error: nil)

    let networkError = NSError(
      domain: "testCallFunctionWhenAppCheckIsInstalled",
      code: -1,
      userInfo: nil
    )

    let httpRequestExpectation = expectation(description: "HTTPRequestExpectation")
    fetcherService.testBlock = { fetcherToTest, testResponse in
      httpRequestExpectation.fulfill()
      let appCheckTokenHeader = fetcherToTest.request?
        .value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertEqual(appCheckTokenHeader, "valid_token")
      testResponse(nil, nil, networkError)
    }

    let completionExpectation = expectation(description: "completionExpectation")
    functions?.callFunction(name: "fake_func", withObject: nil, timeout: 10) { result in
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

  // - (void)testCallFunctionWhenAppCheckIsInstalledAndFACTokenError {
//  NSError *appCheckError = [NSError errorWithDomain:self.name code:-1 userInfo:nil];
//  _appCheckFake.tokenResult = [[FIRAppCheckTokenResultFake alloc] initWithToken:@"dummy_token"
//                                                                          error:appCheckError];
//
//  NSError *networkError = [NSError errorWithDomain:self.name code:-2 userInfo:nil];
//
//  XCTestExpectation *httpRequestExpectation =
//      [self expectationWithDescription:@"HTTPRequestExpectation"];
//  __weak __auto_type weakSelf = self;
//  _fetcherService.testBlock = ^(GTMSessionFetcher *_Nonnull fetcherToTest,
//                                GTMSessionFetcherTestResponse _Nonnull testResponse) {
//    // __unused to avoid warning in Xcode 12+ in g3.
//    __unused __auto_type self = weakSelf;
//    [httpRequestExpectation fulfill];
//
//    NSString *appCheckTokenHeader =
//        [fetcherToTest.request valueForHTTPHeaderField:@"X-Firebase-AppCheck"];
//    XCTAssertNil(appCheckTokenHeader);
//
//    testResponse(nil, nil, networkError);
//  };
//
//  XCTestExpectation *completionExpectation =
//      [self expectationWithDescription:@"completionExpectation"];
//  [_functions callFunction:@"fake_func"
//                withObject:nil
//                   timeout:10
//                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
//                  XCTAssertEqualObjects(error, networkError);
//                  [completionExpectation fulfill];
//                }];
//
//  [self waitForExpectations:@[ httpRequestExpectation, completionExpectation ] timeout:1.5];
  // }
//
  // - (void)testCallFunctionWhenAppCheckIsNotInstalled {
//  NSError *networkError = [NSError errorWithDomain:@"testCallFunctionWhenAppCheckIsInstalled"
//                                              code:-1
//                                          userInfo:nil];
//
//  XCTestExpectation *httpRequestExpectation =
//      [self expectationWithDescription:@"HTTPRequestExpectation"];
//  __weak __auto_type weakSelf = self;
//  _fetcherService.testBlock = ^(GTMSessionFetcher *_Nonnull fetcherToTest,
//                                GTMSessionFetcherTestResponse _Nonnull testResponse) {
//    // __unused to avoid warning in Xcode 12+ in g3.
//    __unused __auto_type self = weakSelf;
//    [httpRequestExpectation fulfill];
//
//    NSString *appCheckTokenHeader =
//        [fetcherToTest.request valueForHTTPHeaderField:@"X-Firebase-AppCheck"];
//    XCTAssertNil(appCheckTokenHeader);
//
//    testResponse(nil, nil, networkError);
//  };
//
//  XCTestExpectation *completionExpectation =
//      [self expectationWithDescription:@"completionExpectation"];
//  [_functionsCustomDomain
//      callFunction:@"fake_func"
//        withObject:nil
//           timeout:10
//        completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
//          XCTAssertEqualObjects(error, networkError);
//          [completionExpectation fulfill];
//        }];
//
//  [self waitForExpectations:@[ httpRequestExpectation, completionExpectation ] timeout:1.5];
  // }
//
  // @end
}
