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

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";

@interface FIRAppCheckDebugProvider (Tests)

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider;

@end

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id debugProviderMock;
@property(nonatomic) FIRAppCheckDebugProvider *provider;

@end

@implementation FIRAppCheckDebugProviderTests

- (void)setUp {
  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.debugProviderMock = OCMStrictClassMock([GACAppCheckDebugProvider class]);
  self.provider = [[FIRAppCheckDebugProvider alloc] initWithDebugProvider:self.debugProviderMock];
}

- (void)tearDown {
  self.provider = nil;
  [self.debugProviderMock stopMocking];
  self.debugProviderMock = nil;
}

#pragma mark - Initialization

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];

  OCMExpect([self.debugProviderMock alloc]).andReturn(self.debugProviderMock);
  OCMExpect([self.debugProviderMock initWithStorageID:kAppName
                                         resourceName:self.resourceName
                                               APIKey:kAPIKey
                                         requestHooks:OCMOCK_ANY])
      .andReturn(self.debugProviderMock);

  XCTAssertNotNil([[FIRAppCheckDebugProvider alloc] initWithApp:app]);

  OCMVerifyAll(self.debugProviderMock);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.projectID = kProjectID;
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];

  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = kAPIKey;
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingProjectIDApp]);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Current Debug token

- (void)testCurrentTokenShim {
  NSString *currentToken = @"debug_token";
  OCMExpect([self.debugProviderMock currentDebugToken]).andReturn(currentToken);

  XCTAssertEqualObjects([self.provider currentDebugToken], currentToken);

  OCMVerifyAll(self.debugProviderMock);
}

#pragma mark - Debug token to FAC token exchange

- (void)testGetTokenSuccess {
  // 1. Stub internal debug provider.
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.debugProviderMock
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
  OCMVerifyAll(self.debugProviderMock);
}

- (void)testGetTokenAPIError {
  // 1. Stub internal debug provider.
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.debugProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  // 2. Validate get token.
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  // 3. Verify mock debug provider.
  OCMVerifyAll(self.debugProviderMock);
}

@end
