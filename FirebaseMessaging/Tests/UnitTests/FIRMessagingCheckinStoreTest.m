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

#import <TargetConditionals.h>
#if !TARGET_OS_MACCATALYST
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingBackupExcludedPlist.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeKeychain.h"

static const NSTimeInterval kExpectationTimeout = 12;

@interface FIRMessagingCheckinStore ()
@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;
@property(nonatomic, readwrite, strong) FIRMessagingBackupExcludedPlist *plist;
- (NSString *)bundleIdentifierForKeychainAccount;
@end

@interface FIRMessaging (ExposedForTest)
+ (BOOL)createSubDirectory:(NSString *)subDirectoryName;
@end

@interface FIRMessagingBackupExcludedPlist (ExposedForTest)
- (BOOL)deleteFile:(NSError **)error;
@end

// Testing constants
static NSString *const kFakeCheckinPlistName = @"com.google.test.TestCheckin";
static NSString *const kSubDirectoryName = @"FirebaseInstanceIDCheckinTest";
static NSString *const kAuthID = @"test-auth-id";
static NSString *const kDigest = @"test-digest";
static NSString *const kSecret = @"test-secret";
static NSString *const kFakeErrorDomain = @"fakeDomain";
static const NSUInteger kFakeErrorCode = -1;

static int64_t const kLastCheckinTimestamp = 123456;

@interface FIRMessagingCheckinStoreTest : XCTestCase

@property(nonatomic, strong) FIRMessagingCheckinStore *checkinStore;
@property(nonatomic, strong) FIRMessagingBackupExcludedPlist *plist;
@end

@implementation FIRMessagingCheckinStoreTest

- (void)setUp {
  [super setUp];
  [FIRMessaging createSubDirectory:kSubDirectoryName];
  self.checkinStore = [[FIRMessagingCheckinStore alloc] init];
  self.plist = [[FIRMessagingBackupExcludedPlist alloc] initWithPlistFile:kFakeCheckinPlistName
                                                             subDirectory:kSubDirectoryName];
  self.checkinStore.plist = self.plist;
}

- (void)tearDown {
  [self.plist deleteFile:nil];
  [super tearDown];
}

/**
 *  Keychain read failure should lead to checkin preferences with invalid credentials.
 */
- (void)testInvalidCheckinPreferencesOnKeychainFail {
  XCTestExpectation *checkinInvalidExpectation = [self
      expectationWithDescription:@"Checkin preference should be invalid after keychain failure"];

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  self.checkinStore.keychain = fakeKeychain;
  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNil(error);
                                      fakeKeychain.cannotReadFromKeychain = YES;
                                      preferences = [self->_checkinStore cachedCheckinPreferences];

                                      XCTAssertNil(preferences.deviceID);
                                      XCTAssertNil(preferences.secretToken);
                                      XCTAssertFalse([preferences hasValidCheckinInfo]);

                                      [checkinInvalidExpectation fulfill];
                                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/**
 *  CheckinStore should not be able to save the checkin preferences if the write to the
 *  Keychain fails.
 */
- (void)testCheckinSaveFailsOnKeychainWriteFailure {
  XCTestExpectation *checkinSaveFailsExpectation =
      [self expectationWithDescription:@"Checkin save should fail after keychain write failure"];
  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  fakeKeychain.cannotWriteToKeychain = YES;
  self.checkinStore.keychain = fakeKeychain;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNotNil(error);

                                      preferences = [self->_checkinStore cachedCheckinPreferences];
                                      XCTAssertNil(preferences.deviceID);
                                      XCTAssertNil(preferences.secretToken);
                                      XCTAssertFalse([preferences hasValidCheckinInfo]);
                                      [checkinSaveFailsExpectation fulfill];
                                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

- (void)testCheckinSaveFailsOnPlistWriteFailure {
  XCTestExpectation *checkinSaveFailsExpectation =
      [self expectationWithDescription:@"Checkin save should fail after plist write failure"];

  id plistMock = OCMPartialMock(self.plist);
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:nil];
  OCMStub([plistMock writeDictionary:[OCMArg any] error:[OCMArg setTo:error]]).andReturn(NO);

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  self.checkinStore.keychain = fakeKeychain;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNotNil(error);
                                      XCTAssertEqual(error.code, kFakeErrorCode);

                                      preferences = [self->_checkinStore cachedCheckinPreferences];
                                      XCTAssertNil(preferences.deviceID);
                                      XCTAssertNil(preferences.secretToken);
                                      XCTAssertFalse([preferences hasValidCheckinInfo]);
                                      [checkinSaveFailsExpectation fulfill];
                                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

- (void)testCheckinSaveSuccess {
  XCTestExpectation *checkinSaveSuccessExpectation =
      [self expectationWithDescription:@"Checkin save should succeed"];

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  self.checkinStore.keychain = fakeKeychain;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNil(error);

                                      preferences = [self->_checkinStore cachedCheckinPreferences];
                                      XCTAssertEqualObjects(preferences.deviceID, kAuthID);
                                      XCTAssertEqualObjects(preferences.secretToken, kSecret);
                                      [checkinSaveSuccessExpectation fulfill];
                                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/**
 *  A version info of an unexpected type in the checkin plist, for example one saved by an older
 *  SDK version, is dropped when the checkin is loaded. The other values are kept.
 */
- (void)testCachedCheckinPreferencesDropsNonStringVersionInfo {
  XCTestExpectation *checkinSaveSuccessExpectation =
      [self expectationWithDescription:@"Checkin save should succeed"];
  self.checkinStore.keychain = [[FIRMessagingFakeKeychain alloc] init];
  FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [self.checkinStore saveCheckinPreferences:preferences
                                    handler:^(NSError *error) {
                                      XCTAssertNil(error);
                                      [checkinSaveSuccessExpectation fulfill];
                                    }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // Save a numeric version info, and read the plist from disk again as on the next launch.
  NSMutableDictionary *plistContents = [[self.plist contentAsDictionary] mutableCopy];
  plistContents[kFIRMessagingVersionInfoStringKey] = @123;
  XCTAssertTrue([self.plist writeDictionary:plistContents error:NULL]);
  self.checkinStore.plist =
      [[FIRMessagingBackupExcludedPlist alloc] initWithPlistFile:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];

  FIRMessagingCheckinPreferences *cachedPreferences = [self.checkinStore cachedCheckinPreferences];
  XCTAssertEqualObjects(cachedPreferences.deviceID, kAuthID);
  XCTAssertEqualObjects(cachedPreferences.secretToken, kSecret);
  XCTAssertEqualObjects(cachedPreferences.digest, kDigest);
  XCTAssertNil(cachedPreferences.versionInfo);
}

/**
 *  Checkin credentials in the plist, where older SDK versions saved them, are used if they are
 *  missing from the keychain.
 */
- (void)testCachedCheckinPreferencesUsesPlistCredentials {
  self.checkinStore.keychain = [[FIRMessagingFakeKeychain alloc] init];
  XCTAssertTrue([self.plist writeDictionary:[[self class] checkinPreferences] error:NULL]);

  FIRMessagingCheckinPreferences *cachedPreferences = [self.checkinStore cachedCheckinPreferences];
  XCTAssertEqualObjects(cachedPreferences.deviceID, kAuthID);
  XCTAssertEqualObjects(cachedPreferences.secretToken, kSecret);
  XCTAssertEqualObjects(cachedPreferences.digest, kDigest);
}

/**
 *  Checkin credentials of an unexpected type in the plist are ignored.
 */
- (void)testCachedCheckinPreferencesIgnoresNonStringPlistCredentials {
  self.checkinStore.keychain = [[FIRMessagingFakeKeychain alloc] init];
  NSMutableDictionary *plistContents = [[[self class] checkinPreferences] mutableCopy];
  plistContents[kFIRMessagingDeviceAuthIdKey] = @1234;
  plistContents[kFIRMessagingSecretTokenKey] = @5678;
  XCTAssertTrue([self.plist writeDictionary:plistContents error:NULL]);

  XCTAssertNil([self.checkinStore cachedCheckinPreferences]);
}

#pragma mark - Private Helpers

+ (NSDictionary *)checkinPreferences {
  return @{
    kFIRMessagingDeviceAuthIdKey : kAuthID,
    kFIRMessagingSecretTokenKey : kSecret,
    kFIRMessagingDigestStringKey : kDigest,
    kFIRMessagingGServicesDictionaryKey : @{},
    kFIRMessagingLastCheckinTimeKey : @(kLastCheckinTimestamp),
  };
}

+ (NSDictionary *)newCheckinPlistPreferences {
  NSMutableDictionary *oldPreferences = [[self checkinPreferences] mutableCopy];
  [oldPreferences removeObjectForKey:kFIRMessagingDeviceAuthIdKey];
  [oldPreferences removeObjectForKey:kFIRMessagingSecretTokenKey];
  oldPreferences[kFIRMessagingLastCheckinTimeKey] =
      @(FIRMessagingCurrentTimestampInMilliseconds() - 1000);
  return [oldPreferences copy];
}

@end
#endif  // !TARGET_OS_MACCATALYST
