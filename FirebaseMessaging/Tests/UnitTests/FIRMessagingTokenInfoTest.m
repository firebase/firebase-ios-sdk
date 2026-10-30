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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingLegacyArchiveFixtures.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

static NSString *const kAuthorizedEntity = @"authorizedEntity";
static NSString *const kScope = @"scope";
static NSString *const kToken = @"eMP633ZkDYA:APA91bGfnlnbinRVE7nUwJSr_k6cuSTKectOlt66dKv1r_-"
                                @"9Qvhy9XljAI62QPw307rgA0MaFHPnrU5sFxGZvsncRnkfuciwTUeyRpPNDZMFhNXt"
                                @"7h1BKq9Wb2A0LAANpQefrPHVUp4p";
static NSString *const kFirebaseAppID = @"firebaseAppID";
static NSString *const kIID = @"eMP633ZkDYA";
static BOOL const kAPNSSandbox = NO;

@interface FIROptions ()
+ (NSDictionary *)defaultOptionsDictionary;
@end

@interface FIRMessagingTokenInfoTest : XCTestCase

@property(nonatomic, strong) NSData *APNSDeviceToken;
@property(nonatomic, strong) FIRMessagingTokenInfo *validTokenInfo;
@property(nonatomic, strong) id mockOptions;

@end

#pragma mark - Archive Compatibility

// ----------------------------------------------------------------------------
// The serialization format of FIRMessagingTokenInfo evolved from insecure coding
// (requiresSecureCoding = NO in Firebase 12 and earlier) to secure coding
// (requiresSecureCoding = YES in Firebase 13+).
//
// These tests assert that the Firebase 13 SDK can read legacy payloads and that
// older SDK versions can safely unarchive payloads written by Firebase 13.
//
// The legacy encoders and decoders they rely on live in
// FIRMessagingLegacyArchiveFixtures, verified line-by-line against the 10.18.0
// and 12.19.0 release tags. Keep them there: a second copy is a second thing to
// drift.
// ----------------------------------------------------------------------------

@implementation FIRMessagingTokenInfoTest

- (void)setUp {
  [super setUp];

  self.APNSDeviceToken = [@"validDeviceToken" dataUsingEncoding:NSUTF8StringEncoding];

  self.mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([self.mockOptions defaultOptionsDictionary]).andReturn(@{
    kFIRGoogleAppID : kFirebaseAppID
  });

  self.validTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:FIRMessagingCurrentAppVersion()
                                                firebaseAppID:FIRMessagingFirebaseAppID()
                                                    tokenType:@"V4"];
  self.validTokenInfo.APNSInfo =
      [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:self.APNSDeviceToken
                                              isSandbox:kAPNSSandbox];
  self.validTokenInfo.cacheTime = [NSDate date];

  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  [NSKeyedUnarchiver setClass:[FIRMessagingTokenInfo class] forClassName:@"FIRInstanceIDTokenInfo"];
}

- (void)tearDown {
  [FIROptions defaultOptions].googleAppID = kFirebaseAppID;
  [self.mockOptions stopMocking];
  [super tearDown];
}

// Test that archiving a FIRMessagingTokenInfo object and restoring it from the archive
// yields the same values for all the fields.
- (void)testTokenInfoEncodingAndDecoding {
  FIRMessagingTokenInfo *info = self.validTokenInfo;
  NSError *error;
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:info
                                          requiringSecureCoding:YES
                                                          error:&error];
  XCTAssertNil(error);
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                            fromData:archive
                                                                               error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(restoredInfo.authorizedEntity, info.authorizedEntity);
  XCTAssertEqualObjects(restoredInfo.scope, info.scope);
  XCTAssertEqualObjects(restoredInfo.token, info.token);
  XCTAssertEqualObjects(restoredInfo.appVersion, info.appVersion);
  XCTAssertEqualObjects(restoredInfo.firebaseAppID, info.firebaseAppID);
  XCTAssertEqualObjects(restoredInfo.cacheTime, info.cacheTime);
  XCTAssertEqualObjects(restoredInfo.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
  XCTAssertEqual(restoredInfo.APNSInfo.sandbox, info.APNSInfo.sandbox);
}

/// **Scenario:** A user upgrades their app from Firebase 10.19 (or 11.x/12.x) to the brand new SDK.
/// **What it does:** Archives a token insecurely (mimicking legacy data on disk) and proves our new
/// secure `unarchivedObjectOfClasses:` decoder can read it without losing the token string or
/// `APNSInfo`.
- (void)testTokenInfoLegacyEncodingCanBeSecurelyDecoded {
  FIRMessagingTokenInfo *info = self.validTokenInfo;
  NSError *error;

  // 1. Archive WITHOUT secure coding (simulate legacy data from 10.19.0+)
  NSData *archive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  archive = [NSKeyedArchiver archivedDataWithRootObject:info];
#pragma clang diagnostic pop

  // 2. Unarchive securely (NSKeyedUnarchiver unarchivedObjectOfClasses requires secure coding)
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                            fromData:archive
                                                                               error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(restoredInfo.token, info.token);
  XCTAssertEqualObjects(restoredInfo.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
}

/// Archives `tokenInfo` the way Firebase 13 does: secure coding, root object renamed to
/// `FIRInstanceIDTokenInfo`. `setClassName:forClass:` is process-global, so the incumbent mapping
/// is captured and restored rather than cleared -- production code sets this same mapping, and
/// clearing it outright would alter later tests.
- (NSData *)archiveWrittenBy13:(FIRMessagingTokenInfo *)tokenInfo {
  NSString *previousName = [NSKeyedArchiver classNameForClass:[FIRMessagingTokenInfo class]];
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
  NSError *error = nil;
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo
                                          requiringSecureCoding:YES
                                                          error:&error];
  [NSKeyedArchiver setClassName:previousName forClass:[FIRMessagingTokenInfo class]];
  XCTAssertNil(error);
  return archive;
}

/// Decodes `archive` the way Firebase 13 does: secure coding, with the `FIRInstanceIDTokenInfo`
/// mapping that `-setUp` installs (matching production).
- (FIRMessagingTokenInfo *)tokenInfoReadBy13:(NSData *)archive {
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  NSError *error = nil;
  FIRMessagingTokenInfo *tokenInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                         fromData:archive
                                                                            error:&error];
  XCTAssertNil(error);
  return tokenInfo;
}

/// **Scenario:** The full version-mixing cycle a user can actually produce with 10.19 - 12.x as
/// the starting point: upgrade to 13, downgrade back, then roll forward to 13 again.
/// **What it does:** Walks all six legs --
/// 12.x writes ➔ 13 reads ➔ 13 writes ➔ 12.x reads ➔ 12.x writes ➔ 13 reads --
/// asserting the payload survives each hop. The 12.x legs run the genuine 12.19.0 read/write
/// logic from `FIRMessagingLegacyArchiveFixtures`, not an approximation of it.
///
/// The final leg is the one that matters most: a downgrade is only safe if the record the old
/// SDK writes on its way back out is still readable by the new one. Stopping after leg 4 would
/// leave a user who reinstalls the newer build in untested territory.
- (void)testTokenInfoSurvivesUpgradeDowngradeRollForwardCycle_10_19_Plus {
  FIRMessagingTokenInfo *info = self.validTokenInfo;

  // Leg 1: a 12.x SDK writes the record.
  NSData *legacyArchive = [FIRMessagingLegacyArchiveFixtures archiveWrittenBy12:info];

  // Leg 2: the user upgrades, and 13 reads it under secure coding.
  FIRMessagingTokenInfo *upgraded = [self tokenInfoReadBy13:legacyArchive];
  XCTAssertNotNil(upgraded);
  XCTAssertEqualObjects(upgraded.token, info.token);
  XCTAssertEqualObjects(upgraded.APNSInfo.deviceToken, info.APNSInfo.deviceToken);

  // Leg 3: 13 writes it back out.
  NSData *secureArchive = [self archiveWrittenBy13:upgraded];

  // Leg 4: the user downgrades, and 12.x reads what 13 wrote. Only the root object needs a
  // mapping: `APNSInfo` has always been archived under its own class name, so a 12.x reader
  // resolves it without help.
  FIRMessagingTokenInfo *downgraded =
      [FIRMessagingLegacyArchiveFixtures tokenInfoReadBy12:secureArchive];
  XCTAssertNotNil(downgraded);
  XCTAssertEqualObjects(downgraded.token, info.token);
  XCTAssertEqualObjects(downgraded.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
  XCTAssertFalse(downgraded.needsMigration,
                 @"A 13-written record is already in the modern format, so 12.x has nothing to "
                 @"migrate.");

  // Leg 5: 12.x writes it back out.
  NSData *rewrittenArchive = [FIRMessagingLegacyArchiveFixtures archiveWrittenBy12:downgraded];

  // Leg 6: the user rolls forward to 13 again.
  FIRMessagingTokenInfo *rolledForward = [self tokenInfoReadBy13:rewrittenArchive];
  XCTAssertNotNil(rolledForward);
  XCTAssertEqualObjects(rolledForward.token, info.token);
  XCTAssertEqualObjects(rolledForward.authorizedEntity, info.authorizedEntity);
  XCTAssertEqualObjects(rolledForward.scope, info.scope);
  XCTAssertEqualObjects(rolledForward.appVersion, info.appVersion);
  XCTAssertEqualObjects(rolledForward.firebaseAppID, info.firebaseAppID);
  XCTAssertEqualObjects(rolledForward.cacheTime, info.cacheTime);
  XCTAssertEqualObjects(rolledForward.tokenType, info.tokenType);
  XCTAssertEqualObjects(rolledForward.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
  XCTAssertEqual(rolledForward.APNSInfo.sandbox, info.APNSInfo.sandbox);
  XCTAssertFalse(rolledForward.needsMigration);
}

// Test that archiving a FIRMessagingTokenInfo object with missing fields and restoring it
// from the archive yields the same values for all the fields.
- (void)testTokenInfoEncodingAndDecodingWithMissingFields {
  // Don't include appVersion, firebaseAppID, APNSInfo and cacheTime
  FIRMessagingTokenInfo *sparseInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:nil
                                                firebaseAppID:nil
                                                    tokenType:@"V4"];
  NSError *error;
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:sparseInfo
                                          requiringSecureCoding:YES
                                                          error:&error];
  XCTAssertNil(error);
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                            fromData:archive
                                                                               error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(restoredInfo.authorizedEntity, sparseInfo.authorizedEntity);
  XCTAssertEqualObjects(restoredInfo.scope, sparseInfo.scope);
  XCTAssertEqualObjects(restoredInfo.token, sparseInfo.token);
  XCTAssertNil(restoredInfo.appVersion);
  XCTAssertNil(restoredInfo.firebaseAppID);
  XCTAssertNil(restoredInfo.cacheTime);
  XCTAssertNil(restoredInfo.APNSInfo);
}

- (void)testTokenFreshnessWithLocaleChange {
  // Default should be fresh because we mock last fetch token time just now.
  XCTAssertTrue([self.validTokenInfo isFreshWithIID:kIID]);

  // Locale change should affect token refreshness.
  // Set to a different locale than the current locale.
  [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hant"
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
  // Reset locale
  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)testTokenFreshnessWithLocaleChangeWhenInstallationIdEnabled {
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  FIRMessagingTestUtilities *testUtil =
      [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  OCMStub([testUtil.mockMessaging isInstallationIdEnabled]).andReturn(YES);

  FIRMessagingTokenInfo *fidTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:FIRMessagingCurrentAppVersion()
                                                firebaseAppID:FIRMessagingFirebaseAppID()
                                                    tokenType:@"FID"];
  fidTokenInfo.APNSInfo = [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:self.APNSDeviceToken
                                                                  isSandbox:kAPNSSandbox];
  fidTokenInfo.cacheTime = [NSDate date];

  // Default should be fresh.
  XCTAssertTrue([fidTokenInfo isFreshWithIID:kIID]);

  // Set to a different locale than the current locale. Locale change should not affect FID token
  // freshness.
  [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hant"
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
  XCTAssertTrue([fidTokenInfo isFreshWithIID:kIID]);

  // Reset locale
  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [testUtil cleanupAfterTest:self];
}

- (void)testTokenFreshnessWithTokenTimestampChange {
  XCTAssertTrue([self.validTokenInfo isFreshWithIID:kIID]);
  // Set last fetch token time 7 days ago.
  NSTimeInterval lastFetchTokenTimestamp =
      FIRMessagingCurrentTimestampInSeconds() - 7 * 24 * 60 * 60;
  self.validTokenInfo.cacheTime = [NSDate dateWithTimeIntervalSince1970:lastFetchTokenTimestamp];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);

  // Set last fetch token time more than 7 days ago.
  lastFetchTokenTimestamp = FIRMessagingCurrentTimestampInSeconds() - 8 * 24 * 60 * 60;
  self.validTokenInfo.cacheTime = [NSDate dateWithTimeIntervalSince1970:lastFetchTokenTimestamp];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);

  // Set last fetch token time nil to mock legacy storage format. Token should be considered not
  // fresh.
  self.validTokenInfo.cacheTime = nil;
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
}

- (void)testTokenFreshnessWithFirebaseAppIDChange {
  XCTAssertTrue([self.validTokenInfo isFreshWithIID:kIID]);
  // Change Firebase App ID.
  [FIROptions defaultOptions].googleAppID = @"newFirebaseAppID:ios:abcdefg";
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
  [FIROptions defaultOptions].googleAppID = kFirebaseAppID;
}

- (void)testTokenFreshnessWithAppVersionChange {
  XCTAssertTrue([self.validTokenInfo isFreshWithIID:kIID]);
  // Change app version.
  self.validTokenInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:@"1.1"
                                                firebaseAppID:FIRMessagingFirebaseAppID()
                                                    tokenType:@"V4"];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
}

- (void)testTokenInconsistentWithIID {
  XCTAssertTrue([self.validTokenInfo isFreshWithIID:kIID]);
  // Change token.
  self.validTokenInfo = [[FIRMessagingTokenInfo alloc]
      initWithAuthorizedEntity:kAuthorizedEntity
                         scope:kScope
                         token:@"cxhhwVY27AE:APA91bGfnlnbinRVE7nUwJSr_k6cuSTKectOlt66dKv1r_-"
                               @"9Qvhy9XljAI62QPw307rgA0MaFHPnrU5sFxGZvsncRnkfuciwTUeyRpPNDZMFhNXt7"
                               @"h1BKq9Wb2A0LAANpQefrPHVUp4p"
                    appVersion:@"1.1"
                 firebaseAppID:FIRMessagingFirebaseAppID()
                     tokenType:@"V4"];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
}
@end
