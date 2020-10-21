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
#import "OCMock.h"

#import "FirebaseAppCheck/Source/Library/Core/Private/FIRAppCheckInternal.h"
#import "FirebaseAppCheck/Source/Library/DebugProvider/Public/FIRAppCheckDebugProvider.h"

static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";

@interface FIRAppCheckDebugProviderTests : XCTestCase

@property(nonatomic) FIRAppCheckDebugProvider *provider;
@property(nonatomic) id processInfoMock;

@end

typedef void (^FIRAppCheckTokenValidationBlock)(FIRAppCheckToken *_Nullable token,
                                                NSError *_Nullable error);

@implementation FIRAppCheckDebugProviderTests

- (void)setUp {
  self.provider = [[FIRAppCheckDebugProvider alloc] init];

  self.processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);
}

- (void)tearDown {
  self.provider = nil;
  [self.processInfoMock stopMocking];
  self.processInfoMock = nil;
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDebugTokenUserDefaultsKey];
}

- (void)testGetTokenWhenEnvironmentVariableSetAndTokenStored {
  [[NSUserDefaults standardUserDefaults] setObject:@"stored token"
                                            forKey:kDebugTokenUserDefaultsKey];
  NSString *envToken = @"env token";
  OCMStub([self.processInfoMock processInfo]).andReturn(self.processInfoMock);
  OCMExpect([self.processInfoMock environment]).andReturn(@{kDebugTokenEnvKey : envToken});

  [self validateGetToken:^void(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(token.token, envToken);
  }];
}

- (void)testGetTokenWhenNoEnvironmentVariableAndTokenStored {
  NSString *storedToken = @"stored token";
  [[NSUserDefaults standardUserDefaults] setObject:storedToken forKey:kDebugTokenUserDefaultsKey];

  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);

  [self validateGetToken:^void(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(token.token, storedToken);
  }];
}

- (void)testGetTokenWhenNoEnvironmentVariableAndNoTokenStored {
  XCTAssertNil(NSProcessInfo.processInfo.environment[kDebugTokenEnvKey]);
  XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey]);

  __block NSString *generatedToken;
  [self validateGetToken:^void(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertNotNil(token.token);
    generatedToken = token.token;
  }];

  XCTAssertEqualObjects(
      [[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey],
      generatedToken);
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
