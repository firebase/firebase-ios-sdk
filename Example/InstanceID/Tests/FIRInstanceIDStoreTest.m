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

#import <FirebaseInstanceID/FIRInstanceIDCheckinPreferences.h>
#import <OCMock/OCMock.h>
#import "FIRInstanceIDFakeKeychain.h"
#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinService.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinStore.h"
#import "Firebase/InstanceID/FIRInstanceIDStore.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenInfo.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenStore.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"

static NSString *const kSubDirectoryName = @"FirebaseInstanceIDStoreTest";

static NSString *const kAuthorizedEntity = @"test-audience";
static NSString *const kScope = @"test-scope";
static NSString *const kToken = @"test-token";
static NSString *const kAuthID = @"test-auth-id";
static NSString *const kSecret = @"test-secret";

@interface FIRInstanceIDStore ()

- (NSString *)tokenWithKey:(NSString *)key;
- (void)cacheToken:(NSString *)token withKey:(NSString *)key;

// APNS
+ (NSString *)legacyAPNSTokenCacheKeyForServerType:(BOOL)isSandbox;
+ (NSData *)dataWithHexString:(NSString *)hex;

- (void)resetCredentialsIfNeeded;
- (BOOL)hasSavedLibraryVersion;
- (BOOL)hasCheckinPlist;

@end

@interface FIRInstanceIDStoreTest : XCTestCase

@property(strong, nonatomic) FIRInstanceIDStore *instanceIDStore;
@property(strong, nonatomic) FIRInstanceIDBackupExcludedPlist *checkinPlist;
@property(strong, nonatomic) FIRInstanceIDCheckinStore *checkinStore;
@property(strong, nonatomic) FIRInstanceIDTokenStore *tokenStore;
@property(strong, nonatomic) id mockCheckinStore;
@property(strong, nonatomic) id mockTokenStore;
@property(strong, nonatomic) id mockInstanceIDStore;

@end

@implementation FIRInstanceIDStoreTest

- (void)setUp {
  [super setUp];
  [FIRInstanceIDStore createSubDirectory:kSubDirectoryName];

  NSString *checkinPlistName = @"com.google.test.IIDStoreTestCheckin";
  self.checkinPlist = [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:checkinPlistName
                                                                    subDirectory:kSubDirectoryName];

  // checkin store
  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  _checkinStore = [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:self.checkinPlist
                                                                 keychain:fakeKeychain];
  _mockCheckinStore = OCMPartialMock(_checkinStore);
  // token store
  FIRInstanceIDFakeKeychain *fakeTokenKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  _tokenStore = [[FIRInstanceIDTokenStore alloc] initWithKeychain:fakeTokenKeychain];
  _mockTokenStore = OCMPartialMock(_tokenStore);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  _instanceIDStore = [[FIRInstanceIDStore alloc] initWithCheckinStore:_mockCheckinStore
                                                           tokenStore:_mockTokenStore
                                                             delegate:nil];
#pragma clang diagnostic pop
  _mockInstanceIDStore = OCMPartialMock(_instanceIDStore);
}

- (void)tearDown {
  [self.instanceIDStore removeAllCachedTokensWithHandler:nil];
  [self.instanceIDStore removeCheckinPreferencesWithHandler:nil];
  [FIRInstanceIDStore removeSubDirectory:kSubDirectoryName error:nil];
  [_mockCheckinStore stopMocking];
  [_mockTokenStore stopMocking];
  [_mockInstanceIDStore stopMocking];
  [super tearDown];
}

/**
 *  Tests that an InstanceID token can be stored in the FIRInstanceIDStore for
 *  an authorizedEntity and scope.
 */
- (void)testSaveToken {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"token is saved"];
  FIRInstanceIDTokenInfo *tokenInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kScope
                                                         token:kToken
                                                    appVersion:@"1.0"
                                                 firebaseAppID:@"firebaseAppID"];
  [self.instanceIDStore saveTokenInfo:tokenInfo
                              handler:^(NSError *error) {
                                XCTAssertNil(error);
                                FIRInstanceIDTokenInfo *retrievedTokenInfo = [self.instanceIDStore
                                    tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                            scope:kScope];
                                XCTAssertEqualObjects(retrievedTokenInfo.token, kToken);
                                [tokenExpectation fulfill];
                              }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a token can be removed from from FIRInstanceIDStore's cache when specifying
 *  its authorizedEntity and scope.
 */
- (void)testRemoveCachedToken {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"token is removed"];
  FIRInstanceIDTokenInfo *tokenInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kScope
                                                         token:kToken
                                                    appVersion:@"1.0"
                                                 firebaseAppID:@"firebaseAppID"];
  [self.instanceIDStore
      saveTokenInfo:tokenInfo
            handler:^(NSError *error) {
              XCTAssertNotNil([self.instanceIDStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                            scope:kScope]);

              [self.instanceIDStore removeCachedTokenWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope];
              XCTAssertNil([self.instanceIDStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                         scope:kScope]);
              [tokenExpectation fulfill];
            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a checkin authentication ID can be stored in the FIRInstanceIDStore.
 */
- (void)testSaveCheckinAuthID {
  XCTestExpectation *checkinExpectation = [self expectationWithDescription:@"checkin is saved"];
  NSDictionary *plistContent = @{
    kFIRInstanceIDDigestStringKey : @"digest-xyz",
    kFIRInstanceIDLastCheckinTimeKey : @(FIRInstanceIDCurrentTimestampInMilliseconds())
  };
  FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:plistContent];
  [self.instanceIDStore
      saveCheckinPreferences:preferences
                     handler:^(NSError *_Nonnull error) {
                       XCTAssertNil(error);
                       FIRInstanceIDCheckinPreferences *cachedPreferences =
                           [self.instanceIDStore cachedCheckinPreferences];

                       XCTAssertEqualObjects(cachedPreferences.deviceID, kAuthID);
                       XCTAssertEqualObjects(cachedPreferences.secretToken, kSecret);
                       [checkinExpectation fulfill];
                     }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 *  Tests that a checkin authentication ID can be removed from FIRInstanceIDStore's cache.
 */
- (void)testRemoveCheckinPreferences {
  XCTestExpectation *checkinExpectation = [self expectationWithDescription:@"checkin is removed"];
  NSDictionary *plistContent = @{
    kFIRInstanceIDDigestStringKey : @"digest-xyz",
    kFIRInstanceIDLastCheckinTimeKey : @(FIRInstanceIDCurrentTimestampInMilliseconds())
  };
  FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:plistContent];

  [self.instanceIDStore
      saveCheckinPreferences:preferences
                     handler:^(NSError *error) {
                       XCTAssertNil(error);

                       [self.instanceIDStore
                           removeCheckinPreferencesWithHandler:^(NSError *_Nullable error) {
                             XCTAssertNil(error);

                             FIRInstanceIDCheckinPreferences *cachedPreferences =
                                 [self.instanceIDStore cachedCheckinPreferences];
                             XCTAssertNil(cachedPreferences.deviceID);
                             XCTAssertNil(cachedPreferences.secretToken);
                             [checkinExpectation fulfill];
                           }];
                     }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testResetCredentialsWithFreshInstall {
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  // Expect checkin is removed if it's a fresh install.
  [[_mockCheckinStore expect]
      removeCheckinPreferencesWithHandler:[OCMArg invokeBlockWithArgs:[NSNull null], nil]];
  // Always setting up stub after expect.
  OCMStub([_mockCheckinStore cachedCheckinPreferences]).andReturn(checkinPreferences);
  // Plist file doesn't exist, meaning this is a fresh install.
  OCMStub([_mockCheckinStore hasCheckinPlist]).andReturn(NO);

  [_mockInstanceIDStore resetCredentialsIfNeeded];
  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithoutFreshInstall {
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  // Expect migration happens if it's not a fresh install.
  [[_mockCheckinStore expect] migrateCheckinItemIfNeeded];
  // Always setting up stub after expect.
  OCMStub([_mockCheckinStore cachedCheckinPreferences]).andReturn(checkinPreferences);
  // Mock plist exists, meaning this is not a fresh install.
  OCMStub([_mockCheckinStore hasCheckinPlist]).andReturn(YES);

  [_mockInstanceIDStore resetCredentialsIfNeeded];
  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithNoCachedCheckin {
  id niceMockCheckinStore = [OCMockObject niceMockForClass:[FIRInstanceIDCheckinStore class]];
  [[niceMockCheckinStore reject]
      removeCheckinPreferencesWithHandler:[OCMArg invokeBlockWithArgs:[NSNull null], nil]];
  // Always setting up stub after expect.
  OCMStub([_checkinStore cachedCheckinPreferences]).andReturn(nil);

  [_instanceIDStore resetCredentialsIfNeeded];
  OCMVerifyAll(niceMockCheckinStore);
}
@end
