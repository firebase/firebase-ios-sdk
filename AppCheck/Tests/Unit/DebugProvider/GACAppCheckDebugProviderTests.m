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

#import "AppCheck/Sources/Core/GACAppCheckToken+Internal.h"
#import "AppCheck/Sources/DebugProvider/API/GACAppCheckDebugProviderAPIService.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";

@interface GACAppCheckDebugProvider (Tests)

- (instancetype)initWithAPIService:(id<GACAppCheckDebugProviderAPIServiceProtocol>)APIService;

@end

@interface GACAppCheckDebugProviderTests : XCTestCase

@property(nonatomic) GACAppCheckDebugProvider *provider;
@property(nonatomic) id processInfoMock;
@property(nonatomic) id fakeAPIService;

@end

typedef void (^GACAppCheckTokenValidationBlock)(GACAppCheckToken *_Nullable token,
                                                NSError *_Nullable error);

@implementation GACAppCheckDebugProviderTests

- (void)setUp {
  self.processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);

  self.fakeAPIService = OCMProtocolMock(@protocol(GACAppCheckDebugProviderAPIServiceProtocol));
  self.provider = [[GACAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];
}

- (void)tearDown {
  self.provider = nil;
  [self.processInfoMock stopMocking];
  self.processInfoMock = nil;
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
}

#pragma mark - Initialization

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];

  XCTAssertNotNil([[GACAppCheckDebugProvider alloc]
      initWithStorageID:options.googleAppID
           resourceName:[GACAppCheckDebugProviderTests resourceNameFromApp:app]
                 APIKey:app.options.APIKey
           requestHooks:nil]);
}

#pragma mark - Debug token generating/storing

- (void)testCurrentTokenWhenEnvironmentVariableSetAndTokenStored {
  [[NSUserDefaults standardUserDefaults] setObject:@"stored token"
                                            forKey:kDebugTokenUserDefaultsKey];
  NSString *envToken = @"env token";
  OCMStub([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment]).andReturn(@{kDebugTokenEnvKey : envToken});

  XCTAssertEqualObjects([self.provider currentDebugToken], envToken);
}

- (void)testCurrentTokenWhenNoEnvironmentVariableAndTokenStored {
  NSString *storedToken = @"stored token";
  [[NSUserDefaults standardUserDefaults] setObject:storedToken forKey:kDebugTokenUserDefaultsKey];

  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);

  XCTAssertEqualObjects([self.provider currentDebugToken], storedToken);
}

- (void)testCurrentTokenWhenNoEnvironmentVariableAndNoTokenStored {
  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);
  XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey]);

  NSString *generatedToken = [self.provider currentDebugToken];
  XCTAssertNotNil(generatedToken);

  // Check if the generated token is stored to the user defaults.
  XCTAssertEqualObjects(
      [[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey],
      generatedToken);

  // Check if the same token is used once generated.
  XCTAssertEqualObjects([self.provider currentDebugToken], generatedToken);
}

#pragma mark - Debug token to FAC token exchange

- (void)testGetTokenSuccess {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  GACAppCheckToken *validToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate date]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken])
      .andReturn([FBLPromise resolvedWith:validToken]);

  // 2. Validate get token.
  [self validateGetToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(token.token, validToken.token);
    XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validToken.receivedAtDate);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

- (void)testGetTokenAPIError {
  // 1. Stub API service.
  NSString *expectedDebugToken = [self.provider currentDebugToken];
  NSError *APIError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken])
      .andReturn(rejectedPromise);

  // 2. Validate get token.
  [self validateGetToken:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(error, APIError);
    XCTAssertNil(token);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

#pragma mark - Helpers

- (void)validateGetToken:(GACAppCheckTokenValidationBlock)validationBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"getToken"];
  [self.provider
      getTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        validationBlock(token, error);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:0.5];
}

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN

+ (NSString *)resourceNameFromApp:(FIRApp *)app {
  return [NSString
      stringWithFormat:@"projects/%@/apps/%@", app.options.projectID, app.options.googleAppID];
}

// FIREBASE_APP_CHECK_ONLY_END

@end
