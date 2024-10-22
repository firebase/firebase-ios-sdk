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
                                                firebaseAppID:FIRMessagingFirebaseAppID()];
  self.validTokenInfo.APNSInfo =
      [[FIRMessagingAPNSInfo alloc] initWithDeviceToken:self.APNSDeviceToken
                                              isSandbox:kAPNSSandbox];
  self.validTokenInfo.cacheTime = [NSDate date];

  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
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

// Test that archiving a FIRMessagingTokenInfo object with missing fields and restoring it
// from the archive yields the same values for all the fields.
- (void)testTokenInfoEncodingAndDecodingWithMissingFields {
  // Don't include appVersion, firebaseAppID, APNSInfo and cacheTime
  FIRMessagingTokenInfo *sparseInfo =
      [[FIRMessagingTokenInfo alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                        token:kToken
                                                   appVersion:nil
                                                firebaseAppID:nil];
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
                                                firebaseAppID:FIRMessagingFirebaseAppID()];
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
                 firebaseAppID:FIRMessagingFirebaseAppID()];
  XCTAssertFalse([self.validTokenInfo isFreshWithIID:kIID]);
}
@end
