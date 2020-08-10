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

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"

#import "FIRInstanceIDAuthKeychain.h"
#import "FIRInstanceIDBackupExcludedPlist.h"
#import "FIRInstanceIDCheckinPreferences+Internal.h"
#import "FIRInstanceIDStore.h"
#import "FIRInstanceIDTokenInfo.h"
#import "FIRInstanceIDTokenStore.h"

#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDTokenStore.h"

static NSString *const kFakeCheckinPlistName = @"com.google.test.IIDStoreTestCheckin";
static NSString *const kSubDirectoryName = @"FIRInstallationsIIDCheckinStoreTests";
static NSString *const kIDTokenKeychainId = @"com.google.iid-tokens";

@interface FIRInstallationsIIDTokenStoreTests : XCTestCase
@property(nonatomic) FIRInstallationsIIDTokenStore *installationsIIDCheckinStore;

@property(nonatomic) FIRInstanceIDTokenStore *IIDTokenStore;
@property(nonatomic) FIRInstanceIDAuthKeychain *IIDKeychain;

@property(nonatomic) NSString *GCMSenderID;
@end

@implementation FIRInstallationsIIDTokenStoreTests

- (void)setUp {
  self.GCMSenderID = @"GCMSenderID";
  self.installationsIIDCheckinStore =
      [[FIRInstallationsIIDTokenStore alloc] initWithGCMSenderID:self.GCMSenderID];

  self.IIDKeychain = [[FIRInstanceIDAuthKeychain alloc] initWithIdentifier:kIDTokenKeychainId];
  self.IIDTokenStore = [[FIRInstanceIDTokenStore alloc] initWithKeychain:self.IIDKeychain];
}

- (void)tearDown {
  self.IIDKeychain = nil;
  self.IIDTokenStore = nil;

  self.installationsIIDCheckinStore = nil;
}

- (void)testExistingAuthToken_WhenNoToken_ThenFails {
  [self removeIIDTokenWithScope:@"*"];

  __auto_type checkinPromise = [self.installationsIIDCheckinStore existingIIDDefaultToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isRejected);
  XCTAssertNil(checkinPromise.value);
  XCTAssertNotNil(checkinPromise.error);
}

- (void)testExistingAuthToken_WhenThereAreTokensButNoDefaultToken_ThenFails {
  [self removeIIDTokenWithScope:@"*"];
  [self saveIIDDefaultTokenForScope:@"FIAM" token:@"iid-auth-token"];

  __auto_type checkinPromise = [self.installationsIIDCheckinStore existingIIDDefaultToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isRejected);
  XCTAssertNil(checkinPromise.value);
  XCTAssertNotNil(checkinPromise.error);
}

- (void)testExistingAuthToken_WhenDataCorrupted_ThenFails {
  [self removeIIDTokenWithScope:@"*"];
  [self saveIIDDefaultTokenForScope:@"FIAM" token:@""];

  __auto_type checkinPromise = [self.installationsIIDCheckinStore existingIIDDefaultToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isRejected);
  XCTAssertNil(checkinPromise.value);
  XCTAssertNotNil(checkinPromise.error);
}

- (void)testExistingAuthTokenSuccess {
  NSString *savedToken = [self saveIIDDefaultTokenForScope:@"*" token:@"iid-auth-token"];

  __auto_type checkinPromise = [self.installationsIIDCheckinStore existingIIDDefaultToken];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(checkinPromise.isFulfilled);
  XCTAssertNil(checkinPromise.error);
  XCTAssertNotNil(checkinPromise.value);
  XCTAssert([checkinPromise.value isKindOfClass:[NSString class]]);

  XCTAssertEqualObjects(checkinPromise.value, savedToken);
}

#pragma mark - Helpers

- (NSString *)saveIIDDefaultTokenForScope:(NSString *)scope token:(NSString *)token {
  FIRInstanceIDTokenInfo *tokenInfoToSave =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:self.GCMSenderID
                                                         scope:scope
                                                         token:token
                                                    appVersion:nil
                                                 firebaseAppID:nil];

  XCTestExpectation *saveExpectation =
      [self expectationWithDescription:@"saveIIDCheckingPreferences"];
  [self.IIDTokenStore saveTokenInfo:tokenInfoToSave
                            handler:^(NSError *error) {
                              XCTAssertNil(error);
                              [saveExpectation fulfill];
                            }];

  [self waitForExpectations:@[ saveExpectation ] timeout:1];

  FIRInstanceIDTokenInfo *savedTokenInfo =
      [self.IIDTokenStore tokenInfoWithAuthorizedEntity:self.GCMSenderID scope:scope];

  XCTAssertEqualObjects(tokenInfoToSave.token, savedTokenInfo.token);

  return savedTokenInfo.token;
}

- (void)removeIIDTokenWithScope:(NSString *)scope {
  XCTestExpectation *expectation = [self expectationWithDescription:@"removeIIDTokens"];
  [self.IIDTokenStore removeTokenWithAuthorizedEntity:self.GCMSenderID scope:scope];
  [self.IIDTokenStore removeAllTokensWithHandler:^(NSError *_Nonnull error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:1];
}

@end
