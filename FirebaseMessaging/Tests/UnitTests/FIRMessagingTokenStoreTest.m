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
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"
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

+ (NSString *)serviceKeyForAuthorizedEntity:(NSString *)authorizedEntity scope:(NSString *)scope;
+ (nullable FIRMessagingTokenInfo *)tokenInfoFromKeychainItem:(NSData *)item;

@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;

@end

@interface FIRMessagingBackupExcludedPlist (ExposedForTest)

- (BOOL)deleteFile:(NSError **)error;

@end

#pragma mark - Legacy Parity Testing Mocks

/// **Mock:** Reproduces the `<= 10.18.0` *encoding* format, in which `apns_info` was written as a
/// nested `NSKeyedArchiver` blob (an `NSData`) rather than as a directly encoded object. The
/// nested blob names the class `FIRInstanceIDAPNSInfo`.
///
/// To verify exact parity, diff this implementation against `FIRMessagingTokenInfo` from the
/// `10.18.0` release. Note that `token_type` is absent: it was introduced later.
@interface FIRMessagingTokenInfo_Legacy10_18 : FIRMessagingTokenInfo
@end

@implementation FIRMessagingTokenInfo_Legacy10_18

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:@"authorized_entity"];
  [aCoder encodeObject:self.scope forKey:@"scope"];
  [aCoder encodeObject:self.token forKey:@"token"];
  [aCoder encodeObject:self.appVersion forKey:@"app_version"];
  [aCoder encodeObject:self.firebaseAppID forKey:@"firebase_app_id"];
  if (self.APNSInfo) {
    [NSKeyedArchiver setClassName:@"FIRInstanceIDAPNSInfo" forClass:[FIRMessagingAPNSInfo class]];
    NSData *rawAPNSInfo;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    rawAPNSInfo = [NSKeyedArchiver archivedDataWithRootObject:self.APNSInfo];
#pragma clang diagnostic pop
    // `setClassName:forClass:` is process-global, so undo it immediately. Leaving it in place
    // would rename `FIRMessagingAPNSInfo` in every subsequent archive written by this test
    // bundle.
    [NSKeyedArchiver setClassName:nil forClass:[FIRMessagingAPNSInfo class]];
    [aCoder encodeObject:rawAPNSInfo forKey:@"apns_info"];
  }
  [aCoder encodeObject:self.cacheTime forKey:@"cache_time"];
}

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
                                                firebaseAppID:@"firebaseAppID"
                                                    tokenType:@"V4"];
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
                                                firebaseAppID:@"firebaseAppID"
                                                    tokenType:@"V4"];
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

/// **Scenario:** Tests that the actual Store class connects to the keychain and passes the right
/// SecureCoding flags to read old data. **What it does:** Generates an insecure 10.19-era binary
/// blob and injects it into the mock keychain. We then call the public
/// `tokenInfoWithAuthorizedEntity:` API on the Token Store to prove the store itself extracts and
/// parses the legacy keychain item.
- (void)testTokenStoreReadsLegacyInsecureToken {
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"firebaseAppID"
                                                    tokenType:@"V4"];

  // 1. Archive WITHOUT secure coding (simulating legacy data). `setClassName:forClass:` is
  // process-global, so restore the incumbent mapping afterwards.
  NSString *previousName = [NSKeyedArchiver classNameForClass:[FIRMessagingTokenInfo class]];
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
  NSData *legacyArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  legacyArchive = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:previousName forClass:[FIRMessagingTokenInfo class]];

  // 2. Inject directly into the keychain
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [FIRMessagingTokenStore serviceKeyForAuthorizedEntity:kAuthorizedEntity
                                                                      scope:kScope];
  XCTestExpectation *expectation = [self expectationWithDescription:@"Inject legacy token"];
  [self.tokenStore.keychain setData:legacyArchive
                         forService:service
                            account:account
                            handler:^(NSError *error) {
                              XCTAssertNil(error);
                              [expectation fulfill];
                            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];

  // 3. Verify that the TokenStore's public API can read and decode it!
  FIRMessagingTokenInfo *retrievedTokenInfo =
      [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kScope];

  XCTAssertNotNil(retrievedTokenInfo);
  XCTAssertEqualObjects(retrievedTokenInfo.token, kToken);
}

/// **Scenario:** The reverse downgrade integration test.
/// **What it does:** Uses the new secure `saveTokenInfo:` API to write data to the mock keychain.
/// We then pull that binary blob out of the keychain and parse it using the deprecated
/// `[NSKeyedUnarchiver unarchiveObjectWithData:]` API to prove that an older app version can read
/// the bytes produced by the new SDK.
- (void)testLegacyTokenStoreReadsSecureToken {
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"firebaseAppID"
                                                    tokenType:@"V4"];

  // 1. Use the NEW secure coding write path
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"token is saved"];
  [self.tokenStore saveTokenInfo:tokenInfo
                         handler:^(NSError *error) {
                           XCTAssertNil(error);
                           [tokenExpectation fulfill];
                         }];
  [self waitForExpectationsWithTimeout:1 handler:nil];

  // 2. Manually read it from the keychain
  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [FIRMessagingTokenStore serviceKeyForAuthorizedEntity:kAuthorizedEntity
                                                                      scope:kScope];
  NSData *secureArchive = [self.tokenStore.keychain dataForService:service account:account];
  XCTAssertNotNil(secureArchive);

  // 3. Decode it using the old `tokenInfoFromKeychainItem:` logic. `setClass:forClassName:` is
  // process-global here (unlike the instance-scoped variant), so restore what was there before.
  Class previousClass = [NSKeyedUnarchiver classForClassName:@"FIRInstanceIDTokenInfo"];
  [NSKeyedUnarchiver setClass:[FIRMessagingTokenInfo class] forClassName:@"FIRInstanceIDTokenInfo"];
  FIRMessagingTokenInfo *downgradedInfo;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  downgradedInfo = [NSKeyedUnarchiver unarchiveObjectWithData:secureArchive];
#pragma clang diagnostic pop
  [NSKeyedUnarchiver setClass:previousClass forClassName:@"FIRInstanceIDTokenInfo"];

  XCTAssertNotNil(downgradedInfo);
  XCTAssertEqualObjects(downgradedInfo.token, kToken);
}

/// **Scenario:** A user upgrades directly from FirebaseMessaging 10.18.0 (or earlier), skipping
/// the 10.19.0 - 12.x window entirely.
/// **What it does:** Writes a token in the genuine `<= 10.18.0` on-disk format, where `apns_info`
/// is a nested `NSData` blob, then decodes it through the production
/// `tokenInfoFromKeychainItem:` path.
///
/// Both the token and its `APNSInfo` must survive. The nested blob is read under secure coding,
/// so nothing in the read path falls back to `requiresSecureCoding = NO`.
- (void)testTokenInfoFrom10_18ArchiveIsDecodedSecurely {
  FIRMessagingTokenInfo_Legacy10_18 *legacyTokenInfo =
      [[FIRMessagingTokenInfo_Legacy10_18 alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope
                                                                    token:kToken
                                                               appVersion:@"1.0"
                                                            firebaseAppID:@"firebaseAppID"
                                                                tokenType:@"V4"];
  legacyTokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc]
      initWithDeviceToken:[@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding]
                isSandbox:NO];
  legacyTokenInfo.cacheTime = [NSDate date];

  // 1. Archive in the pre-10.19 format: insecure, and rooted at `FIRInstanceIDTokenInfo`.
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo"
                       forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  NSData *legacyArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  legacyArchive = [NSKeyedArchiver archivedDataWithRootObject:legacyTokenInfo];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:nil forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  XCTAssertNotNil(legacyArchive);

  // Sanity check the fixture: `apns_info` must be a *nested* archive blob, not a directly encoded
  // object. If this fails, the mock has drifted from the 10.18.0 format and the assertions below
  // would prove nothing. The legacy class name lives inside the nested archive's bytes, so the
  // outer plist has to be walked one level down to find it.
  NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:legacyArchive
                                                                  options:NSPropertyListImmutable
                                                                   format:NULL
                                                                    error:NULL];
  BOOL embedsLegacyAPNSInfoArchive = NO;
  for (id object in plist[@"$objects"]) {
    // A nested archive is encoded as a dictionary carrying its raw bytes under "NS.data".
    id nestedData = [object isKindOfClass:[NSDictionary class]] ? object[@"NS.data"] : nil;
    if (![nestedData isKindOfClass:[NSData class]]) {
      continue;
    }
    NSDictionary *nested = [NSPropertyListSerialization propertyListWithData:nestedData
                                                                     options:NSPropertyListImmutable
                                                                      format:NULL
                                                                       error:NULL];
    if ([[nested[@"$objects"] description] containsString:@"FIRInstanceIDAPNSInfo"]) {
      embedsLegacyAPNSInfoArchive = YES;
      break;
    }
  }
  XCTAssertTrue(embedsLegacyAPNSInfoArchive,
                @"Fixture should embed a nested archive naming the legacy APNSInfo class.");

  // 2. Decode through the production read path.
  FIRMessagingTokenInfo *decodedTokenInfo =
      [FIRMessagingTokenStore tokenInfoFromKeychainItem:legacyArchive];

  // 3. Both the token and the legacy APNSInfo must survive.
  XCTAssertNotNil(decodedTokenInfo,
                  @"A pre-10.19 keychain record must not be discarded wholesale just because its "
                  @"APNSInfo is in a retired format.");
  XCTAssertEqualObjects(decodedTokenInfo.token, kToken);
  XCTAssertEqualObjects(decodedTokenInfo.authorizedEntity, kAuthorizedEntity);
  XCTAssertEqualObjects(decodedTokenInfo.scope, kScope);
  XCTAssertEqualObjects(decodedTokenInfo.APNSInfo.deviceToken,
                        [@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding],
                        @"The nested blob is still readable under secure coding, so upgrading "
                        @"must not cost the cached APNS association.");
  XCTAssertFalse(decodedTokenInfo.APNSInfo.isSandbox);
  XCTAssertTrue(decodedTokenInfo.needsMigration,
                @"A record carrying the legacy blob is exactly what `needsMigration` describes.");
}

/// **Scenario:** Guards the absence of a `FIRInstanceIDAPNSInfo` -> `FIRMessagingAPNSInfo` class
/// mapping on the *outer* decoder in `-[FIRMessagingTokenInfo initWithCoder:]`.
/// **What it does:** Archives a token in the current format and asserts the nested APNSInfo is
/// recorded under its present-day class name. Nothing renames `FIRMessagingAPNSInfo` on the write
/// path, so the outer decode needs no mapping. 10.18-and-earlier archives bury the legacy name
/// inside an opaque blob, where an outer mapping could never reach it: that name is resolved by
/// the dedicated nested unarchiver instead.
- (void)testModernArchiveRecordsAPNSInfoUnderItsCurrentClassName {
  FIRMessagingTokenInfo *tokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.0"
                                                firebaseAppID:@"firebaseAppID"
                                                    tokenType:@"V4"];
  tokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc]
      initWithDeviceToken:[@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding]
                isSandbox:NO];

  NSError *error = nil;
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo
                                          requiringSecureCoding:YES
                                                          error:&error];
  XCTAssertNil(error);

  NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive
                                                                  options:NSPropertyListImmutable
                                                                   format:NULL
                                                                    error:NULL];
  NSString *objects = [plist[@"$objects"] description];
  XCTAssertTrue([objects containsString:@"FIRMessagingAPNSInfo"]);
  XCTAssertFalse([objects containsString:@"FIRInstanceIDAPNSInfo"],
                 @"Nothing maps APNSInfo onto its legacy name, so the read path needs no mapping.");
}

/// **Scenario:** A pre-10.19 keychain record is read through the full public store API.
/// **What it does:** Injects a legacy record into the keychain, reads it via
/// `tokenInfoWithAuthorizedEntity:scope:`, and asserts the store rewrites it in the modern
/// format so the legacy blob is not re-encountered on every subsequent read.
- (void)testReadingLegacyRecordMigratesItToTheModernFormat {
  FIRMessagingTokenInfo_Legacy10_18 *legacyTokenInfo =
      [[FIRMessagingTokenInfo_Legacy10_18 alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope
                                                                    token:kToken
                                                               appVersion:@"1.0"
                                                            firebaseAppID:@"firebaseAppID"
                                                                tokenType:@"V4"];
  legacyTokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc]
      initWithDeviceToken:[@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding]
                isSandbox:NO];
  legacyTokenInfo.cacheTime = [NSDate date];

  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo"
                       forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  NSData *legacyArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  legacyArchive = [NSKeyedArchiver archivedDataWithRootObject:legacyTokenInfo];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:nil forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];

  NSString *account = FIRMessagingAppIdentifier();
  NSString *service = [FIRMessagingTokenStore serviceKeyForAuthorizedEntity:kAuthorizedEntity
                                                                      scope:kScope];
  XCTestExpectation *injected = [self expectationWithDescription:@"Inject legacy token"];
  [self.tokenStore.keychain setData:legacyArchive
                         forService:service
                            account:account
                            handler:^(NSError *error) {
                              XCTAssertNil(error);
                              [injected fulfill];
                            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];

  NSData *expectedDeviceToken = [@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding];
  FIRMessagingTokenInfo *retrieved =
      [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kScope];
  XCTAssertNotNil(retrieved);
  XCTAssertEqualObjects(retrieved.token, kToken);
  XCTAssertEqualObjects(retrieved.APNSInfo.deviceToken, expectedDeviceToken);

  // The store should have rewritten the record, so a second read no longer sees a legacy payload.
  // The rewrite must be lossless: migration is invisible to the app only if the APNS association
  // survives it, otherwise the token would be invalidated on the next APNS registration.
  FIRMessagingTokenInfo *reread = [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                           scope:kScope];
  XCTAssertNotNil(reread);
  XCTAssertEqualObjects(reread.token, kToken);
  XCTAssertEqualObjects(reread.APNSInfo.deviceToken, expectedDeviceToken);
  XCTAssertFalse(reread.needsMigration,
                 @"The legacy record should have been migrated on the first read.");
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
