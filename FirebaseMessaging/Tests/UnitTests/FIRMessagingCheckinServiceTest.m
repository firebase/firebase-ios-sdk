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

#import <OCMock/OCMock.h>
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

static NSString *const kDeviceAuthId = @"1234";
static NSString *const kSecretToken = @"567890";
static NSString *const kDigest = @"com.google.digest";
static NSString *const kVersionInfo = @"1.0";
static NSString *const kDeviceCheckinURL = @"https://device-provisioning.googleapis.com/checkin";

@interface FIRMessagingCheckinServiceTest : XCTestCase

@property(nonatomic) id URLSessionMock;
@property(nonatomic) FIRMessagingCheckinService *checkinService;

@end

@implementation FIRMessagingCheckinServiceTest

- (void)setUp {
  [super setUp];

  // Stub NSURLSession constructor before instantiating FIRMessagingCheckinService to inject
  // URLSessionMock.
  self.URLSessionMock = OCMClassMock([NSURLSession class]);
  OCMStub(ClassMethod([self.URLSessionMock sessionWithConfiguration:[OCMArg any]]))
      .andReturn(self.URLSessionMock);

  self.checkinService = [[FIRMessagingCheckinService alloc] init];
}

- (void)tearDown {
  self.checkinService = nil;
  [self.URLSessionMock stopMocking];
  self.URLSessionMock = nil;
  [super tearDown];
}

- (void)testCheckinWithSuccessfulCompletion {
  FIRMessagingCheckinPreferences *existingCheckin = [self stubCheckinCacheWithValidData];
  NSURL *expectedRequestURL = [NSURL URLWithString:kDeviceCheckinURL];

  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                    statusCode:200
                                                                   HTTPVersion:@"1.1"
                                                                  headerFields:nil];

  NSMutableDictionary *dataResponse = [NSMutableDictionary dictionary];
  dataResponse[@"android_id"] = @([kDeviceAuthId longLongValue]);
  dataResponse[@"security_token"] = @([kSecretToken longLongValue]);
  dataResponse[@"time_msec"] = @(FIRMessagingCurrentTimestampInMilliseconds());
  dataResponse[@"version_info"] = kVersionInfo;
  dataResponse[@"digest"] = kDigest;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dataResponse
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:data
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    [self assertValidCheckinRequest:sentRequest expectedURL:expectedRequestURL];
                    return YES;
                  }];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [self.checkinService
      checkinWithExistingCheckin:existingCheckin
                      completion:^(FIRMessagingCheckinPreferences *checkinPreferences,
                                   NSError *error) {
                        XCTAssertNil(error);
                        XCTAssertEqualObjects(checkinPreferences.deviceID, kDeviceAuthId);
                        XCTAssertEqualObjects(checkinPreferences.versionInfo, kVersionInfo);
                        // For accuracy purposes it's better to compare seconds since the test
                        // should never run for more than 1 second.
                        NSInteger expectedTimestampInSeconds =
                            (NSInteger)FIRMessagingCurrentTimestampInSeconds();
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

- (void)testCheckinServiceFailure {
  NSURL *expectedRequestURL = [NSURL URLWithString:kDeviceCheckinURL];

  NSHTTPURLResponse *failureResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                   statusCode:404
                                                                  HTTPVersion:@"1.1"
                                                                 headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:failureResponse
                                    body:[@"Not Found" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    [self assertValidCheckinRequest:sentRequest expectedURL:expectedRequestURL];
                    return YES;
                  }];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [self.checkinService
      checkinWithExistingCheckin:nil
                      completion:^(FIRMessagingCheckinPreferences *preferences, NSError *error) {
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

- (void)testCheckinServiceNetworkFailure {
  NSURL *expectedRequestURL = [NSURL URLWithString:kDeviceCheckinURL];

  NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeInvalidRequest
                                     failureReason:@"Checkin failed with invalid request."];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:nil
                                    body:nil
                                   error:error
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    [self assertValidCheckinRequest:sentRequest expectedURL:expectedRequestURL];
                    return YES;
                  }];

  [self.checkinService
      checkinWithExistingCheckin:nil
                      completion:^(FIRMessagingCheckinPreferences *preferences, NSError *error) {
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

#pragma mark - Stub

- (FIRMessagingCheckinPreferences *)stubCheckinCacheWithValidData {
  NSDictionary *gservicesData = @{
    @"FIRMessagingVersionInfo" : kVersionInfo,
    @"FIRMessagingLastCheckinTimestampKey" : @(FIRMessagingCurrentTimestampInMilliseconds())
  };
  FIRMessagingCheckinPreferences *checkinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceAuthId
                                                   secretToken:kSecretToken];
  [checkinPreferences updateWithCheckinPlistContents:gservicesData];
  return checkinPreferences;
}

#pragma mark - Helpers

- (void)assertValidCheckinRequest:(NSURLRequest *)request expectedURL:(NSURL *)expectedURL {
  XCTAssertEqualObjects(request.URL, expectedURL);
  XCTAssertEqualObjects(request.allHTTPHeaderFields, @{@"Content-Type" : @"application/json"});

  // TODO: Validate body.
}

@end
