/*
 * Copyright 2021 Google LLC
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

#import <AppCheckCore/AppCheckCore.h>
#import <DeviceCheck/DeviceCheck.h>
#import <OCMock/OCMock.h>

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppAttestProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppAttestProvider (Tests)
- (instancetype)initWithAppAttestProvider:(GACAppAttestProvider *)appAttestProvider;
@end

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppAttestProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id appAttestProviderMock;
@property(nonatomic) FIRAppAttestProvider *provider;

@end

@implementation FIRAppAttestProviderTests

- (void)setUp {
  [super setUp];

  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.appAttestProviderMock = OCMStrictClassMock([GACAppAttestProvider class]);
  self.provider =
      [[FIRAppAttestProvider alloc] initWithAppAttestProvider:self.appAttestProviderMock];
}

- (void)tearDown {
  self.provider = nil;
  [self.appAttestProviderMock stopMocking];
  self.appAttestProviderMock = nil;
}

#pragma mark - Init tests

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;

  XCTAssertNotNil([[FIRAppAttestProvider alloc] initWithApp:app]);
}

- (void)testGetTokenSuccess {
  // 1. Stub internal debug provider.
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.appAttestProviderMock
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

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.appAttestProviderMock);
}

- (void)testGetTokenAPIError {
  // 1. Stub internal debug provider.
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.appAttestProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.appAttestProviderMock);
}

#pragma mark - Limited-Use Token

- (void)testGetLimitedUseTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"TEST_ValidToken"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.appAttestProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:validInternalToken,
                                                                    [NSNull null], nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertEqualObjects(token.token, validInternalToken.token);
    XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
    XCTAssertNil(error);
  }];

  OCMVerifyAll(self.appAttestProviderMock);
}

- (void)testGetLimitedUseTokenProviderError {
  NSError *expectedError = [NSError errorWithDomain:@"TEST_LimitedUseToken_Error"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.appAttestProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                    NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertIdentical(error, expectedError);
  }];

  OCMVerifyAll(self.appAttestProviderMock);
}

@end
