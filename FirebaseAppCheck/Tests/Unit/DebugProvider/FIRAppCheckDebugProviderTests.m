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
#import "FirebaseAppCheck/Sources/DebugProvider/API/FIRAppCheckDebugProviderAPIService.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";

@interface FIRAppCheckDebugProvider (Tests)

- (instancetype)initWithAPIService:(id<FIRAppCheckDebugProviderAPIServiceProtocol>)APIService;

@end

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic) FIRAppCheckDebugProvider *provider;
@property(nonatomic) id processInfoMock;
@property(nonatomic) id fakeAPIService;

@end

typedef void (^FIRAppCheckTokenValidationBlock)(FIRAppCheckToken *_Nullable token,
                                                NSError *_Nullable error);

@implementation FIRAppCheckDebugProviderTests

- (void)setUp {
  self.processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);

  self.fakeAPIService = OCMProtocolMock(@protocol(FIRAppCheckDebugProviderAPIServiceProtocol));
  self.provider = [[FIRAppCheckDebugProvider alloc] initWithAPIService:self.fakeAPIService];
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

  XCTAssertNotNil([[FIRAppCheckDebugProvider alloc] initWithApp:app]);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];

  options.projectID = @"project_id";
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp"
                                                          options:options];
  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingAPIKeyApp]);

  options.projectID = nil;
  options.APIKey = @"api_key";
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp"
                                                             options:options];
  XCTAssertNil([[FIRAppCheckDebugProvider alloc] initWithApp:missingProjectIDApp]);
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
  FIRAppCheckToken *validToken = [[FIRAppCheckToken alloc] initWithToken:@"valid_token"
                                                          expirationDate:[NSDate date]
                                                          receivedAtDate:[NSDate date]];
  OCMExpect([self.fakeAPIService appCheckTokenWithDebugToken:expectedDebugToken])
      .andReturn([FBLPromise resolvedWith:validToken]);

  // 2. Validate get token.
  [self validateGetToken:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
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
  [self validateGetToken:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(error, APIError);
    XCTAssertNil(token);
  }];

  // 3. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
}

#pragma mark - Helpers

- (void)validateGetToken:(FIRAppCheckTokenValidationBlock)validationBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"getToken"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        validationBlock(token, error);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:0.5];
}

@end
