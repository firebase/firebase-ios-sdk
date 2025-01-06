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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

@interface RCNConfigSettings (ExposedTestCase)
- (RCNConfigFetchRequest *)nextRequestWithUserProperties:(NSDictionary *)userProperties
                                           fetchedConfig:(NSDictionary *)fetchedConfig;
- (void)updateConfigContentWithResponse:(RCNConfigFetchResponse *)response;
- (void)updateFetchTimeWithSuccessFetch:(BOOL)isSuccessfulFetch;
- (BOOL)hasCachedData;
- (BOOL)isCachedDataFresh;
@end

@interface RCNConfigSettingsTest : XCTestCase {
  RCNConfigSettings *_mockSettings;
}
@end

@implementation RCNConfigSettingsTest
- (void)setUp {
  [super setUp];
  // Mock the read/write DB operations, which are not needed in these tests.
  _mockSettings = [[RCNConfigSettings alloc] initWithDatabaseManager:nil];
}

- (void)testCrashShouldNotHappenWithoutMainBundleID {
  id mockBundle = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([NSBundle mainBundle]).andReturn(mockBundle);
  OCMStub([mockBundle bundleIdentifier]).andReturn(nil);
  _mockSettings =
      [[RCNConfigSettings alloc] initWithDatabaseManager:[[RCNConfigDBManager alloc] init]];
  [mockBundle stopMocking];
}

#ifdef FIX_OR_DELETE
- (void)testThrottlingFresh {
  NSTimeInterval endTimestamp = [_mockSettings cachedDataThrottledEndTimestamp];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  XCTAssertTrue(endTimestamp <= now);

  // Fetch failed once.
  [_mockSettings updateFetchTimeWithSuccessFetch:NO];
  endTimestamp = [_mockSettings cachedDataThrottledEndTimestamp];
  now = [[NSDate date] timeIntervalSince1970];
  XCTAssertTrue(endTimestamp <= now);

  // Fetch succeeded once.
  [_mockSettings updateFetchTimeWithSuccessFetch:YES];
  endTimestamp = [_mockSettings cachedDataThrottledEndTimestamp];
  now = [[NSDate date] timeIntervalSince1970];
  XCTAssertTrue(endTimestamp <= now);

  // The failure fetch rate is 5. Try another 3 times, and do not go over the limit.
  for (int i = 0; i < 3; i++) {
    [_mockSettings updateFetchTimeWithSuccessFetch:NO];
  }
  endTimestamp = [_mockSettings cachedDataThrottledEndTimestamp];
  now = [[NSDate date] timeIntervalSince1970];
  XCTAssertTrue(endTimestamp <= now);

  // The success fetch rate is 5. Try another 4 times, which should go over the limit afterwards.
  for (int i = 0; i < 4; i++) {
    [_mockSettings updateFetchTimeWithSuccessFetch:YES];
  }
  endTimestamp = [_mockSettings cachedDataThrottledEndTimestamp];
  now = [[NSDate date] timeIntervalSince1970];
  // Now it should go over the limit.
  XCTAssertFalse(endTimestamp <= now);
  XCTAssertTrue([_mockSettings hasCachedData]);
}
#endif

- (void)testResetDigestInNextRequest {
  NSDictionary *digestPerNamespace = @{@"firebase" : @"1234", @"p4" : @"5678"};
  [_mockSettings setNamespaceToDigest:digestPerNamespace];

  RCNNamedValue *firebaseDigest = [[RCNNamedValue alloc] init];
  firebaseDigest.name = @"firebase";
  firebaseDigest.value = @"1234";

  RCNNamedValue *p4Digest = [[RCNNamedValue alloc] init];
  p4Digest.name = @"p4";
  p4Digest.value = @"5678";

  // Test where each namespace's fetched config is a non-empty dictionary, request should include
  // the namespace's digest.
  NSDictionary *fetchedConfig =
      @{@"firebase" : @{@"a" : @"b", @"c" : @"d"}, @"p4" : @{@"p4key" : @"p4value"}};
  RCNConfigFetchRequest *request = [_mockSettings nextRequestWithUserProperties:nil
                                                                  fetchedConfig:fetchedConfig];
  XCTAssertEqual(request.packageDataArray.count, 1);
  NSArray *expectedArray = @[ firebaseDigest, p4Digest ];
  XCTAssertEqualObjects(request.packageDataArray[0].namespaceDigestArray, expectedArray);

  // Test when the namespace's fetched config doesn't exist, reset the digest by not included
  // in the request.
  fetchedConfig = @{@"firebase" : @{@"a" : @"b", @"c" : @"d"}};
  request = [_mockSettings nextRequestWithUserProperties:nil fetchedConfig:fetchedConfig];
  XCTAssertEqual(request.packageDataArray.count, 1);
  XCTAssertEqualObjects(request.packageDataArray[0].namespaceDigestArray, @[ firebaseDigest ]);

  // Test when a namespace's fetched config is empty, reset the digest.
  fetchedConfig = @{@"firebase" : @{@"a" : @"b", @"c" : @"d"}, @"p4" : @{}};
  request = [_mockSettings nextRequestWithUserProperties:nil fetchedConfig:fetchedConfig];
  XCTAssertEqual(request.packageDataArray.count, 1);
  XCTAssertEqualObjects(request.packageDataArray[0].namespaceDigestArray, @[ firebaseDigest ]);

  // Test when a namespace's fetched config is a invalid format (non-dictionary), reset the digest.
  fetchedConfig = @{@"firebase" : @{@"a" : @"b", @"c" : @"d"}, @"p4" : @[]};
  request = [_mockSettings nextRequestWithUserProperties:nil fetchedConfig:fetchedConfig];
  XCTAssertEqual(request.packageDataArray.count, 1);
  XCTAssertEqualObjects(request.packageDataArray[0].namespaceDigestArray, @[ firebaseDigest ]);

  // Test when a namespace's fetched config is a invalid format (non-dictionary), reset the digest.
  fetchedConfig = @{@"firebase" : @{@"a" : @"b", @"c" : @"d"}, @"p4" : @"wrong format of config"};
  request = [_mockSettings nextRequestWithUserProperties:nil fetchedConfig:fetchedConfig];
  XCTAssertEqual(request.packageDataArray.count, 1);
  XCTAssertEqualObjects(request.packageDataArray[0].namespaceDigestArray, @[ firebaseDigest ]);
}

@end
