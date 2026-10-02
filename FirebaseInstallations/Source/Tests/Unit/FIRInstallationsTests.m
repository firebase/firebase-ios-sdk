/*
 * Copyright 2019 Google
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

#import <Security/Security.h>
#import <TargetConditionals.h>
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FBLPromise+Testing.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallations+Tests.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsErrorUtil+Tests.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsErrorUtil.h"
#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsHTTPError.h"
#import "FirebaseInstallations/Source/Library/FIRInstallationsAuthTokenResultInternal.h"
#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDStore.h"
#import "FirebaseInstallations/Source/Library/InstallationsIDController/FIRInstallationsIDController.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredAuthToken.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallations.h"

@interface FIRInstallationsTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@property(nonatomic) id mockIDController;
@property(nonatomic) FIROptions *appOptions;
@end

@interface FIRInstallationsIIDStore (Tests)
- (NSDictionary *)keyQueryForKeyWithTagPrefix:(NSString *)tagPrefix;
- (NSString *)keychainKeyTagWithPrefix:(NSString *)prefix;
- (BOOL)deleteKeychainKeyWithTagPrefix:(NSString *)tagPrefix error:(NSError **)outError;
- (NSString *)plistPath;
@end

@implementation FIRInstallationsTests

- (void)testIIDKeyDeletionSkipsMissingTag {
  id store = OCMPartialMock([[FIRInstallationsIIDStore alloc] init]);
  OCMStub([store keychainKeyTagWithPrefix:[OCMArg any]]).andReturn(nil);
  XCTAssertNil([store keyQueryForKeyWithTagPrefix:@"com.google.iid.keypair.public-"]);
  XCTAssertNil([store keyQueryForKeyWithTagPrefix:@"com.google.iid.keypair.private-"]);
  NSError *error = nil;
  XCTAssertTrue([store deleteKeychainKeyWithTagPrefix:@"com.google.iid.keypair.public-"
                                                error:&error]);
  XCTAssertTrue([store deleteKeychainKeyWithTagPrefix:@"com.google.iid.keypair.private-"
                                                error:&error]);
  XCTAssertNil(error);
  [store stopMocking];
}

#if !TARGET_OS_OSX
- (void)testDeleteExistingIIDRemovesBothLegacyKeys {
  NSString *identifier = NSUUID.UUID.UUIDString;
  NSString *publicTag = [@"com.google.iid.keypair.public-" stringByAppendingString:identifier];
  NSString *privateTag = [@"com.google.iid.keypair.private-" stringByAppendingString:identifier];
  NSDictionary *attributes = @{
    (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits : @2048,
    (__bridge id)kSecPublicKeyAttrs : @{
      (__bridge id)kSecAttrIsPermanent : @YES,
      (__bridge id)kSecAttrApplicationTag : [publicTag dataUsingEncoding:NSUTF8StringEncoding]
    },
    (__bridge id)kSecPrivateKeyAttrs : @{
      (__bridge id)kSecAttrIsPermanent : @YES,
      (__bridge id)kSecAttrApplicationTag : [privateTag dataUsingEncoding:NSUTF8StringEncoding]
    }
  };
  SecKeyRef publicKey = NULL;
  SecKeyRef privateKey = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  OSStatus status =
      SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKey, &privateKey);
#pragma clang diagnostic pop
  if (publicKey) {
    CFRelease(publicKey);
  }
  if (privateKey) {
    CFRelease(privateKey);
  }
  XCTAssertEqual(status, errSecSuccess);

  id store = OCMPartialMock([[FIRInstallationsIIDStore alloc] init]);
  OCMStub([store keychainKeyTagWithPrefix:@"com.google.iid.keypair.public-"]).andReturn(publicTag);
  OCMStub([store keychainKeyTagWithPrefix:@"com.google.iid.keypair.private-"])
      .andReturn(privateTag);
  OCMStub([store plistPath])
      .andReturn([NSTemporaryDirectory() stringByAppendingPathComponent:identifier]);
  NSDictionary *publicQuery = [store keyQueryForKeyWithTagPrefix:@"com.google.iid.keypair.public-"];
  NSDictionary *privateQuery =
      [store keyQueryForKeyWithTagPrefix:@"com.google.iid.keypair.private-"];
  @try {
    XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)publicQuery, NULL), errSecSuccess);
    XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)privateQuery, NULL),
                   errSecSuccess);
    FBLPromise<NSNull *> *promise = [store deleteExistingIID];
    XCTAssertTrue(FBLWaitForPromisesWithTimeout(5));
    XCTAssertTrue(promise.isFulfilled);
    XCTAssertNil(promise.error);
    XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)publicQuery, NULL),
                   errSecItemNotFound);
    XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)privateQuery, NULL),
                   errSecItemNotFound);
  } @finally {
    SecItemDelete((__bridge CFDictionaryRef)publicQuery);
    SecItemDelete((__bridge CFDictionaryRef)privateQuery);
    [store stopMocking];
  }
}
#endif

- (void)testIIDKeyQueryUsesRequestedTagPrefix {
  FIRInstallationsIIDStore *IIDStore = [[FIRInstallationsIIDStore alloc] init];
  NSString *privateTagPrefix = @"com.google.iid.keypair.private-";
  NSDictionary *query = [IIDStore keyQueryForKeyWithTagPrefix:privateTagPrefix];
  NSData *tagData = query[(__bridge id)kSecAttrApplicationTag];
  NSString *tag = [[NSString alloc] initWithData:tagData encoding:NSUTF8StringEncoding];

  XCTAssertTrue([tag hasPrefix:privateTagPrefix]);
  XCTAssertFalse([tag containsString:@"keypair.public-"]);
}

- (void)setUp {
  [super setUp];

  self.appOptions = [[FIROptions alloc] initWithGoogleAppID:@"GoogleAppID"
                                                GCMSenderID:@"GCMSenderID"];
  self.appOptions.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  self.appOptions.projectID = @"ProjectID";

  self.mockIDController = OCMClassMock([FIRInstallationsIDController class]);
  self.installations = [[FIRInstallations alloc] initWithAppOptions:self.appOptions
                                                            appName:@"appName"
                                          installationsIDController:self.mockIDController
                                                  prefetchAuthToken:NO];
}

- (void)tearDown {
  self.installations = nil;
  self.mockIDController = nil;
  [super tearDown];
}

- (void)testDefaultInstallationWhenNoDefaultAppThenIsNil {
  XCTAssertThrows([FIRInstallations installations]);
}

- (void)testInstallationIDSuccess {
  // Stub get installation.
  FIRInstallationsItem *installation = [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockIDController getInstallationItem])
      .andReturn([FBLPromise resolvedWith:installation]);

  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(identifier);
        XCTAssertEqualObjects(identifier, installation.firebaseInstallationID);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testInstallationIDError {
  // Stub get installation.
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  NSError *privateError = [NSError errorWithDomain:@"TestsError" code:-1 userInfo:nil];
  [errorPromise reject:privateError];

  OCMExpect([self.mockIDController getInstallationItem]).andReturn(errorPromise);

  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(identifier);
        XCTAssertNotNil(error);

        XCTAssertEqualObjects(error.domain, kFirebaseInstallationsErrorDomain);
        XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], errorPromise.error);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenSuccess {
  FIRInstallationsItem *installationWithToken =
      [FIRInstallationsItem createRegisteredInstallationItemWithAppID:self.appOptions.googleAppID
                                                              appName:@"appName"];
  installationWithToken.authToken.token = @"token";
  installationWithToken.authToken.expirationDate = [NSDate dateWithTimeIntervalSinceNow:1000];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:NO])
      .andReturn([FBLPromise resolvedWith:installationWithToken]);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThan(tokenResult.authToken.length, 0);
        XCTAssertTrue([tokenResult.expirationDate laterDate:[NSDate date]]);
        XCTAssertNil(error);

        [tokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenError {
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  [errorPromise reject:[FIRInstallationsErrorUtil
                           APIErrorWithHTTPCode:FIRInstallationsHTTPCodesServerInternalError]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:NO]).andReturn(errorPromise);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNil(tokenResult);
        XCTAssertEqualObjects(error, errorPromise.error);

        [tokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenForcingRefreshSuccess {
  FIRInstallationsItem *installationWithToken =
      [FIRInstallationsItem createRegisteredInstallationItemWithAppID:self.appOptions.googleAppID
                                                              appName:@"appName"];
  installationWithToken.authToken.token = @"token";
  installationWithToken.authToken.expirationDate = [NSDate dateWithTimeIntervalSinceNow:1000];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:YES])
      .andReturn([FBLPromise resolvedWith:installationWithToken]);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenForcingRefresh:YES
                   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                     XCTAssertNil(error);
                     XCTAssertNotNil(tokenResult);
                     XCTAssertEqualObjects(tokenResult.authToken,
                                           installationWithToken.authToken.token);
                     XCTAssertEqualObjects(tokenResult.expirationDate,
                                           installationWithToken.authToken.expirationDate);
                     [tokenExpectation fulfill];
                   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenForcingRefreshError {
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  [errorPromise reject:[FIRInstallationsErrorUtil
                           APIErrorWithHTTPCode:FIRInstallationsHTTPCodesServerInternalError]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:YES]).andReturn(errorPromise);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenForcingRefresh:YES
                   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                     XCTAssertNil(tokenResult);
                     XCTAssertEqualObjects(error, errorPromise.error);

                     [tokenExpectation fulfill];
                   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testDeleteSuccess {
  OCMExpect([self.mockIDController deleteInstallation])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"DeleteSuccess"];
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [deleteExpectation fulfill];
  }];

  [self waitForExpectations:@[ deleteExpectation ] timeout:0.5];
}

- (void)testDeleteError {
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  NSError *APIError =
      [FIRInstallationsErrorUtil APIErrorWithHTTPCode:FIRInstallationsHTTPCodesServerInternalError];
  [errorPromise reject:APIError];
  OCMExpect([self.mockIDController deleteInstallation]).andReturn(errorPromise);

  XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"deleteExpectation"];
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertEqualObjects(error, APIError);
    [deleteExpectation fulfill];
  }];

  [self waitForExpectations:@[ deleteExpectation ] timeout:0.5];
}

#pragma mark - Invalid Firebase configuration

- (void)testInitWhenProjectIDMissingThenThrow {
  FIROptions *options = [self.appOptions copy];
  options.projectID = nil;
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"missingProjectID"]);

  options.projectID = @"";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"emptyProjectID"]);
}

- (void)testInitWhenAPIKeyMissingThenThrows {
  FIROptions *options = [self.appOptions copy];
  options.APIKey = nil;
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"missingAPIKey"]);

  options.APIKey = @"";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"emptyAPIKey"]);
}

- (void)testInitWhenGoogleAppIDMissingThenThrows {
  FIROptions *options = [self.appOptions copy];
  options.googleAppID = @"";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"emptyGoogleAppID"]);
}

- (void)testInitWhenGCMSenderIDMissingThenThrows {
  FIROptions *options = [self.appOptions copy];
  options.GCMSenderID = @"";
  XCTAssertNoThrow([self createInstallationsWithAppOptions:options appName:@"emptyGCMSenderID"]);
}

- (void)testInitWhenAppNameMissingThenThrows {
  FIROptions *options = [self.appOptions copy];
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@""]);
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:nil]);
}

- (void)testInitWhenAppOptionsMissingThenThrows {
  XCTAssertThrows([self createInstallationsWithAppOptions:nil appName:@"missingOptions"]);
}

- (void)testInitWithAPIKeyIsNotMatchingExpectedFormat {
  FIROptions *options = [self.appOptions copy];
  options.APIKey = @"AIzaSy-ApiKeyTooShort_0123456789012345";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"shortAPIKey"]);

  options.APIKey = @"AIzaSy-ApiKeyWithLengthTooLong_0123456789";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"longAPIKey"]);

  options.APIKey = @"BBAIzaSy-ApiKeyInvalidFormat_0123456789";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"wrongFirstCharacter"]);

  options.APIKey = @"AIzaSy-+-ApiKeyInvalidFormat_0123456789";
  XCTAssertThrows([self createInstallationsWithAppOptions:options appName:@"invalidCharacters"]);
}

#pragma mark - Helpers

- (FIRInstallations *)createInstallationsWithAppOptions:(FIROptions *)options
                                                appName:(NSString *)appName {
  id mockIDController = OCMClassMock([FIRInstallationsIDController class]);
  return [[FIRInstallations alloc] initWithAppOptions:options
                                              appName:appName
                            installationsIDController:mockIDController
                                    prefetchAuthToken:NO];
}

@end
