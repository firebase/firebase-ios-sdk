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
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingLegacyArchiveFixtures.h"

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

  // Global, so clear it per test rather than trusting run order.
  FIRMessagingArchiveGadget.wasDecoded = NO;
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

#pragma mark - Archive Compatibility

/// The keychain service the compatibility tests below read and write.
- (NSString *)tokenServiceKey {
  return [FIRMessagingTokenStore serviceKeyForAuthorizedEntity:kAuthorizedEntity scope:kScope];
}

/// Writes `item` into the fake keychain as though a previous SDK version had left it there.
- (void)injectKeychainItem:(NSData *)item {
  XCTestExpectation *injected = [self expectationWithDescription:@"Inject keychain item"];
  [self.tokenStore.keychain setData:item
                         forService:[self tokenServiceKey]
                            account:FIRMessagingAppIdentifier()
                            handler:^(NSError *error) {
                              XCTAssertNil(error);
                              [injected fulfill];
                            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
}

/// Reads the raw bytes currently stored for this test's token, bypassing any decoding.
- (NSData *)keychainItem {
  return [self.tokenStore.keychain dataForService:[self tokenServiceKey]
                                          account:FIRMessagingAppIdentifier()];
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

  // Archive the way 12.19.0's `saveTokenInfo:` did -- insecure, rooted at
  // `FIRInstanceIDTokenInfo` -- and plant it in the keychain.
  [self injectKeychainItem:[FIRMessagingLegacyArchiveFixtures archiveWrittenBy12:tokenInfo]];

  // Verify that the TokenStore's public API can read and decode it.
  FIRMessagingTokenInfo *retrievedTokenInfo =
      [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity scope:kScope];

  XCTAssertNotNil(retrievedTokenInfo);
  XCTAssertEqualObjects(retrievedTokenInfo.token, kToken);
}

/// **Scenario:** The reverse downgrade integration test.
/// **What it does:** Uses the new secure `saveTokenInfo:` API to write data to the mock keychain,
/// pulls the binary blob back out, and parses it with 12.19.0's `tokenInfoFromKeychainItem:` and
/// `initWithCoder:` to prove an older app version can read the bytes the new SDK produced.
///
/// Routing the root object to `FIRMessagingTokenInfo_Legacy12` is what makes this a real
/// downgrade test: mapping it onto the current `FIRMessagingTokenInfo` would run Firebase 13's
/// decoder and prove only that the container is parseable.
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
  NSData *secureArchive = [self keychainItem];
  XCTAssertNotNil(secureArchive);

  // 3. Decode it with the genuine 12.19.0 read path.
  FIRMessagingTokenInfo *downgradedInfo =
      [FIRMessagingLegacyArchiveFixtures tokenInfoReadBy12:secureArchive];

  XCTAssertNotNil(downgradedInfo);
  XCTAssertEqualObjects(downgradedInfo.token, kToken);
  XCTAssertEqualObjects(downgradedInfo.authorizedEntity, kAuthorizedEntity);
  XCTAssertEqualObjects(downgradedInfo.scope, kScope);
  XCTAssertEqualObjects(downgradedInfo.appVersion, @"1.0");
  XCTAssertEqualObjects(downgradedInfo.firebaseAppID, @"firebaseAppID");
  XCTAssertEqualObjects(downgradedInfo.tokenType, @"V4");
  XCTAssertNotNil(downgradedInfo.cacheTime, @"`saveTokenInfo:` stamps the cache time on write.");
}

/// The device token embedded in every `<= 10.18.0` fixture below.
- (NSData *)legacyDeviceToken {
  return [@"deviceToken" dataUsingEncoding:NSUTF8StringEncoding];
}

/// Builds a keychain item in the genuine `<= 10.18.0` on-disk format, where `apns_info` is a
/// nested `NSKeyedArchiver` blob naming `FIRInstanceIDAPNSInfo`.
///
/// `tokenType:` is supplied but never lands in the archive: the 10.18.0 encoder had no
/// `token_type` key. That absence is the point -- see the `V4` assertions below.
- (NSData *)archiveWrittenBy10_18 {
  FIRMessagingTokenInfo_Legacy10_18 *legacyTokenInfo =
      [[FIRMessagingTokenInfo_Legacy10_18 alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                    scope:kScope
                                                                    token:kToken
                                                               appVersion:@"1.0"
                                                            firebaseAppID:@"firebaseAppID"
                                                                tokenType:@"V4"];
  legacyTokenInfo.APNSInfo =
      [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:[self legacyDeviceToken] isSandbox:NO];
  legacyTokenInfo.cacheTime = [NSDate date];
  NSData *archive = [FIRMessagingLegacyArchiveFixtures archiveWrittenBy10_18:legacyTokenInfo];
  XCTAssertNotNil(archive);
  return archive;
}

/// Asserts that `archive` really is in the pre-10.19 shape: `apns_info` must be a *nested*
/// archive blob, not a directly encoded object. Without this the tests below could pass against
/// a fixture that had silently drifted into the modern format, proving nothing. The legacy class
/// name lives inside the nested archive's bytes, so the outer plist has to be walked one level
/// down to find it.
- (void)assertArchiveEmbedsLegacyAPNSInfoBlob:(NSData *)archive {
  NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive
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
  NSData *legacyArchive = [self archiveWrittenBy10_18];
  [self assertArchiveEmbedsLegacyAPNSInfoBlob:legacyArchive];

  // Decode through the production read path.
  FIRMessagingTokenInfo *decodedTokenInfo =
      [FIRMessagingTokenStore tokenInfoFromKeychainItem:legacyArchive];

  // Both the token and the legacy APNSInfo must survive.
  XCTAssertNotNil(decodedTokenInfo,
                  @"A pre-10.19 keychain record must not be discarded wholesale just because its "
                  @"APNSInfo is in a retired format.");
  XCTAssertEqualObjects(decodedTokenInfo.token, kToken);
  XCTAssertEqualObjects(decodedTokenInfo.authorizedEntity, kAuthorizedEntity);
  XCTAssertEqualObjects(decodedTokenInfo.scope, kScope);
  XCTAssertEqualObjects(decodedTokenInfo.APNSInfo.deviceToken, [self legacyDeviceToken],
                        @"The nested blob is still readable under secure coding, so upgrading "
                        @"must not cost the cached APNS association.");
  XCTAssertFalse(decodedTokenInfo.APNSInfo.isSandbox);
  XCTAssertTrue(decodedTokenInfo.needsMigration,
                @"A record carrying the legacy blob is exactly what `needsMigration` describes.");
  XCTAssertEqualObjects(decodedTokenInfo.tokenType, @"V4",
                        @"10.18.0 archives predate the `token_type` key, so the decoder's `V4` "
                        @"default is the only thing standing between these users and a nil token "
                        @"type. It is a compatibility contract, not an implementation detail.");
}

#pragma mark - Secure coding is enforced

// The two tests below are the regression tests for the vulnerability this file's compatibility
// work exists to fix. Everything else here checks that legacy data still *decodes*; these check
// that hostile data still *does not*. Threat model: a local attacker or co-process sharing the
// keychain access group that can write to `com.google.iid-tokens`.
//
// Both would pass just as happily with `requiresSecureCoding = NO`, were it not for the
// `wasDecoded` assertion. That assertion is the test.

/// **Scenario:** A hostile writer replaces the keychain item with an archive rooted at a class
/// of its choosing, attacking the *outer* unarchiver.
/// **What it does:** Plants a `FIRMessagingArchiveGadget` archive and asserts
/// `tokenInfoFromKeychainItem:` rejects it without ever running the gadget's `initWithCoder:`.
- (void)testHostileRootObjectIsRejectedWithoutBeingConstructed {
  NSData *hostileArchive = [FIRMessagingLegacyArchiveFixtures archiveOfGadget];

  FIRMessagingTokenInfo *decoded =
      [FIRMessagingTokenStore tokenInfoFromKeychainItem:hostileArchive];

  XCTAssertNil(decoded, @"An archive that is not a token info must not yield one.");
  XCTAssertFalse(FIRMessagingArchiveGadget.wasDecoded,
                 @"Secure coding must reject the class before `initWithCoder:` runs. If this "
                 @"fails, the outer unarchiver is back to `requiresSecureCoding = NO` and the "
                 @"keychain item is once again an arbitrary-class instantiation primitive.");
}

/// **Scenario:** The same attack aimed at the *nested* unarchiver, which the `<= 10.18.0`
/// APNSInfo fallback keeps reachable. This is the subtler half: the outer record is perfectly
/// well-formed, so only the inner decoder stands between the attacker and their gadget.
/// **What it does:** Plants a legacy-shaped record whose `apns_info` blob is a gadget archive,
/// and asserts the record still decodes -- minus its APNSInfo -- with the gadget never
/// constructed.
///
/// Keeping the fallback is what makes upgrades from 10.18 lossless; this test is the price of
/// keeping it, and the reason the nested unarchiver runs with secure coding on rather than being
/// deleted outright.
- (void)testHostileNestedAPNSInfoIsRejectedWithoutBeingConstructed {
  NSData *hostileArchive = [FIRMessagingLegacyArchiveFixtures
      archiveWithGadgetInNestedAPNSInfoForAuthorizedEntity:kAuthorizedEntity
                                                     scope:kScope
                                                     token:kToken];

  FIRMessagingTokenInfo *decoded =
      [FIRMessagingTokenStore tokenInfoFromKeychainItem:hostileArchive];

  XCTAssertFalse(FIRMessagingArchiveGadget.wasDecoded,
                 @"The nested unarchiver must reject the class before `initWithCoder:` runs. If "
                 @"this fails, the legacy APNSInfo fallback has become the gadget surface the "
                 @"outer fix was meant to close.");
  XCTAssertNotNil(decoded, @"A bad `apns_info` must not cost the user their token.");
  XCTAssertEqualObjects(decoded.token, kToken);
  XCTAssertNil(decoded.APNSInfo, @"An APNSInfo that failed to decode must not be substituted.");
  XCTAssertTrue(decoded.needsMigration,
                @"The record is in the legacy shape, so the store should rewrite it and be rid "
                @"of the hostile blob.");
}

/// **Scenario:** A `<= 10.18.0` record whose nested `apns_info` blob is corrupt rather than
/// hostile: bit rot, a partial keychain write, or a bug in some other writer.
/// **What it does:** Plants each flavour of corruption in turn and asserts the record still
/// decodes with only its APNSInfo missing.
///
/// The three flavours fail at different depths of `NSKeyedUnarchiver`, which matters because the
/// shallow ones are the ones that can *raise* instead of returning an error. If a raise escaped
/// the nested decode it would unwind to the `@catch` in `tokenInfoFromKeychainItem:` and discard
/// the whole record -- costing the user their token over a damaged APNS association. Losing the
/// APNSInfo is recoverable on the next APNS registration; losing the token is not.
- (void)testCorruptNestedAPNSInfoCostsOnlyTheAPNSInfo {
  NSDictionary<NSString *, NSNumber *> *kinds = @{
    @"not a property list" : @(FIRMessagingCorruptPayloadKindNotAPropertyList),
    @"property list but not an archive" :
        @(FIRMessagingCorruptPayloadKindPropertyListButNotAnArchive),
    @"truncated archive" : @(FIRMessagingCorruptPayloadKindTruncatedArchive),
  };

  for (NSString *description in kinds) {
    FIRMessagingCorruptPayloadKind kind = kinds[description].integerValue;
    NSData *corruptArchive = [FIRMessagingLegacyArchiveFixtures
        archiveWithCorruptNestedAPNSInfoForAuthorizedEntity:kAuthorizedEntity
                                                      scope:kScope
                                                      token:kToken
                                                payloadKind:kind];

    FIRMessagingTokenInfo *decoded =
        [FIRMessagingTokenStore tokenInfoFromKeychainItem:corruptArchive];

    XCTAssertNotNil(decoded, @"%@: a damaged APNSInfo must not cost the user their token.",
                    description);
    XCTAssertEqualObjects(decoded.token, kToken, @"%@", description);
    XCTAssertEqualObjects(decoded.authorizedEntity, kAuthorizedEntity, @"%@", description);
    XCTAssertNil(decoded.APNSInfo,
                 @"%@: nothing should be substituted for a blob that failed to "
                 @"decode.",
                 description);
    XCTAssertTrue(decoded.needsMigration,
                  @"%@: the record is still in the legacy shape, so the store should rewrite it "
                  @"and be rid of the bad blob.",
                  description);
  }
}

#pragma mark - Archive shape

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
  [self injectKeychainItem:[self archiveWrittenBy10_18]];

  NSData *expectedDeviceToken = [self legacyDeviceToken];
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

/// **Scenario:** The longest realistic version path: a user sitting on a `<= 10.18.0` record
/// upgrades to Firebase 13, which migrates the record, and then downgrades to 12.x.
/// **What it does:** Injects a 10.18 record, lets the store migrate it, then reads the migrated
/// bytes straight out of the keychain with 12.19.0's decoder.
///
/// This is the one cell of the compatibility matrix that neither the 10.18 test nor the
/// downgrade test covers on its own, and it is the cell where a mistake would be worst: the
/// migration rewrites bytes the user may never be able to get back, so a 12.x SDK has to be able
/// to read the result. It can, because migration writes the same modern shape 13 writes for
/// everyone else.
- (void)testRecordMigratedFrom10_18IsStillReadableBy12 {
  [self injectKeychainItem:[self archiveWrittenBy10_18]];

  // Reading through the store triggers the migration rewrite.
  FIRMessagingTokenInfo *migrated = [self.tokenStore tokenInfoWithAuthorizedEntity:kAuthorizedEntity
                                                                             scope:kScope];
  XCTAssertNotNil(migrated);
  XCTAssertTrue(migrated.needsMigration, @"The injected record should have been the legacy shape.");

  NSData *migratedArchive = [self keychainItem];
  XCTAssertNotNil(migratedArchive);

  // The user downgrades. 12.19.0's read path must cope with the migrated bytes.
  FIRMessagingTokenInfo *downgraded =
      [FIRMessagingLegacyArchiveFixtures tokenInfoReadBy12:migratedArchive];
  XCTAssertNotNil(downgraded, @"Migration must not strand the record on a newer SDK.");
  XCTAssertEqualObjects(downgraded.token, kToken);
  XCTAssertEqualObjects(downgraded.authorizedEntity, kAuthorizedEntity);
  XCTAssertEqualObjects(downgraded.scope, kScope);
  XCTAssertEqualObjects(downgraded.APNSInfo.deviceToken, [self legacyDeviceToken],
                        @"The APNS association has to survive both the migration and the "
                        @"downgrade, or the next APNS registration invalidates the token.");
  XCTAssertEqualObjects(downgraded.tokenType, @"V4",
                        @"Migration should persist the `V4` default the 13 decoder substituted, "
                        @"so 12.x does not have to re-derive it.");
  XCTAssertFalse(downgraded.needsMigration,
                 @"Post-migration the record is in the modern shape, so 12.x sees nothing legacy.");
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
