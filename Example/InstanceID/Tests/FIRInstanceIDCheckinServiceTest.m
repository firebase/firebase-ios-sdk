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

#import <FirebaseInstanceID/FIRInstanceIDCheckinPreferences.h>
#import <OCMock/OCMock.h>
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinService.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"
#import "Firebase/InstanceID/NSError+FIRInstanceID.h"

static NSString *const kDeviceAuthId = @"1234";
static NSString *const kSecretToken = @"567890";
static NSString *const kDigest = @"com.google.digest";
static NSString *const kVersionInfo = @"1.0";

@interface FIRInstanceIDCheckinServiceTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceIDCheckinService *checkinService;

@end

@implementation FIRInstanceIDCheckinServiceTest

- (void)setUp {
  [super setUp];
  self.checkinService = [[FIRInstanceIDCheckinService alloc] init];
}

- (void)tearDown {
  self.checkinService = nil;
  [super tearDown];
}

- (void)testCheckinWithSuccessfulCompletion {
  FIRInstanceIDCheckinPreferences *existingCheckin = [self stubCheckinCacheWithValidData];

  [FIRInstanceIDCheckinService setCheckinTestBlock:[self successfulCheckinCompletionHandler]];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [self.checkinService
      checkinWithExistingCheckin:existingCheckin
                      completion:^(FIRInstanceIDCheckinPreferences *checkinPreferences,
                                   NSError *error) {
                        XCTAssertNil(error);
                        XCTAssertEqualObjects(checkinPreferences.deviceID, kDeviceAuthId);
                        XCTAssertEqualObjects(checkinPreferences.versionInfo, kVersionInfo);
                        // For accuracy purposes it's better to compare seconds since the test
                        // should never run for more than 1 second.
                        NSInteger expectedTimestampInSeconds =
                            (NSInteger)FIRInstanceIDCurrentTimestampInSeconds();
                        NSInteger actualTimestampInSeconds =
                            checkinPreferences.lastCheckinTimestampMillis / 1000.0;
                        XCTAssertEqual(expectedTimestampInSeconds, actualTimestampInSeconds);
                        XCTAssertTrue([checkinPreferences hasValidCheckinInfo]);
                        [checkinCompletionExpectation fulfill];
                      }];

  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFailedCheckinService {
  [FIRInstanceIDCheckinService setCheckinTestBlock:[self failCheckinCompletionHandler]];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [self.checkinService
      checkinWithExistingCheckin:nil
                      completion:^(FIRInstanceIDCheckinPreferences *preferences, NSError *error) {
                        XCTAssertNotNil(error);
                        XCTAssertNil(preferences.deviceID);
                        XCTAssertNil(preferences.secretToken);
                        XCTAssertFalse([preferences hasValidCheckinInfo]);
                        [checkinCompletionExpectation fulfill];
                      }];

  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Checkin Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testCheckinServiceFailsWithErrorAfterStopFetching {
  [self.checkinService stopFetching];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [self.checkinService
      checkinWithExistingCheckin:nil
                      completion:^(FIRInstanceIDCheckinPreferences *preferences, NSError *error) {
                        [checkinCompletionExpectation fulfill];
                        XCTAssertNil(preferences);
                        XCTAssertNotNil(error);
                        XCTAssertEqual(error.code, kFIRInstanceIDErrorCodeRegistrarFailedToCheckIn);
                      }];

  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Checkin Timeout Error: %@", error);
                                 }
                               }];
}

#pragma mark - Stub

- (FIRInstanceIDCheckinPreferences *)stubCheckinCacheWithValidData {
  NSDictionary *gservicesData = @{
    @"FIRInstanceIDVersionInfo" : kVersionInfo,
    @"FIRInstanceIDLastCheckinTimestampKey" : @(FIRInstanceIDCurrentTimestampInMilliseconds())
  };
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                    secretToken:kSecretToken];
  [checkinPreferences updateWithCheckinPlistContents:gservicesData];
  return checkinPreferences;
}

#pragma mark - Swizzle

- (FIRInstanceIDURLRequestTestBlock)successfulCheckinCompletionHandler {
  return ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock testResponse) {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:nil];

    NSMutableDictionary *dataResponse = [NSMutableDictionary dictionary];
    dataResponse[@"android_id"] = @([kDeviceAuthId longLongValue]);
    dataResponse[@"security_token"] = @([kSecretToken longLongValue]);
    dataResponse[@"time_msec"] = @(FIRInstanceIDCurrentTimestampInMilliseconds());
    dataResponse[@"version_info"] = kVersionInfo;
    dataResponse[@"digest"] = kDigest;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dataResponse
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    testResponse(data, response, nil);
  };
}

- (FIRInstanceIDURLRequestTestBlock)failCheckinCompletionHandler {
  return ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock testResponse) {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:nil];

    NSError *error =
        [NSError errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeInvalidRequest];

    testResponse(nil, response, error);
  };
}

@end
