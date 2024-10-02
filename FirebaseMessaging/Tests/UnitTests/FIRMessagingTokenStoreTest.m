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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingBackupExcludedPlist.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenStore.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeKeychain.h"

static NSString *const kSubDirectoryName = @"FirebaseMessagingStoreTest";

static NSString *const kAuthorizedEntity = @"test-audience";
static NSString *const kScope = @"test-scope";
static NSString *const kToken = @"test-token";
static NSString *const kAuthID = @"test-auth-id";
static NSString *const kSecret = @"test-secret";
static NSString *const kFakeCheckinPlistName = @"com.google.test.TestTokenStore";

@interface FIRMessaging (ExposedForTest)
+ (BOOL)createSubDirectory:(NSString *)subDirectoryName;
@end

@interface FIRMessagingCheckinStore ()

@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;

@end

@interface FIRMessagingTokenStore ()

@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;

@end

@interface FIRMessagingBackupExcludedPlist (ExposedForTest)

- (BOOL)deleteFile:(NSError **)error;

@end

@interface FIRMessagingTokenStoreTest : XCTestCase

@property(strong, nonatomic) FIRMessagingBackupExcludedPlist *checkinPlist;
@property(strong, nonatomic) FIRMessagingCheckinStore *checkinStore;
@property(strong, nonatomic) FIRMessagingTokenStore *tokenStore;
@property(strong, nonatomic) id mockCheckinStore;
@property(strong, nonatomic) id mockTokenStore;
@property(strong, nonatomic) id mockMessagingStore;

@end

@implementation FIRMessagingTokenStoreTest

- (void)setUp {
  [super setUp];
  [FIRMessaging createSubDirectory:kSubDirectoryName];

  self.checkinPlist =
      [[FIRMessagingBackupExcludedPlist alloc] initWithPlistFile:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];

  // checkin store
  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  _checkinStore = [[FIRMessagingCheckinStore alloc] init];
  _checkinStore.keychain = fakeKeychain;

  _mockCheckinStore = OCMPartialMock(_checkinStore);
  // token store
  _tokenStore = [[FIRMessagingTokenStore alloc] init];
  _tokenStore.keychain = fakeKeychain;
  _mockTokenStore = OCMPartialMock(_tokenStore);
}

- (void)tearDown {
  [self.checkinPlist deleteFile:nil];
  [_tokenStore removeAllTokensWithHandler:nil];
  [_mockCheckinStore stopMocking];
  [_mockTokenStore stopMocking];
  [_mockMessagingStore stopMocking];
  [super tearDown];
}

/**
 *  Tests that an Messaging token can be stored in the FIRMessagingStore for
 *  an authorizedEntity and scope.
 */
- (void)testSaveToken {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"token is saved"];
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"firebaseAppID"];
  [self.tokenStore saveTokenInfo:tokenInfo
                         handler:^(NSError *error) {
                           XCTAssertNil(error);
                           FIRMessagingTokenInfo *retrievedTokenInfo =
                               [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                        scope:kScope];
                           XCTAssertEqualObjects(retrievedTokenInfo.token, kToken);
                           [tokenExpectation fulfill];
                         }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a token can be removed from from FIRMessagingStore's cache when specifying
 *  its authorizedEntity and scope.
 */
- (void)testRemoveCachedToken {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"token is removed"];
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"firebaseAppID"];
  [self.tokenStore
      saveTokenInfo:tokenInfo
            handler:^(NSError *error) {
              XCTAssertNotNil([self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                       scope:kScope]);

              [self.tokenStore removeTokenWithAuthorizedEntity:kAuthorizedEntity scope:kScope];
              XCTAssertNil([self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope]);
              [tokenExpectation fulfill];
            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a checkin authentication ID can be stored in the FIRMessagingStore.
 */
- (void)testSaveCheckinAuthID {
  XCTestExpectation *checkinExpectation = [self expectationWithDescription:@"checkin is saved"];
  NSDictionary *plistContent = @{
    kFIRMessagingDigestStringKey : @"digest-xyz",
    kFIRMessagingLastCheckinTimeKey : @(FIRMessagingCurrentTimestampInMilliseconds())
  };
  FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:plistContent];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *_Nonnull error) {
                                      XCTAssertNil(error);
                                      FIRMessagingCheckinPreferences *cachedPreferences =
                                          [self.checkinStore cachedCheckinPreferences];

                                      XCTAssertEqualObjects(cachedPreferences.deviceID, kAuthID);
                                      XCTAssertEqualObjects(cachedPreferences.secretToken, kSecret);
                                      [checkinExpectation fulfill];
                                    }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a checkin authentication ID can be removed from FIRMessagingStore's cache.
 */
- (void)testRemoveCheckinPreferences {
  XCTestExpectation *checkinExpectation = [self expectationWithDescription:@"checkin is removed"];
  NSDictionary *plistContent = @{
    kFIRMessagingDigestStringKey : @"digest-xyz",
    kFIRMessagingLastCheckinTimeKey : @(FIRMessagingCurrentTimestampInMilliseconds())
  };
  FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:plistContent];

  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNil(error);

                                      [self.checkinStore removeCheckinPreferencesWithHandler:^(
                                                             NSError *_Nullable error) {
                                        XCTAssertNil(error);

                                        FIRMessagingCheckinPreferences *cachedPreferences =
                                            [self.checkinStore cachedCheckinPreferences];
                                        XCTAssertNil(cachedPreferences.deviceID);
                                        XCTAssertNil(cachedPreferences.secretToken);
                                        [checkinExpectation fulfill];
                                      }];
                                    }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Private Helpers
- (NSString *)pathForCheckinPlist {
  NSArray *paths =
      NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES);
  NSString *plistNameWithExtension = [NSString stringWithFormat:@"%@.plist", kFakeCheckinPlistName];
  return [paths[0] stringByAppendingPathComponent:plistNameWithExtension];
}
@end
