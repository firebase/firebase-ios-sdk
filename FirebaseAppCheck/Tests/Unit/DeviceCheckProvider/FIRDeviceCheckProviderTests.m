/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/FIRDeviceCheckTokenGenerator.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

API_AVAILABLE(ios(11.0), macos(10.15), tvos(11.0))
API_UNAVAILABLE(watchos)
@interface FIRDeviceCheckProviderTests : XCTestCase
@property(nonatomic) FIRDeviceCheckProvider *provider;
@property(nonatomic) id fakeAPIService;
@property(nonatomic) id fakeTokenGenerator;
@end

@interface FIRDeviceCheckProvider (Tests)

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<FIRDeviceCheckTokenGenerator>)deviceTokenGenerator;

@end

@implementation FIRDeviceCheckProviderTests

- (void)setUp {
  [super setUp];

  self.fakeAPIService = OCMProtocolMock(@protocol(FIRDeviceCheckAPIServiceProtocol));
  self.fakeTokenGenerator = OCMProtocolMock(@protocol(FIRDeviceCheckTokenGenerator));
  self.provider = [[FIRDeviceCheckProvider alloc] initWithAPIService:self.fakeAPIService
                                                deviceTokenGenerator:self.fakeTokenGenerator];
}

- (void)tearDown {
  self.provider = nil;
  self.fakeAPIService = nil;
  self.fakeTokenGenerator = nil;
}

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];

  XCTAssertNotNil([[FIRDeviceCheckProvider alloc] initWithApp:app]);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];

  options.projectID = @"project_id";
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp"
                                                          options:options];
  XCTAssertNil([[FIRDeviceCheckProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = @"api_key";
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp"
                                                             options:options];
  XCTAssertNil([[FIRDeviceCheckProvider alloc] initWithApp:missingProjectIDApp]);
}

- (void)testGetTokenSuccess {
  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  FIRAppCheckToken *validToken = [[FIRAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate distantFuture]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDeviceToken:deviceToken])
      .andReturn([FBLPromise resolvedWith:validToken]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertEqualObjects(token.token, validToken.token);
        XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

- (void)testGetTokenWhenDeviceTokenFails {
  // 1. Expect device token to be generated.
  NSError *deviceTokenError = [NSError errorWithDomain:@"FIRDeviceCheckProviderTests"
                                                  code:-1
                                              userInfo:nil];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:[NSNull null], deviceTokenError, nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Don't expect FAA token to be requested.
  OCMReject([self.fakeAPIService appCheckTokenWithDeviceToken:[OCMArg any]]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, deviceTokenError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

- (void)testGetTokenWhenAPIServiceFails {
  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  NSError *APIServiceError = [NSError errorWithDomain:@"FIRDeviceCheckProviderTests"
                                                 code:-1
                                             userInfo:nil];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIServiceError];
  OCMExpect([self.fakeAPIService appCheckTokenWithDeviceToken:deviceToken])
      .andReturn(rejectedPromise);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, APIServiceError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

@end
