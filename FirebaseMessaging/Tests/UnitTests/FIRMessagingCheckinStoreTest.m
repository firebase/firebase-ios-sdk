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

#import <XCTest/XCTest.h>

#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingBackupExcludedPlist.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeKeychain.h"
#import "OCMock.h"

static const NSTimeInterval kExpectationTimeout = 12;

@interface FIRMessagingCheckinStore ()
@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;
@property(nonatomic, readwrite, strong) FIRMessagingBackupExcludedPlist *plist;
- (NSString *)bundleIdentifierForKeychainAccount;
@end

@interface FIRMessaging (ExposedForTest)
+ (BOOL)createSubDirectory:(NSString *)subDirectoryName;
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

@interface FIRMessagingCheckinStoreTest : XCTestCase

@end

@implementation FIRMessagingCheckinStoreTest

- (void)setUp {
  [super setUp];
  [FIRMessaging createSubDirectory:kSubDirectoryName];
}

- (void)tearDown {
  NSString *path = [self pathForCheckinPlist];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
  }
  [super tearDown];
}

/**
 *  Keychain read failure should lead to checkin preferences with invalid credentials.
 */
- (void)testInvalidCheckinPreferencesOnKeychainFail {
  XCTestExpectation *checkinInvalidExpectation = [self
      expectationWithDescription:@"Checkin preference should be invalid after keychain failure"];

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];

  FIRMessagingCheckinStore *checkinStore = [[FIRMessagingCheckinStore alloc] init];
  checkinStore.keychain = fakeKeychain;
  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
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
  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  fakeKeychain.cannotWriteToKeychain = YES;

  FIRMessagingCheckinStore *checkinStore = [[FIRMessagingCheckinStore alloc] init];
  checkinStore.keychain = fakeKeychain;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
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
  FIRMessagingBackupExcludedPlist *checkinPlist =
      [[FIRMessagingBackupExcludedPlist alloc] initWithFileName:kFakeCheckinPlistName
                                                   subDirectory:kSubDirectoryName];
  id plistMock = OCMPartialMock(checkinPlist);
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:nil];
  OCMStub([plistMock writeDictionary:[OCMArg any] error:[OCMArg setTo:error]]).andReturn(NO);

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];

  FIRMessagingCheckinStore *checkinStore = [[FIRMessagingCheckinStore alloc] init];
  checkinStore.keychain = fakeKeychain;
  checkinStore.plist = checkinPlist;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
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

  FIRMessagingFakeKeychain *fakeKeychain = [[FIRMessagingFakeKeychain alloc] init];
  FIRMessagingCheckinStore *checkinStore = [[FIRMessagingCheckinStore alloc] init];
  checkinStore.keychain = fakeKeychain;

  __block FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kAuthID secretToken:kSecret];
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
