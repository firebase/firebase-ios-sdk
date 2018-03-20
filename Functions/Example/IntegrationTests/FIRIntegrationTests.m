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

@import XCTest;

#import "FIRError.h"
#import "FIRFunctions+Internal.h"
#import "FIRFunctions.h"
#import "FIRHTTPSCallable.h"
#import "FUNFakeApp.h"
#import "FUNFakeInstanceID.h"

@interface FIRIntegrationTests : XCTestCase {
  FIRFunctions *_functions;
}
@end

@implementation FIRIntegrationTests

- (void)setUp {
  [super setUp];
  id app = [[FUNFakeApp alloc] initWithProjectID:@"functions-integration-test"];
  _functions = [FIRFunctions functionsForApp:app];
  [_functions useLocalhost];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testData {
  NSDictionary *data = @{
    @"bool" : @YES,
    @"int" : @2,
    @"long" : @3L,
    @"string" : @"four",
    @"array" : @[ @5, @6 ],
    @"null" : [NSNull null],
  };

  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"dataTest"];
  [function callWithObject:data
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
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
  id app = [[FUNFakeApp alloc] initWithProjectID:@"functions-integration-test" token:@"token"];
  FIRFunctions *functions = [FIRFunctions functionsForApp:app];
  [functions useLocalhost];

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

- (void)testInstanceID {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"instanceIdTest"];
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
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

- (void)testExplicitError {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] init];
  FIRHTTPSCallable *function = [_functions HTTPSCallableWithName:@"explicitErrorTest"];
  [function callWithObject:@{}
      completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(FIRFunctionsErrorCodeOutOfRange, error.code);
        XCTAssertEqualObjects(@"explicit nope", error.userInfo[NSLocalizedDescriptionKey]);
        NSDictionary *expectedDetails = @{ @"start" : @10, @"end" : @20, @"long" : @30L };
        XCTAssertEqualObjects(expectedDetails, error.userInfo[FIRFunctionsErrorDetailsKey]);
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

@end
