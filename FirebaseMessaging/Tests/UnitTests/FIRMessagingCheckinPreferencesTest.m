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

#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"

static NSString *const kDeviceAuthId = @"1234";
static NSString *const kSecretToken = @"567890";

@interface FIRMessagingCheckinPreferencesTest : XCTestCase

@end

@implementation FIRMessagingCheckinPreferencesTest

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testInvalidCheckinInfo {
  FIRMessagingCheckinPreferences *preferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:@"" secretToken:@""];
  XCTAssertFalse([preferences hasValidCheckinInfo]);
}

- (void)testCheckinPreferencesReset {
  FIRMessagingCheckinPreferences *checkin =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                   secretToken:kSecretToken];
  [checkin reset];
  XCTAssertNil(checkin.deviceID);
  XCTAssertNil(checkin.secretToken);
  XCTAssertFalse([checkin hasValidCheckinInfo]);
}

- (void)testInvalidCheckinInfoDueToLocaleChanged {
  // Set to a different locale than the current locale.
  [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hant"
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  FIRMessagingCheckinPreferences *checkin =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                   secretToken:kSecretToken];
  XCTAssertFalse([checkin hasValidCheckinInfo],
                 @"Should consider checkin info invalid as locale has changed.");
  // set back the original locale
  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
}

- (void)testCheckinPreferenceRefreshTokenWeekly {
  FIRMessagingCheckinPreferences *checkin =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                   secretToken:kSecretToken];
  int64_t now = FIRMessagingCurrentTimestampInMilliseconds();
  [checkin updateWithCheckinPlistContents:@{kFIRMessagingLastCheckinTimeKey : @(now)}];

  XCTAssertTrue([checkin hasValidCheckinInfo]);

  // Set last checkin time long time ago.
  now = FIRMessagingCurrentTimestampInMilliseconds();
  [checkin updateWithCheckinPlistContents:@{
    kFIRMessagingLastCheckinTimeKey : @(now - kFIRMessagingDefaultCheckinInterval * 1000 - 1)
  }];

  XCTAssertFalse([checkin hasValidCheckinInfo]);
}

- (void)testUpdateWithCheckinPlistContentsDropsNonStringValues {
  int64_t now = FIRMessagingCurrentTimestampInMilliseconds();
  NSArray *invalidValues = @[ @123, @{@"version" : @"1.0"}, [NSNull null] ];
  for (id invalidValue in invalidValues) {
    FIRMessagingCheckinPreferences *checkin =
        [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                     secretToken:kSecretToken];
    [checkin updateWithCheckinPlistContents:@{
      kFIRMessagingVersionInfoStringKey : invalidValue,
      kFIRMessagingDigestStringKey : invalidValue,
      kFIRMessagingDeviceDataVersionKey : invalidValue,
      kFIRMessagingLastCheckinTimeKey : @(now),
      kFIRMessagingGServicesDictionaryKey : @{@"name" : @"value"},
    }];

    XCTAssertNil(checkin.versionInfo, @"%@", invalidValue);
    XCTAssertNil(checkin.digest, @"%@", invalidValue);
    XCTAssertNil(checkin.deviceDataVersion, @"%@", invalidValue);
    XCTAssertEqual(checkin.lastCheckinTimestampMillis, now, @"%@", invalidValue);
    XCTAssertTrue([checkin hasCheckinInfo], @"%@", invalidValue);
    NSDictionary *plistContents = [checkin checkinPlistContents];
    XCTAssertEqualObjects(plistContents[kFIRMessagingVersionInfoStringKey], @"", @"%@",
                          invalidValue);
    XCTAssertEqualObjects(plistContents[kFIRMessagingGServicesDictionaryKey],
                          (@{@"name" : @"value"}), @"%@", invalidValue);
    XCTAssertTrue([NSPropertyListSerialization propertyList:plistContents
                                           isValidForFormat:NSPropertyListXMLFormat_v1_0],
                  @"%@", invalidValue);
  }
}

- (void)testUpdateWithCheckinPlistContentsDropsNonNumericLastCheckinTime {
  NSArray *invalidValues = @[ [NSNull null], @[ @1 ], @{@"time" : @1} ];
  for (id invalidValue in invalidValues) {
    FIRMessagingCheckinPreferences *checkin =
        [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                     secretToken:kSecretToken];
    [checkin updateWithCheckinPlistContents:@{
      kFIRMessagingLastCheckinTimeKey : invalidValue,
      kFIRMessagingVersionInfoStringKey : @"1.0",
    }];

    XCTAssertEqual(checkin.lastCheckinTimestampMillis, 0, @"%@", invalidValue);
    XCTAssertEqualObjects(checkin.versionInfo, @"1.0", @"%@", invalidValue);
  }
}

- (void)testUpdateWithCheckinPlistContentsAcceptsStringLastCheckinTime {
  FIRMessagingCheckinPreferences *checkin =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                   secretToken:kSecretToken];
  [checkin updateWithCheckinPlistContents:@{kFIRMessagingLastCheckinTimeKey : @"1234"}];

  XCTAssertEqual(checkin.lastCheckinTimestampMillis, 1234);
}

- (void)testUpdateWithCheckinPlistContentsDropsNonDictionaryGServices {
  NSArray *invalidValues = @[ @"name=value", @[ @"name" ], @5 ];
  for (id invalidValue in invalidValues) {
    FIRMessagingCheckinPreferences *checkin =
        [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                     secretToken:kSecretToken];
    [checkin updateWithCheckinPlistContents:@{
      kFIRMessagingGServicesDictionaryKey : invalidValue,
      kFIRMessagingDigestStringKey : @"digest",
    }];

    XCTAssertEqualObjects([checkin checkinPlistContents][kFIRMessagingGServicesDictionaryKey], @{},
                          @"%@", invalidValue);
    XCTAssertEqualObjects(checkin.digest, @"digest", @"%@", invalidValue);
  }
}

@end
