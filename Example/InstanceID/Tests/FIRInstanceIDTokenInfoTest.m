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

#import "Firebase/InstanceID/FIRInstanceIDTokenInfo.h"

#import <XCTest/XCTest.h>

#import <FirebaseCore/FIROptions.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <OCMock/OCMock.h>
#import "Firebase/InstanceID/FIRInstanceIDAPNSInfo.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"

static NSString *const kAuthorizedEntity = @"authorizedEntity";
static NSString *const kScope = @"scope";
static NSString *const kToken = @"validToken";
static NSString *const kFirebaseAppID = @"firebaseAppID";
static BOOL const kAPNSSandbox = NO;

@interface FIRInstanceIDTokenInfoTest : XCTestCase

@property(nonatomic, strong) NSData *APNSDeviceToken;
@property(nonatomic, strong) FIRInstanceIDTokenInfo *validTokenInfo;
@property(nonatomic, strong) id mockOptions;

@end

@implementation FIRInstanceIDTokenInfoTest

- (void)setUp {
  [super setUp];

  self.APNSDeviceToken = [@"validDeviceToken" dataUsingEncoding:NSUTF8StringEncoding];

  self.mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([self.mockOptions defaultOptionsDictionary]).andReturn(@{
    kFIRGoogleAppID : kFirebaseAppID
  });

  self.validTokenInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kScope
                                                         token:kToken
                                                    appVersion:FIRInstanceIDCurrentAppVersion()
                                                 firebaseAppID:FIRInstanceIDFirebaseAppID()];
  self.validTokenInfo.APNSInfo =
      [[FIRInstanceIDAPNSInfo alloc] initWithDeviceToken:self.APNSDeviceToken
                                               isSandbox:kAPNSSandbox];
  self.validTokenInfo.cacheTime = [NSDate date];
}

- (void)tearDown {
  [self.mockOptions stopMocking];
  [super tearDown];
}

- (void)testTokenInfoCreationWithInvalidArchive {
  NSData *badData = [@"badData" dataUsingEncoding:NSUTF8StringEncoding];
  FIRInstanceIDTokenInfo *info = nil;
  @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    info = [NSKeyedUnarchiver unarchiveObjectWithData:badData];
#pragma clang diagnostic pop
  } @catch (NSException *e) {
    XCTAssertEqualObjects([e name], @"NSInvalidArgumentException");
  }
  XCTAssertNil(info);
}

// Test that archiving a FIRInstanceIDTokenInfo object and restoring it from the archive
// yields the same values for all the fields.
- (void)testTokenInfoEncodingAndDecoding {
  FIRInstanceIDTokenInfo *info = self.validTokenInfo;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:info];
  FIRInstanceIDTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
  XCTAssertEqualObjects(restoredInfo.authorizedEntity, info.authorizedEntity);
  XCTAssertEqualObjects(restoredInfo.scope, info.scope);
  XCTAssertEqualObjects(restoredInfo.token, info.token);
  XCTAssertEqualObjects(restoredInfo.appVersion, info.appVersion);
  XCTAssertEqualObjects(restoredInfo.firebaseAppID, info.firebaseAppID);
  XCTAssertEqualObjects(restoredInfo.cacheTime, info.cacheTime);
  XCTAssertEqualObjects(restoredInfo.APNSInfo.deviceToken, info.APNSInfo.deviceToken);
  XCTAssertEqual(restoredInfo.APNSInfo.sandbox, info.APNSInfo.sandbox);
}

// Test that archiving a FIRInstanceIDTokenInfo object with missing fields and restoring it
// from the archive yields the same values for all the fields.
- (void)testTokenInfoEncodingAndDecodingWithMissingFields {
  // Don't include appVersion, firebaseAppID, APNSInfo and cacheTime
  FIRInstanceIDTokenInfo *sparseInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kScope
                                                         token:kToken
                                                    appVersion:nil
                                                 firebaseAppID:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:sparseInfo];
  FIRInstanceIDTokenInfo *restoredInfo = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
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
  XCTAssertTrue([self.validTokenInfo isFresh]);

  // Locale change should affect token refreshness.
  // Set to a different locale than the current locale.
  [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hant"
                                            forKey:kFIRInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
  XCTAssertFalse([self.validTokenInfo isFresh]);
  // Reset locale
  [[NSUserDefaults standardUserDefaults] setObject:FIRInstanceIDCurrentLocale()
                                            forKey:kFIRInstanceIDUserDefaultsKeyLocale];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)testTokenFreshnessWithTokenTimestampChange {
  XCTAssertTrue([self.validTokenInfo isFresh]);
  // Set last fetch token time 7 days ago.
  NSTimeInterval lastFetchTokenTimestamp =
      FIRInstanceIDCurrentTimestampInSeconds() - 7 * 24 * 60 * 60;
  self.validTokenInfo.cacheTime = [NSDate dateWithTimeIntervalSince1970:lastFetchTokenTimestamp];
  XCTAssertFalse([self.validTokenInfo isFresh]);

  // Set last fetch token time more than 7 days ago.
  lastFetchTokenTimestamp = FIRInstanceIDCurrentTimestampInSeconds() - 8 * 24 * 60 * 60;
  self.validTokenInfo.cacheTime = [NSDate dateWithTimeIntervalSince1970:lastFetchTokenTimestamp];
  XCTAssertFalse([self.validTokenInfo isFresh]);

  // Set last fetch token time nil to mock legacy storage format. Token should be considered not
  // fresh.
  self.validTokenInfo.cacheTime = nil;
  XCTAssertFalse([self.validTokenInfo isFresh]);
}

- (void)testTokenFreshnessWithFirebaseAppIDChange {
  XCTAssertTrue([self.validTokenInfo isFresh]);
  // Change Firebase App ID.
  [FIROptions defaultOptions].googleAppID = @"newFirebaseAppID:ios:abcdefg";
  XCTAssertFalse([self.validTokenInfo isFresh]);
}

- (void)testTokenFreshnessWithAppVersionChange {
  XCTAssertTrue([self.validTokenInfo isFresh]);
  // Change app version.
  self.validTokenInfo =
      [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                         scope:kScope
                                                         token:kToken
                                                    appVersion:@"1.1"
                                                 firebaseAppID:FIRInstanceIDFirebaseAppID()];
  XCTAssertFalse([self.validTokenInfo isFresh]);
}
@end
