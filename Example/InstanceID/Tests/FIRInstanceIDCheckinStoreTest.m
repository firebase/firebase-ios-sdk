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

#import <OCMock/OCMock.h>

#import <FirebaseInstanceID/FIRInstanceIDCheckinPreferences.h>
#import "FIRInstanceIDFakeKeychain.h"
#import "Firebase/InstanceID/FIRInstanceIDAuthKeyChain.h"
#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinService.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinStore.h"
#import "Firebase/InstanceID/FIRInstanceIDStore.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"
#import "Firebase/InstanceID/FIRInstanceIDVersionUtilities.h"

static const NSTimeInterval kExpectationTimeout = 12;

@interface FIRInstanceIDCheckinStore ()
- (NSString *)bundleIdentifierForKeychainAccount;
@end

// Testing constants
static NSString *const kFakeCheckinPlistName = @"com.google.test.IIDStoreTestCheckin";
static NSString *const kSubDirectoryName = @"FirebaseInstanceIDCheckinTest";

static NSString *const kAuthID = @"test-auth-id";
static NSString *const kDigest = @"test-digest";
static NSString *const kSecret = @"test-secret";
static NSString *const kFakeErrorDomain = @"fakeDomain";
static const NSUInteger kFakeErrorCode = -1;

static int64_t const kLastCheckinTimestamp = 123456;

@interface FIRInstanceIDCheckinStoreTest : XCTestCase

@end

@implementation FIRInstanceIDCheckinStoreTest

- (void)setUp {
  [super setUp];
  [FIRInstanceIDStore createSubDirectory:kSubDirectoryName];
}

- (void)tearDown {
  NSString *path = [self pathForCheckinPlist];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
  }
  [FIRInstanceIDStore removeSubDirectory:kSubDirectoryName error:nil];
  [super tearDown];
}

/**
 *  Keychain read failure should lead to checkin preferences with invalid credentials.
 */
- (void)testInvalidCheckinPreferencesOnKeychainFail {
  XCTestExpectation *checkinInvalidExpectation = [self
      expectationWithDescription:@"Checkin preference should be invalid after keychain failure"];
  FIRInstanceIDBackupExcludedPlist *checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];

  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];

  FIRInstanceIDCheckinStore *checkinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:checkinPlist keychain:fakeKeychain];
  __block FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [checkinStore saveCheckinPreferences:preferences
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                                 fakeKeychain.cannotReadFromKeychain = YES;
                                 preferences = [checkinStore cachedCheckinPreferences];

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
  FIRInstanceIDBackupExcludedPlist *checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];
  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  fakeKeychain.cannotWriteToKeychain = YES;

  FIRInstanceIDCheckinStore *checkinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:checkinPlist keychain:fakeKeychain];

  __block FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [checkinStore saveCheckinPreferences:preferences
                               handler:^(NSError *error) {
                                 XCTAssertNotNil(error);

                                 preferences = [checkinStore cachedCheckinPreferences];
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
  FIRInstanceIDBackupExcludedPlist *checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];
  id plistMock = OCMPartialMock(checkinPlist);
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:nil];
  OCMStub([plistMock writeDictionary:[OCMArg any] error:[OCMArg setTo:error]]).andReturn(NO);

  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];

  FIRInstanceIDCheckinStore *checkinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:plistMock keychain:fakeKeychain];

  __block FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [checkinStore saveCheckinPreferences:preferences
                               handler:^(NSError *error) {
                                 XCTAssertNotNil(error);
                                 XCTAssertEqual(error.code, kFakeErrorCode);

                                 preferences = [checkinStore cachedCheckinPreferences];
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
  FIRInstanceIDBackupExcludedPlist *checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];
  id plistMock = OCMPartialMock(checkinPlist);

  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  FIRInstanceIDCheckinStore *checkinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:plistMock keychain:fakeKeychain];

  __block FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];
  [checkinStore saveCheckinPreferences:preferences
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);

                                 preferences = [checkinStore cachedCheckinPreferences];
                                 XCTAssertEqualObjects(preferences.deviceID, kAuthID);
                                 XCTAssertEqualObjects(preferences.secretToken, kSecret);
                                 [checkinSaveSuccessExpectation fulfill];
                               }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

// Write fake checkin data to legacy location, then test if migration worked.
- (void)testCheckinMigrationMovesToNewLocationInKeychain {
  XCTestExpectation *checkinMigrationExpectation =
      [self expectationWithDescription:@"checkin migration should move to the new location"];
  // Create checkin store class.
  FIRInstanceIDBackupExcludedPlist *checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                    subDirectory:kSubDirectoryName];

  FIRInstanceIDFakeKeychain *fakeKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  FIRInstanceIDFakeKeychain *weakKeychain = fakeKeychain;

  // Create fake checkin preferences object.
  FIRInstanceIDCheckinPreferences *preferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
  [preferences updateWithCheckinPlistContents:[[self class] newCheckinPlistPreferences]];

  // Write checkin into legacy location in Fake keychain.
  NSString *checkinKeychainContent = [preferences checkinKeychainContent];
  NSData *data = [checkinKeychainContent dataUsingEncoding:NSUTF8StringEncoding];
  [fakeKeychain setData:data
             forService:kFIRInstanceIDLegacyCheckinKeychainService
          accessibility:nil
                account:kFIRInstanceIDLegacyCheckinKeychainAccount
                handler:^(NSError *error) {
                  XCTAssertNil(error);
                  // Check that we saved it correctly to the legacy location.
                  NSData *dataInLegacyLocation =
                      [weakKeychain dataForService:kFIRInstanceIDLegacyCheckinKeychainService
                                           account:kFIRInstanceIDLegacyCheckinKeychainAccount];
                  XCTAssertNotNil(dataInLegacyLocation);

                  FIRInstanceIDCheckinStore *checkinStore =
                      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:checkinPlist
                                                                     keychain:weakKeychain];
                  // Perform migration.
                  [checkinStore migrateCheckinItemIfNeeded];

                  // Ensure the item is no longer in the old location.
                  dataInLegacyLocation =
                      [weakKeychain dataForService:kFIRInstanceIDLegacyCheckinKeychainService
                                           account:kFIRInstanceIDLegacyCheckinKeychainAccount];
                  XCTAssertNil(dataInLegacyLocation);
                  // Check that it exists in the new location.
                  NSData *dataInMigratedLocation =
                      [weakKeychain dataForService:kFIRInstanceIDCheckinKeychainService
                                           account:checkinStore.bundleIdentifierForKeychainAccount];
                  XCTAssertNotNil(dataInMigratedLocation);
                  // Ensure that the data is the same as what we originally saved.
                  XCTAssertEqualObjects(dataInMigratedLocation, data);

                  [checkinMigrationExpectation fulfill];
                }];

  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

#pragma mark - Private Helpers

- (BOOL)savePreferencesToPlist:(NSDictionary *)preferences {
  NSString *path = [self pathForCheckinPlist];
  return [preferences writeToFile:path atomically:YES];
}

- (NSString *)pathForCheckinPlist {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *plistNameWithExtension = [NSString stringWithFormat:@"%@.plist", kFakeCheckinPlistName];
  return [paths[0] stringByAppendingPathComponent:plistNameWithExtension];
}

+ (NSDictionary *)checkinPreferences {
  return @{
    kFIRInstanceIDDeviceAuthIdKey : kAuthID,
    kFIRInstanceIDSecretTokenKey : kSecret,
    kFIRInstanceIDDigestStringKey : kDigest,
    kFIRInstanceIDGServicesDictionaryKey : @{},
    kFIRInstanceIDLastCheckinTimeKey : @(kLastCheckinTimestamp),
  };
}

+ (NSDictionary *)newCheckinPlistPreferences {
  NSMutableDictionary *oldPreferences = [[self checkinPreferences] mutableCopy];
  [oldPreferences removeObjectForKey:kFIRInstanceIDDeviceAuthIdKey];
  [oldPreferences removeObjectForKey:kFIRInstanceIDSecretTokenKey];
  oldPreferences[kFIRInstanceIDLastCheckinTimeKey] =
      @(FIRInstanceIDCurrentTimestampInMilliseconds() - 1000);
  return [oldPreferences copy];
}

@end
