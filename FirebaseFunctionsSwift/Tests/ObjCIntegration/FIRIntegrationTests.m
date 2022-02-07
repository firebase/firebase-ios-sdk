// Copyright 2017 Google
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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"
#import "FirebaseFunctionsSwift/Tests/ObjCIntegration/FIRFunctions+Internal.h"

@import FirebaseFunctionsSwift;
@import GTMSessionFetcherCore;

//#import "SharedTestUtilities/FIRAuthInteropFake.h"
//#import "SharedTestUtilities/FIRMessagingInteropFake.h"

// Project ID used by these tests.
static NSString *const kDefaultProjectID = @"functions-integration-test";

@interface MessagingTokenProvider : NSObject <MessagingInterop>
@end

@implementation MessagingTokenProvider
@synthesize fcmToken;
- (instancetype)init {
  fcmToken = @"abc";
}

@end

@interface FIRIntegrationTests : XCTestCase {
  FIRFunctions *_functions;
  NSString *_projectID;
  BOOL _useLocalhost;
  MessagingTokenProvider *_messagingFake;
}
@end

@implementation FIRIntegrationTests

- (void)setUp {
  [super setUp];

  //_messagingFake = [[FIRMessagingInteropFake alloc] init];
  _messagingFake = [[MessagingTokenProvider alloc] init];

  _projectID = kDefaultProjectID;
  _useLocalhost = YES;

  // Check for configuration of a prod project via GoogleServices-Info.plist.
  FIROptions *options = [FIROptions defaultOptions];
  if (options && ![options.projectID isEqualToString:@"abc-xyz-123"]) {
    _projectID = options.projectID;
    _useLocalhost = NO;
  }

  _functions = [[FIRFunctions alloc]
      initWithProjectID:_projectID
                 region:@"us-central1"
           customDomain:nil
                   auth:nil  //[[FIRAuthInteropFake alloc] initWithToken:nil userID:nil error:nil]
              messaging:nil  //_messagingFake
               appCheck:nil
         fetcherService:[[GTMSessionFetcherService alloc] init]];
  if (_useLocalhost) {
    [_functions useEmulatorWithHost:@"localhost" port:5005];
  }
}

- (void)tearDown {
  [super tearDown];
}

- (void)testData {
  NSDictionary *data = @{
    @"bool" : @YES,
    @"int" : @2,
    @"long" : @9876543210L,
    @"string" : @"four",
    @"array" : @[ @5, @6 ],
    @"null" : [NSNull null],
  };

  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"dataTest"];
  [function callWithObject:data
                completion:^(FIRHTTPSCallableResult *result, NSError *_Nullable error) {
                  XCTAssertNil(error);
                  XCTAssertEqualObjects(@"stub response", result.data[@"message"]);
                  XCTAssertEqualObjects(@42, result.data[@"code"]);
                  XCTAssertEqualObjects(@420L, result.data[@"long"]);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testScalar {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"scalarTest"];
  [function callWithObject:@17
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNil(error);
                  XCTAssertEqualObjects(@76, result.data);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

// TODO: Fix with interop.
- (void)SKIPtestToken {
  // Recreate _functions with a token.
  FIRFunctions *functions =
      [[FIRFunctions alloc] initWithProjectID:_projectID
                                       region:@"us-central1"
                                 customDomain:nil
                                         auth:nil  //[[FIRAuthInteropFake alloc]
                                                   // initWithToken:@"token" userID:nil error:nil]
                                    messaging:nil  //_messagingFake
                                     appCheck:nil
                               fetcherService:[[GTMSessionFetcherService alloc] init]];
  if (_useLocalhost) {
    [_functions useEmulatorWithHost:@"localhost" port:5005];
  }

  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [functions HTTPSCallableWithName:@"tokenTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNil(error);
                  XCTAssertEqualObjects(@{}, result.data);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)SKIPtestFCMToken {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"FCMTokenTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNil(error);
                  XCTAssertEqualObjects(@{}, result.data);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testNull {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"nullTest"];
  [function callWithObject:[NSNull null]
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertEqualObjects([NSNull null], result.data);
                  XCTAssertNil(error);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];

  // Test the version with no arguments.
  expectation = [[XCTestExpectation alloc] init];
  [function
      callWithCompletion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects([NSNull null], result.data);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testMissingResult {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"missingResultTest"];
  [function
      callWithCompletion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(FIRFunctionsErrorCodeInternal, error.code);
        XCTAssertEqualObjects(@"Response is missing data field.", error.localizedDescription);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testUnhandledError {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"unhandledErrorTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNotNil(error);
                  XCTAssertEqual(FIRFunctionsErrorCodeInternal, error.code);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testUnknownError {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"unknownErrorTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNotNil(error);
                  XCTAssertEqual(FIRFunctionsErrorCodeInternal, error.code);
                  XCTAssertEqualObjects(@"INTERNAL", error.localizedDescription);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testExplicitError {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"explicitErrorTest"];
  [function
      callWithObject:@{}
          completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
            XCTAssertNotNil(error);
            XCTAssertEqual(FIRFunctionsErrorCodeOutOfRange, error.code);
            XCTAssertEqualObjects(@"explicit nope", error.userInfo[NSLocalizedDescriptionKey]);
            NSDictionary *expectedDetails = @{@"start" : @10, @"end" : @20, @"long" : @30L};
            XCTAssertEqualObjects(expectedDetails,
                                  error.userInfo[FIRFunctionsErrorKeys.errorDetailsKey]);
            [expectation fulfill];
          }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testHttpError {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"httpErrorTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNotNil(error);
                  XCTAssertEqual(FIRFunctionsErrorCodeInvalidArgument, error.code);
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testTimeout {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"timeoutTest"];
  function.timeoutInterval = 0.05;
  [function
      callWithCompletion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(FIRFunctionsErrorCodeDeadlineExceeded, error.code);
        XCTAssertEqualObjects(@"DEADLINE EXCEEDED", error.userInfo[NSLocalizedDescriptionKey]);
        XCTAssertNil(error.userInfo[FIRFunctionsErrorKeys.errorDetailsKey]);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

@end
//
//@interface AuthTokenProvider: AuthInterop
//@end
//
//@implementation AuthTokenProvider
//@end

// private class AuthTokenProvider: AuthInterop {
//   let token: String
//
//   init(token: String) {
//     self.token = token
//   }
//
//   func getToken(forcingRefresh: Bool, callback: (String?, Error?) -> Void) {
//     callback(token, nil)
//   }
// }
//
// private class MessagingTokenProvider: MessagingInterop {
//   var fcmToken: String { return "fakeFCMToken" }
// }
