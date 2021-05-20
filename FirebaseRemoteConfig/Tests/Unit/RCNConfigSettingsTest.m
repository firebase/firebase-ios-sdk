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
- (void)updateInternalContentWithResponse:(RCNConfigFetchResponse *)response;
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
- (void)testUpdateInternalMetadata {
  RCNConfigFetchResponse *response = [[RCNConfigFetchResponse alloc] init];
  // Mock internal metadata array with all_packages prefix key
  response.internalMetadataArray = [RCNTestUtilities entryArrayWithKeyValuePair:@{
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNHTTPConnectionTimeoutInMillisecondsKey] : @"50",
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNHTTPReadTimeoutInMillisecondsKey] : @"2000000",
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNThrottledSuccessFetchTimeIntervalInSecondsKey] : @"300",
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNThrottledSuccessFetchCountKey] : @"-6",
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNThrottledFailureFetchTimeIntervalInSecondsKey] : @"10000000",
    [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                               RCNThrottledFailureFetchCountKey] : @"21",

  }];
  [_mockSettings updateInternalContentWithResponse:response];
  XCTAssertEqual(
      [_mockSettings internalMetadataValueForKey:RCNHTTPConnectionTimeoutInMillisecondsKey
                                        minValue:RCNHTTPConnectionTimeoutInMillisecondsMin
                                        maxValue:RCNHTTPConnectionTimeoutInMillisecondsMax
                                    defaultValue:RCNHTTPConnectionTimeoutInMillisecondsDefault],
      RCNHTTPConnectionTimeoutInMillisecondsMin,
      @"HTTP Connection Timeout must be within the range.");
  XCTAssertEqual(
      [_mockSettings internalMetadataValueForKey:RCNHTTPReadTimeoutInMillisecondsKey
                                        minValue:RCNHTTPReadTimeoutInMillisecondsMin
                                        maxValue:RCNHTTPReadTimeoutInMillisecondsMax
                                    defaultValue:RCNHTTPReadTimeoutInMillisecondsDefault],
      RCNHTTPReadTimeoutInMillisecondsMax, @"HTTP Read Timeout must be within the range");
  XCTAssertEqual(
      [_mockSettings
          internalMetadataValueForKey:RCNThrottledSuccessFetchTimeIntervalInSecondsKey
                             minValue:RCNThrottledSuccessFetchTimeIntervalInSecondsMin
                             maxValue:RCNThrottledSuccessFetchTimeIntervalInSecondsMax
                         defaultValue:RCNThrottledSuccessFetchTimeIntervalInSecondsDefault],
      RCNThrottledSuccessFetchTimeIntervalInSecondsMin,
      @"Throttling success internal must be within the range");
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                                   minValue:RCNThrottledSuccessFetchCountMin
                                                   maxValue:RCNThrottledSuccessFetchCountMax
                                               defaultValue:RCNThrottledSuccessFetchCountDefault],
                 RCNThrottledSuccessFetchCountMin);
  XCTAssertEqual(
      [_mockSettings
          internalMetadataValueForKey:RCNThrottledFailureFetchTimeIntervalInSecondsKey
                             minValue:RCNThrottledFailureFetchTimeIntervalInSecondsMin
                             maxValue:RCNThrottledFailureFetchTimeIntervalInSecondsMax
                         defaultValue:RCNThrottledFailureFetchTimeIntervalInSecondsDefault],
      RCNThrottledFailureFetchTimeIntervalInSecondsMax);
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledFailureFetchCountKey
                                                   minValue:RCNThrottledFailureFetchCountMin
                                                   maxValue:RCNThrottledFailureFetchCountMax
                                               defaultValue:RCNThrottledFailureFetchCountDefault],
                 RCNThrottledFailureFetchCountMax);

  // Mock internal metadata array with bundle_identifier prefix key.
  // bundle_identifier prefixed key should override all_packages prefix key
  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  response.internalMetadataArray = [RCNTestUtilities entryArrayWithKeyValuePair:@{
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier,
                               RCNHTTPConnectionTimeoutInMillisecondsKey] : @"70000",
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier, RCNHTTPReadTimeoutInMillisecondsKey] :
        @"70000",
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier,
                               RCNThrottledSuccessFetchTimeIntervalInSecondsKey] : @"1800",
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier, RCNThrottledSuccessFetchCountKey] :
        @"100",
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier,
                               RCNThrottledFailureFetchTimeIntervalInSecondsKey] : @"1800",
    [NSString stringWithFormat:@"%@:%@", bundleIdentifier, RCNThrottledFailureFetchCountKey] : @"0",
  }];
  [_mockSettings updateInternalContentWithResponse:response];

  XCTAssertEqual(
      [_mockSettings internalMetadataValueForKey:RCNHTTPConnectionTimeoutInMillisecondsKey
                                        minValue:RCNHTTPConnectionTimeoutInMillisecondsMin
                                        maxValue:RCNHTTPConnectionTimeoutInMillisecondsMax
                                    defaultValue:RCNHTTPConnectionTimeoutInMillisecondsDefault],
      70000);
  XCTAssertEqual(
      [_mockSettings internalMetadataValueForKey:RCNHTTPReadTimeoutInMillisecondsKey
                                        minValue:RCNHTTPReadTimeoutInMillisecondsMin
                                        maxValue:RCNHTTPReadTimeoutInMillisecondsMax
                                    defaultValue:RCNHTTPReadTimeoutInMillisecondsDefault],
      70000);
  XCTAssertEqual(
      [_mockSettings
          internalMetadataValueForKey:RCNThrottledSuccessFetchTimeIntervalInSecondsKey
                             minValue:RCNThrottledSuccessFetchTimeIntervalInSecondsMin
                             maxValue:RCNThrottledSuccessFetchTimeIntervalInSecondsMax
                         defaultValue:RCNThrottledSuccessFetchTimeIntervalInSecondsDefault],
      1800);
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                                   minValue:RCNThrottledSuccessFetchCountMin
                                                   maxValue:RCNThrottledSuccessFetchCountMax
                                               defaultValue:RCNThrottledSuccessFetchCountDefault],
                 20);

  XCTAssertEqual(
      [_mockSettings
          internalMetadataValueForKey:RCNThrottledFailureFetchTimeIntervalInSecondsKey
                             minValue:RCNThrottledFailureFetchTimeIntervalInSecondsMin
                             maxValue:RCNThrottledFailureFetchTimeIntervalInSecondsMax
                         defaultValue:RCNThrottledFailureFetchTimeIntervalInSecondsDefault],
      1800);
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledFailureFetchCountKey
                                                   minValue:RCNThrottledFailureFetchCountMin
                                                   maxValue:RCNThrottledFailureFetchCountMax
                                               defaultValue:RCNThrottledFailureFetchCountDefault],
                 1);
}

- (void)testInternalMetadataOverride {
  // Mock response after fetching.
  RCNConfigFetchResponse *response = [[RCNConfigFetchResponse alloc] init];
  NSString *onePackageKey =
      [NSString stringWithFormat:@"%@:%@", [[NSBundle mainBundle] bundleIdentifier],
                                 RCNThrottledSuccessFetchCountKey];
  NSString *allPackageKey =
      [NSString stringWithFormat:@"%@:%@", RCNInternalMetadataAllPackagesPrefix,
                                 RCNThrottledSuccessFetchCountKey];

  [_mockSettings updateInternalContentWithResponse:response];
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                                   minValue:RCNThrottledSuccessFetchCountMin
                                                   maxValue:RCNThrottledSuccessFetchCountMax
                                               defaultValue:RCNThrottledSuccessFetchCountDefault],
                 RCNThrottledSuccessFetchCountDefault,
                 @"Fetch with no internal metadata, must return default value.");

  response.internalMetadataArray =
      [RCNTestUtilities entryArrayWithKeyValuePair:@{onePackageKey : @"8", allPackageKey : @"9"}];
  [_mockSettings updateInternalContentWithResponse:response];
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                                   minValue:RCNThrottledSuccessFetchCountMin
                                                   maxValue:RCNThrottledSuccessFetchCountMax
                                               defaultValue:RCNThrottledSuccessFetchCountDefault],
                 8, @"Fetch with both keys, must return the one with package key.");

  [response.internalMetadataArray removeAllObjects];
  [_mockSettings updateInternalContentWithResponse:response];
  XCTAssertEqual(
      [_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                        minValue:RCNThrottledSuccessFetchCountMin
                                        maxValue:RCNThrottledSuccessFetchCountMax
                                    defaultValue:RCNThrottledSuccessFetchCountDefault],
      9, @"Fetch with no internal metadata, must return the one with previous all_packages key.");

  [response.internalMetadataArray removeAllObjects];
  response.internalMetadataArray = [RCNTestUtilities entryArrayWithKeyValuePair:@{
    onePackageKey : @"6",
  }];

  [_mockSettings updateInternalContentWithResponse:response];
  XCTAssertEqual([_mockSettings internalMetadataValueForKey:RCNThrottledSuccessFetchCountKey
                                                   minValue:RCNThrottledSuccessFetchCountMin
                                                   maxValue:RCNThrottledSuccessFetchCountMax
                                               defaultValue:RCNThrottledSuccessFetchCountDefault],
                 6, @"Fetch with one package key, must return the one with package key.");
}

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
