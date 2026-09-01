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
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"

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

#pragma mark - Legacy Parity Testing Mocks

// ----------------------------------------------------------------------------
// Over the years, the serialization format of FIRMessagingTokenInfo has evolved
// through three distinct eras. These mocks and tests assert that the
// current SDK can read payloads from any of these eras.
//
// Era 1 (10.18.0 and earlier):
//   APNSInfo was manually serialized into a raw NSData blob before being passed
//   to the archiver. (This is what FIRMessagingTokenInfo_Legacy10 simulates).
//
// Era 2 (10.19.0 up to, and including, 12.18):
//   The NSData step was removed, and APNSInfo was just passed directly to the
//   archiver. However, the archiver itself was still insecure
//   (requiresSecureCoding = NO).
//
// Era 3 (12.19+):
//   Everything is now encoded and decoded with requiresSecureCoding = YES.
// ----------------------------------------------------------------------------

/// **Mock 1:** Represents the 10.18.0 data structure where `APNSInfo` was serialized as `NSData`.
/// To verify exact parity, diff this implementation against `FIRMessagingTokenInfo` from the
/// `10.18.0` release.
@interface FIRMessagingTokenInfo_Legacy10 : FIRMessagingTokenInfo
@end

@implementation FIRMessagingTokenInfo_Legacy10
- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:@"authorized_entity"];
  [aCoder encodeObject:self.scope forKey:@"scope"];
  [aCoder encodeObject:self.token forKey:@"token"];
  [aCoder encodeObject:self.appVersion forKey:@"app_version"];
  [aCoder encodeObject:self.firebaseAppID forKey:@"firebase_app_id"];
  NSData *rawAPNSInfo;
  if (self.APNSInfo) {
    [NSKeyedArchiver setClassName:@"FIRInstanceIDAPNSInfo" forClass:[FIRMessagingAPNSInfo class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    rawAPNSInfo = [NSKeyedArchiver archivedDataWithRootObject:self.APNSInfo];
#pragma clang diagnostic pop

    [aCoder encodeObject:rawAPNSInfo forKey:@"apns_info"];
  }
  [aCoder encodeObject:self.cacheTime forKey:@"cache_time"];
}
@end

/// **Mock 2:** Represents the `< 12.19` unarchiving logic used to decode the object.
/// To verify exact parity, diff this implementation against `FIRMessagingTokenInfo` from the
/// `12.18.0` release.
@interface FIRMessagingTokenInfo_Legacy12 : FIRMessagingTokenInfo
@end

@implementation FIRMessagingTokenInfo_Legacy12
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  BOOL needsMigration = NO;
  // These value cannot be nil

  NSString *authorizedEntity = [aDecoder decodeObjectOfClass:[NSString class]
                                                      forKey:@"authorized_entity"];
  if (!authorizedEntity) {
    return nil;
  }

  NSString *scope = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"scope"];
  if (!scope) {
    return nil;
  }

  NSString *token = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"token"];
  if (!token) {
    return nil;
  }

  // These values are nullable, so don't fail on nil.

  NSString *appVersion = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"app_version"];
  NSString *firebaseAppID = [aDecoder decodeObjectOfClass:[NSString class]
                                                   forKey:@"firebase_app_id"];
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingAPNSInfo.class ]];
  FIRMessagingAPNSInfo *rawAPNSInfo = [aDecoder decodeObjectOfClasses:classes forKey:@"apns_info"];
  if (rawAPNSInfo && ![rawAPNSInfo isKindOfClass:[FIRMessagingAPNSInfo class]]) {
    // If the decoder fails to decode a FIRMessagingAPNSInfo, check if this was archived by a
    // FirebaseMessaging 10.18.0 or earlier.
    // TODO(#12246) This block may be replaced with `rawAPNSInfo = nil` once we're confident all
    // users have upgraded to at least 10.19.0. Perhaps, after privacy manifests have been required
    // for awhile?
    @try {
      NSKeyedUnarchiver *unarchiver =
          [[NSKeyedUnarchiver alloc] initForReadingFromData:(NSData *)rawAPNSInfo error:nil];
      unarchiver.requiresSecureCoding = NO;
      [unarchiver setClass:[FIRMessagingAPNSInfo class] forClassName:@"FIRInstanceIDAPNSInfo"];
      rawAPNSInfo = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
      [unarchiver finishDecoding];
      needsMigration = YES;
    } @catch (NSException *exception) {
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeTokenInfoBadAPNSInfo,
                             @"Could not parse raw APNS Info while parsing archived token info.");
      rawAPNSInfo = nil;
    } @finally {
    }
  }

  NSDate *cacheTime = [aDecoder decodeObjectOfClass:[NSDate class] forKey:@"cache_time"];
  NSString *tokenType = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"token_type"];

  self = [super init];
  if (self) {
    // Note: We use Key-Value Coding (setValue:forKey:) here to mirror the
    // pre-fix unarchiving logic. Because this is a subclass, we cannot access the
    // private `_ivars` of the parent class. KVC injects these values
    // into the parent's readonly properties.
    [self setValue:[authorizedEntity copy] forKey:@"authorizedEntity"];
    [self setValue:[scope copy] forKey:@"scope"];
    [self setValue:[token copy] forKey:@"token"];
    [self setValue:[appVersion copy] forKey:@"appVersion"];
    [self setValue:[firebaseAppID copy] forKey:@"firebaseAppID"];
    [self setValue:[rawAPNSInfo copy] forKey:@"APNSInfo"];
    [self setValue:cacheTime forKey:@"cacheTime"];
    [self setValue:@(needsMigration) forKey:@"needsMigration"];
    [self setValue:([tokenType copy] ?: @"V4") forKey:@"tokenType"];
  }
  return self;
}
@end

/// **Mock 3:** Simulates a 10.18.0 payload where the raw APNS Info NSData is corrupted/garbage.
@interface FIRMessagingTokenInfo_Legacy10Corrupt : FIRMessagingTokenInfo
@end

@implementation FIRMessagingTokenInfo_Legacy10Corrupt
- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:@"authorized_entity"];
  [aCoder encodeObject:self.scope forKey:@"scope"];
  [aCoder encodeObject:self.token forKey:@"token"];
  [aCoder encodeObject:self.appVersion forKey:@"app_version"];
  [aCoder encodeObject:self.firebaseAppID forKey:@"firebase_app_id"];

  // Inject garbage data as the APNSInfo archive to simulate a corrupt payload
  NSData *garbageData = [@"corrupt_apns_data" dataUsingEncoding:NSUTF8StringEncoding];
  [aCoder encodeObject:garbageData forKey:@"apns_info"];

  [aCoder encodeObject:self.cacheTime forKey:@"cache_time"];
}
@end

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

/// **Scenario:** A comprehensive matrix proving a user can upgrade to the new SDK, run it, save
/// data, and then downgrade back to the old SDK without breaking anything.
/// **What it does:** Encodes
/// insecurely (simulating old data) ➔ Decodes securely (simulating new SDK upgrade) ➔ Encodes
/// securely (simulating saving in new SDK) ➔ Decodes insecurely using the exact
/// `FIRMessagingTokenInfo_Legacy12` mock.
- (void)testTokenInfoDowngradeRoundTrip_10_19_Plus {
  FIRMessagingTokenInfo *info = self.validTokenInfo;
  NSError *error;

  // 1. Old (Insecure) Encoding
  NSData *legacyArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  legacyArchive = [NSKeyedArchiver archivedDataWithRootObject:info];
#pragma clang diagnostic pop

  // 2. New (Secure) Decoding
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *securelyRestoredInfo =
      [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:legacyArchive error:&error];
  XCTAssertNil(error);

  // 3. New (Secure) Encoding
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
  NSData *secureArchive = [NSKeyedArchiver archivedDataWithRootObject:securelyRestoredInfo
                                                requiringSecureCoding:YES
                                                                error:&error];
  XCTAssertNil(error);

  // 4. Old (Insecure) Decoding using exact pre-fix logic
  NSKeyedUnarchiver *insecureUnarchiver =
      [[NSKeyedUnarchiver alloc] initForReadingFromData:secureArchive error:&error];
  insecureUnarchiver.requiresSecureCoding = NO;
  [insecureUnarchiver setClass:[FIRMessagingTokenInfo_Legacy12 class]
                  forClassName:@"FIRInstanceIDTokenInfo"];
  // The 12.18.0 SDK applied this mapping directly in FIRMessagingTokenStore prior to decoding.
  // We manually inject it here to accurately simulate the legacy unarchiving environment.
  [insecureUnarchiver setClass:[FIRMessagingAPNSInfo class] forClassName:@"FIRInstanceIDAPNSInfo"];
  FIRMessagingTokenInfo *downgradedInfo =
      [insecureUnarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
  [insecureUnarchiver finishDecoding];

  XCTAssertNotNil(downgradedInfo);
  XCTAssertEqualObjects(downgradedInfo.token, info.token);
  XCTAssertEqualObjects(downgradedInfo.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
}

/// **Scenario:** The extreme legacy fallback. Simulates a user upgrading from Firebase 10.18.0
/// (where `APNSInfo` was wrapped as a raw `NSData` blob) to the new SDK, and then downgrading.
/// **What it does:** Encodes using the `FIRMessagingTokenInfo_Legacy10` mock to generate the raw
/// `NSData` blob ➔ Decodes securely (proving our `try/catch` fallback block recovers the data) ➔
/// Encodes securely (normalizing it to a real object) ➔ Decodes insecurely via the pre-fix mock to
/// ensure the newly normalized data is backwards-compatible.
- (void)testTokenInfoDowngradeRoundTrip_10_18_Minus {
  FIRMessagingTokenInfo *info = self.validTokenInfo;
  NSError *error;

  // 1. Create the 10.18.0 data structure where APNSInfo is an NSData object
  FIRMessagingTokenInfo_Legacy10 *legacyInfo =
      [[FIRMessagingTokenInfo_Legacy10 alloc] initWithAuthorizedEntity:info.authorizedEntity
                                                                 scope:info.scope
                                                                 token:info.token
                                                            appVersion:info.appVersion
                                                         firebaseAppID:info.firebaseAppID
                                                             tokenType:@"V4"];
  legacyInfo.APNSInfo = info.APNSInfo;
  legacyInfo.cacheTime = info.cacheTime;

  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo"
                       forClass:[FIRMessagingTokenInfo_Legacy10 class]];
  NSData *legacyArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  legacyArchive = [NSKeyedArchiver archivedDataWithRootObject:legacyInfo];
#pragma clang diagnostic pop

  // 2. New (Secure) Decoding (MUST successfully hit the NSData migration block)
  [NSKeyedUnarchiver setClass:[FIRMessagingTokenInfo class] forClassName:@"FIRInstanceIDTokenInfo"];
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *securelyRestoredInfo =
      [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:legacyArchive error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(securelyRestoredInfo);
  XCTAssertNotNil(securelyRestoredInfo.APNSInfo);

  // 3. New (Secure) Encoding (APNSInfo is now normalized to a real object)
  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo" forClass:[FIRMessagingTokenInfo class]];
  NSData *secureArchive = [NSKeyedArchiver archivedDataWithRootObject:securelyRestoredInfo
                                                requiringSecureCoding:YES
                                                                error:&error];
  XCTAssertNil(error);

  // 4. Old (Insecure) Decoding using exact pre-fix logic
  NSKeyedUnarchiver *insecureUnarchiver =
      [[NSKeyedUnarchiver alloc] initForReadingFromData:secureArchive error:&error];
  insecureUnarchiver.requiresSecureCoding = NO;
  [insecureUnarchiver setClass:[FIRMessagingTokenInfo_Legacy12 class]
                  forClassName:@"FIRInstanceIDTokenInfo"];
  // The 12.18.0 SDK applied this mapping directly in FIRMessagingTokenStore prior to decoding.
  // We manually inject it here to accurately simulate the legacy unarchiving environment.
  [insecureUnarchiver setClass:[FIRMessagingAPNSInfo class] forClassName:@"FIRInstanceIDAPNSInfo"];
  FIRMessagingTokenInfo *downgradedInfo =
      [insecureUnarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
  [insecureUnarchiver finishDecoding];

  XCTAssertNotNil(downgradedInfo);
  XCTAssertEqualObjects(downgradedInfo.token, info.token);
  XCTAssertEqualObjects(downgradedInfo.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
}

/// **Scenario:** A user upgrades from a version prior to 10.19.0, but the cached APNS info
/// data in the keychain is corrupted.
/// **What it does:** Uses `FIRMessagingTokenInfo_Legacy10Corrupt` to write a corrupted data
/// payload, decodes it with the new SDK, and asserts that the token info is still readable but
/// `needsMigration` is NOT set to YES (avoiding overwriting/deleting the token on disk).
- (void)testTokenInfoDoesNotMigrateOnCorruptedLegacyAPNSInfo {
  FIRMessagingTokenInfo *info = self.validTokenInfo;
  NSError *error;

  // 1. Create the corrupted 10.18.0 data structure
  FIRMessagingTokenInfo_Legacy10Corrupt *corruptInfo =
      [[FIRMessagingTokenInfo_Legacy10Corrupt alloc] initWithAuthorizedEntity:info.authorizedEntity
                                                                        scope:info.scope
                                                                        token:info.token
                                                                   appVersion:info.appVersion
                                                                firebaseAppID:info.firebaseAppID
                                                                    tokenType:@"V4"];
  corruptInfo.cacheTime = info.cacheTime;

  [NSKeyedArchiver setClassName:@"FIRInstanceIDTokenInfo"
                       forClass:[FIRMessagingTokenInfo_Legacy10Corrupt class]];
  NSData *corruptArchive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  corruptArchive = [NSKeyedArchiver archivedDataWithRootObject:corruptInfo];
#pragma clang diagnostic pop

  // 2. Decode securely
  [NSKeyedUnarchiver setClass:[FIRMessagingTokenInfo class] forClassName:@"FIRInstanceIDTokenInfo"];
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingTokenInfo.class, NSDate.class ]];
  FIRMessagingTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                            fromData:corruptArchive
                                                                               error:&error];

  XCTAssertNil(error);
  XCTAssertNotNil(restoredInfo);

  // 3. Assertions
  XCTAssertEqualObjects(restoredInfo.token, info.token);  // Core token info should still survive
  XCTAssertNil(restoredInfo.APNSInfo);                    // APNSInfo must fail gracefully (nil)
  XCTAssertFalse(restoredInfo.needsMigration);  // CRITICAL: must NOT flag for destructive save
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
