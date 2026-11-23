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
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
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

#pragma mark - Response validation

- (void)testCheckinAcceptsStringIDs {
  // The proto3 JSON format sends 64-bit integers as strings.
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"android_id"] = kDeviceAuthId;
  response[@"security_token"] = kSecretToken;

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId);
  XCTAssertEqualObjects(preferences.secretToken, kSecretToken);
  XCTAssertTrue([preferences hasCheckinInfo]);
}

- (void)testCheckinFailsWithNullDeviceID {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"android_id"] = [NSNull null];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(preferences);
  XCTAssertEqualObjects(error.domain, FIRMessagingErrorDomain);
  XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest);
}

- (void)testCheckinFailsWithNullSecurityToken {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"security_token"] = [NSNull null];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(preferences);
  XCTAssertEqualObjects(error.domain, FIRMessagingErrorDomain);
  XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest);
}

- (void)testCheckinFailsWithMissingSecurityToken {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  [response removeObjectForKey:@"security_token"];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(preferences);
  XCTAssertEqualObjects(error.domain, FIRMessagingErrorDomain);
  XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest);
}

- (void)testCheckinFailsWithInvalidIDs {
  // The Arabic-Indic digits are decimal digits but not ASCII. Numbers must be non-negative
  // integers, and JSON booleans are numbers whose string values are "1" and "0".
  NSArray *invalidIDs = @[
    @"", @"12a4", @"-1234", @"12.5", @" 1234", @"1234|5", @"\u0661\u0662\u0663\u0664", @[ @1234 ],
    @{@"id" : @1234}, @12.5, @(-1234), @YES, @NO
  ];
  for (NSString *key in @[ @"android_id", @"security_token" ]) {
    for (id invalidID in invalidIDs) {
      NSMutableDictionary *response = [[self class] validCheckinResponse];
      response[key] = invalidID;

      NSError *error;
      FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                                   statusCode:200
                                                                        error:&error];

      XCTAssertNil(preferences, @"%@: '%@'", key, invalidID);
      XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidRequest, @"%@: '%@'", key, invalidID);
      OCMVerifyAll(self.URLSessionMock);
    }
  }
}

- (void)testCheckinFailsWithArrayRoot {
  NSError *error;
  FIRMessagingCheckinPreferences *preferences =
      [self checkinWithResponse:@[ [[self class] validCheckinResponse] ]
                     statusCode:200
                          error:&error];

  XCTAssertNil(preferences);
  XCTAssertEqualObjects(error.domain, FIRMessagingErrorDomain);
  XCTAssertEqual(error.code, kFIRMessagingErrorCodeRegistrarFailedToCheckIn);
}

- (void)testCheckinFailsWithHTTPErrorStatus {
  NSError *error;
  FIRMessagingCheckinPreferences *preferences =
      [self checkinWithResponse:[[self class] validCheckinResponse] statusCode:500 error:&error];

  XCTAssertNil(preferences);
  XCTAssertEqualObjects(error.domain, FIRMessagingErrorDomain);
  XCTAssertEqual(error.code, kFIRMessagingErrorCodeRegistrarFailedToCheckIn);
}

- (void)testCheckinAcceptsHTTP201Status {
  NSError *error;
  FIRMessagingCheckinPreferences *preferences =
      [self checkinWithResponse:[[self class] validCheckinResponse] statusCode:201 error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId);
  XCTAssertEqualObjects(preferences.secretToken, kSecretToken);
  XCTAssertEqualObjects(preferences.versionInfo, kVersionInfo);
}

- (void)testCheckinIgnoresNumericVersionInfo {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"version_info"] = @123;

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId);
  XCTAssertEqualObjects(preferences.versionInfo, @"");
  XCTAssertTrue([[self class] isPropertyList:[preferences checkinPlistContents]]);
}

- (void)testCheckinIgnoresNullVersionInfo {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"version_info"] = [NSNull null];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId);
  XCTAssertEqualObjects(preferences.versionInfo, @"");
  XCTAssertTrue([[self class] isPropertyList:[preferences checkinPlistContents]]);
}

- (void)testCheckinIgnoresVersionInfoWithNULCharacter {
  // An XML property list can't store U+0000, so the checkin couldn't be saved.
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"version_info"] = [NSString stringWithFormat:@"1.0%C", (unichar)0];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId);
  XCTAssertEqualObjects(preferences.versionInfo, @"");
  XCTAssertTrue([[self class] isPropertyList:[preferences checkinPlistContents]]);
}

- (void)testCheckinIgnoresNonStringDigestAndDeviceDataVersion {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"digest"] = @{@"digest" : kDigest};
  response[@"device_data_version_info"] = @[ @"1" ];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects(preferences.digest, @"");
  XCTAssertEqualObjects(preferences.deviceDataVersion, @"");
  XCTAssertEqualObjects(preferences.versionInfo, kVersionInfo);
  XCTAssertTrue([[self class] isPropertyList:[preferences checkinPlistContents]]);
}

- (void)testCheckinIgnoresNonNumericTimestamp {
  NSArray *invalidTimestamps = @[ [NSNull null], @[ @1 ], @{@"time" : @1} ];
  for (id invalidTimestamp in invalidTimestamps) {
    NSMutableDictionary *response = [[self class] validCheckinResponse];
    response[@"time_msec"] = invalidTimestamp;

    NSError *error;
    FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                                 statusCode:200
                                                                      error:&error];

    XCTAssertNil(error, @"%@", invalidTimestamp);
    XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId, @"%@", invalidTimestamp);
    XCTAssertEqual(preferences.lastCheckinTimestampMillis, 0, @"%@", invalidTimestamp);
    OCMVerifyAll(self.URLSessionMock);
  }
}

- (void)testCheckinAcceptsStringTimestamp {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"time_msec"] = @"1234567";

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqual(preferences.lastCheckinTimestampMillis, 1234567);
}

- (void)testCheckinIgnoresNonArraySettings {
  NSArray *invalidSettings = @[ @{@"name" : @"a", @"value" : @"1"}, @"a=1", [NSNull null] ];
  for (id invalidSetting in invalidSettings) {
    NSMutableDictionary *response = [[self class] validCheckinResponse];
    response[@"setting"] = invalidSetting;

    NSError *error;
    FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                                 statusCode:200
                                                                      error:&error];

    XCTAssertNil(error, @"%@", invalidSetting);
    XCTAssertEqualObjects(preferences.deviceID, kDeviceAuthId, @"%@", invalidSetting);
    XCTAssertEqualObjects([preferences checkinPlistContents][kFIRMessagingGServicesDictionaryKey],
                          @{}, @"%@", invalidSetting);
    OCMVerifyAll(self.URLSessionMock);
  }
}

- (void)testCheckinSkipsSettingsThatAreNotDictionaries {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"setting"] = @[
    @{@"name" : @"a", @"value" : @"1"}, @"b", [NSNull null], @5, @[ @"c" ],
    @{@"name" : @"d", @"value" : @"4"}
  ];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  XCTAssertEqualObjects([preferences checkinPlistContents][kFIRMessagingGServicesDictionaryKey],
                        (@{@"a" : @"1", @"d" : @"4"}));
}

- (void)testCheckinSkipsSettingsWithNonStringNameOrValue {
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"setting"] = @[
    @{@"name" : @"a", @"value" : @"1"},
    @{@"name" : [NSNull null], @"value" : @"2"},
    @{@"name" : @"b", @"value" : [NSNull null]},
    @{@"name" : @3, @"value" : @"3"},
    @{@"name" : @"c", @"value" : @3},
    @{@"name" : @"e"},
    @{@"name" : @"d", @"value" : @"4"},
  ];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  NSDictionary *plistContents = [preferences checkinPlistContents];
  XCTAssertEqualObjects(plistContents[kFIRMessagingGServicesDictionaryKey],
                        (@{@"a" : @"1", @"d" : @"4"}));
  XCTAssertTrue([[self class] isPropertyList:plistContents]);
}

- (void)testCheckinSkipsSettingsWithNULCharacter {
  // An XML property list can't store U+0000 in a key or a value, so the checkin couldn't be saved.
  NSMutableDictionary *response = [[self class] validCheckinResponse];
  response[@"setting"] = @[
    @{@"name" : @"a", @"value" : @"1"},
    @{@"name" : [NSString stringWithFormat:@"b%C", (unichar)0], @"value" : @"2"},
    @{@"name" : @"c", @"value" : [NSString stringWithFormat:@"3%C", (unichar)0]},
    @{@"name" : @"d", @"value" : @"4"},
  ];

  NSError *error;
  FIRMessagingCheckinPreferences *preferences = [self checkinWithResponse:response
                                                               statusCode:200
                                                                    error:&error];

  XCTAssertNil(error);
  NSDictionary *plistContents = [preferences checkinPlistContents];
  XCTAssertEqualObjects(plistContents[kFIRMessagingGServicesDictionaryKey],
                        (@{@"a" : @"1", @"d" : @"4"}));
  XCTAssertTrue([[self class] isPropertyList:plistContents]);
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

/// Returns a valid checkin response body, which tests can modify.
+ (NSMutableDictionary *)validCheckinResponse {
  NSMutableDictionary *response = [NSMutableDictionary dictionary];
  response[@"android_id"] = @([kDeviceAuthId longLongValue]);
  response[@"security_token"] = @([kSecretToken longLongValue]);
  response[@"time_msec"] = @(FIRMessagingCurrentTimestampInMilliseconds());
  response[@"version_info"] = kVersionInfo;
  response[@"digest"] = kDigest;
  return response;
}

/// Performs a checkin that receives `response` as its JSON body, with the given HTTP status code.
/// Returns the checkin preferences passed to the completion handler, and sets `error` to its error.
- (FIRMessagingCheckinPreferences *)checkinWithResponse:(id)response
                                             statusCode:(NSInteger)statusCode
                                                  error:(NSError **)error {
  NSData *body = [NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];
  NSHTTPURLResponse *HTTPResponse =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:kDeviceCheckinURL]
                                  statusCode:statusCode
                                 HTTPVersion:@"1.1"
                                headerFields:nil];
  [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:HTTPResponse
                                                         body:body
                                                        error:nil
                                               URLSessionMock:self.URLSessionMock
                                       requestValidationBlock:nil];

  XCTestExpectation *checkinCompletionExpectation =
      [self expectationWithDescription:@"Checkin Completion"];
  __block FIRMessagingCheckinPreferences *checkinPreferences;
  __block NSError *checkinError;
  [self.checkinService checkinWithExistingCheckin:nil
                                       completion:^(FIRMessagingCheckinPreferences *preferences,
                                                    NSError *completionError) {
                                         checkinPreferences = preferences;
                                         checkinError = completionError;
                                         [checkinCompletionExpectation fulfill];
                                       }];
  [self waitForExpectations:@[ checkinCompletionExpectation ] timeout:5];

  if (error) {
    *error = checkinError;
  }
  return checkinPreferences;
}

/// Returns whether `contents` can be saved as a property list, like the checkin plist.
+ (BOOL)isPropertyList:(id)contents {
  return [NSPropertyListSerialization propertyList:contents
                                  isValidForFormat:NSPropertyListXMLFormat_v1_0];
}

@end
