/*
 * Copyright 2026 Google LLC
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

#import <AppCheckCore/AppCheckCore.h>
@import RecaptchaEnterpriseProvider;

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import <FirebaseAppCheck/FIRRecaptchaEnterpriseProvider.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

static NSString *const kAppName = @"test_app_name";
static NSString *const kAppID = @"test_app_id";
static NSString *const kAPIKey = @"test_api_key";
static NSString *const kProjectID = @"test_project_id";
static NSString *const kProjectNumber = @"123456789";
static NSString *const kSiteKey = @"test_site_key";

@interface FIRRecaptchaEnterpriseProvider (Tests)

- (instancetype)initWithRecaptchaEnterpriseProvider:(GACRecaptchaEnterpriseProvider *)recaptchaEnterpriseProvider;

@end

@interface FIRRecaptchaEnterpriseProviderTests : XCTestCase

@property(nonatomic, copy) NSString *resourceName;
@property(nonatomic) id recaptchaEnterpriseProviderMock;
@property(nonatomic) FIRRecaptchaEnterpriseProvider *provider;

@end

@implementation FIRRecaptchaEnterpriseProviderTests

- (void)setUp {
  [super setUp];

  self.resourceName = [NSString stringWithFormat:@"projects/%@/apps/%@", kProjectID, kAppID];
  self.recaptchaEnterpriseProviderMock = OCMStrictClassMock([GACRecaptchaEnterpriseProvider class]);
  self.provider =
      [[FIRRecaptchaEnterpriseProvider alloc] initWithRecaptchaEnterpriseProvider:self.recaptchaEnterpriseProviderMock];
}

- (void)tearDown {
  self.provider = nil;
  [self.recaptchaEnterpriseProviderMock stopMocking];
  self.recaptchaEnterpriseProviderMock = nil;
  [super tearDown];
}

- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.APIKey = kAPIKey;
  options.projectID = kProjectID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  app.dataCollectionDefaultEnabled = NO;

  XCTAssertNotNil([[FIRRecaptchaEnterpriseProvider alloc] initWithApp:app siteKey:kSiteKey]);
}

- (void)testInitWithIncompleteApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kAppID GCMSenderID:kProjectNumber];
  options.projectID = kProjectID;
  FIRApp *missingAPIKeyApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  missingAPIKeyApp.dataCollectionDefaultEnabled = NO;

  XCTAssertNil([[FIRRecaptchaEnterpriseProvider alloc] initWithApp:missingAPIKeyApp siteKey:kSiteKey]);

  options.projectID = nil;
  options.APIKey = kAPIKey;
  FIRApp *missingProjectIDApp = [[FIRApp alloc] initInstanceWithName:kAppName options:options];
  missingProjectIDApp.dataCollectionDefaultEnabled = NO;
  XCTAssertNil([[FIRRecaptchaEnterpriseProvider alloc] initWithApp:missingProjectIDApp siteKey:kSiteKey]);
}

- (void)testGetTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"valid_token"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.recaptchaEnterpriseProviderMock
      getTokenWithCompletion:([OCMArg
                                 invokeBlockWithArgs:validInternalToken, [NSNull null], nil])]);

  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertEqualObjects(token.token, validInternalToken.token);
        XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
        XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
        XCTAssertNil(error);
      }];

  OCMVerifyAll(self.recaptchaEnterpriseProviderMock);
}

- (void)testGetTokenAPIError {
  NSError *expectedError = [NSError errorWithDomain:@"testGetTokenAPIError" code:-1 userInfo:nil];
  OCMExpect([self.recaptchaEnterpriseProviderMock
      getTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  OCMVerifyAll(self.recaptchaEnterpriseProviderMock);
}

- (void)testGetLimitedUseTokenSuccess {
  GACAppCheckToken *validInternalToken = [[GACAppCheckToken alloc] initWithToken:@"TEST_ValidToken"
                                                                  expirationDate:[NSDate date]
                                                                  receivedAtDate:[NSDate date]];
  OCMExpect([self.recaptchaEnterpriseProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:validInternalToken,
                                                                    [NSNull null], nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                     NSError *_Nullable error) {
    XCTAssertEqualObjects(token.token, validInternalToken.token);
    XCTAssertEqualObjects(token.expirationDate, validInternalToken.expirationDate);
    XCTAssertEqualObjects(token.receivedAtDate, validInternalToken.receivedAtDate);
    XCTAssertNil(error);
  }];

  OCMVerifyAll(self.recaptchaEnterpriseProviderMock);
}

- (void)testGetLimitedUseTokenProviderError {
  NSError *expectedError = [NSError errorWithDomain:@"TEST_LimitedUseToken_Error"
                                               code:-1
                                           userInfo:nil];
  OCMExpect([self.recaptchaEnterpriseProviderMock
      getLimitedUseTokenWithCompletion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError,
                                                                    nil])]);

  [self.provider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                     NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertIdentical(error, expectedError);
  }];

  OCMVerifyAll(self.recaptchaEnterpriseProviderMock);
}

@end
