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

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseFunctions/Tests/ObjCIntegration/FIRFunctions+Internal.h"

@import FirebaseFunctions;
@import FirebaseAuthInterop;
@import FirebaseMessagingInterop;
@import GTMSessionFetcherCore;

// Project ID used by these tests.
static NSString *const kDefaultProjectID = @"functions-integration-test";

@interface MessagingTokenProvider : NSObject <FIRMessagingInterop>
@end

@implementation MessagingTokenProvider
@synthesize FCMToken;
- (instancetype)init {
  if (self = [super init]) {
    FCMToken = @"fakeFCMToken";
  }
  return self;
}

@end

@interface AuthTokenProvider : NSObject <FIRAuthInterop>
@property NSString *token;
@end

@implementation AuthTokenProvider
- (instancetype)initWithToken:(NSString *)token {
  if (self = [super init]) {
    _token = token;
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh withCallback:(nonnull FIRTokenCallback)callback {
  callback(_token, nil);
}

- (nullable NSString *)getUserID {
  return @"dummy user id";
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

  _messagingFake = [[MessagingTokenProvider alloc] init];
  _projectID = kDefaultProjectID;
  _useLocalhost = YES;

  // Check for configuration of a prod project via GoogleServices-Info.plist.
  FIROptions *options = [FIROptions defaultOptions];
  if (options && ![options.projectID isEqualToString:@"abc-xyz-123"]) {
    _projectID = options.projectID;
    _useLocalhost = NO;
  }

  _functions = [[FIRFunctions alloc] initWithProjectID:_projectID
                                                region:@"us-central1"
                                          customDomain:nil
                                                  auth:nil
                                             messaging:_messagingFake
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

- (void)testToken {
  // Recreate _functions with a token.
  FIRFunctions *functions =
      [[FIRFunctions alloc] initWithProjectID:_projectID
                                       region:@"us-central1"
                                 customDomain:nil
                                         auth:[[AuthTokenProvider alloc] initWithToken:@"token"]
                                    messaging:_messagingFake
                                     appCheck:nil
                               fetcherService:[[GTMSessionFetcherService alloc] init]];
  if (_useLocalhost) {
    [functions useEmulatorWithHost:@"localhost" port:5005];
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

- (void)testFCMToken {
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
            XCTAssertEqualObjects(expectedDetails, error.userInfo[@"details"]);
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
                  XCTAssertEqualObjects(error.localizedDescription, @"INVALID ARGUMENT");
                  [expectation fulfill];
                }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/9855
- (void)testThrowTest {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"throwTest"];
  [function callWithObject:@{}
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  XCTAssertNotNil(error);
                  XCTAssertEqual(FIRFunctionsErrorCodeInvalidArgument, error.code);
                  XCTAssertEqualObjects(error.localizedDescription, @"Invalid test requested.");
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
        XCTAssertNil(error.userInfo[@"details"]);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

@end
