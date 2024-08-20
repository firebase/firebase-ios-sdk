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

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRDeviceCheckProvider (Tests)

- (instancetype)initWithDeviceCheckProvider:(GACDeviceCheckProvider *)deviceCheckProvider;

@end

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRDeviceCheckProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id deviceCheckProviderMock;
@property(nonatomic) FIRDeviceCheckProvider *provider;

@end

@implementation FIRDeviceCheckProviderTests

- (void)setUp {
  [super setUp];

  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.deviceCheckProviderMock = OCMStrictClassMock([GACDeviceCheckProvider class]);
  self.provider =
      [[FIRDeviceCheckProvider alloc] initWithDeviceCheckProvider:self.deviceCheckProviderMock];
}

- (void)tearDown {
  self.provider = nil;
  [self.deviceCheckProviderMock stopMocking];
  self.deviceCheckProviderMock = nil;
}

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;

  XCTAssertNotNil([[FIRDeviceCheckProvider alloc] initWithApp:app]);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.projectID = kProjectID;
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingAPIKeyApp.dataCollectionDefaultEnabled = NO;

  XCTAssertNil([[FIRDeviceCheckProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = kAPIKey;
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  missingProjectIDApp.dataCollectionDefaultEnabled = NO;
  XCTAssertNil([[FIRDeviceCheckProvider alloc] initWithApp:missingProjectIDApp]);
}

- (void)testGetTokenSuccess {
  // 1. Stub internal DeviceCheck provider.
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.deviceCheckProviderMock
      getTokenWithCompletion:([OCMArg
                                 invokeBlockWithArgs:validInternalToken, [NSNull null], nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertEqualObjects(token.token, validInternalToken.token);
        XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  // 3. Verify mock DeviceCheck provider.
  OCMVerifyAll(self.deviceCheckProviderMock);
}

- (void)testGetTokenAPIError {
  // 1. Stub internal DeviceCheck provider.
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.deviceCheckProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  // 3. Verify mock DeviceCheck provider.
  OCMVerifyAll(self.deviceCheckProviderMock);
}

#pragma mark - Limited-Use Token

- (void)testGetLimitedUseTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"TEST_ValidToken"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.deviceCheckProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:validInternalToken,
                                                                    [NSNull null], nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertEqualObjects(token.token, validInternalToken.token);
    XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
    XCTAssertNil(error);
  }];

  OCMVerifyAll(self.deviceCheckProviderMock);
}

- (void)testGetLimitedUseTokenProviderError {
  NSError *expectedError = [NSError errorWithDomain:@"TEST_LimitedUseToken_Error"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.deviceCheckProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertIdentical(error, expectedError);
  }];

  OCMVerifyAll(self.deviceCheckProviderMock);
}

@end
