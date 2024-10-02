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

#import "FirebaseRemoteConfig/Sources/RCNUserDefaultsManager.h"

static NSTimeInterval RCNUserDefaultsSampleTimeStamp = 0;

static NSString* const AppName = @"testApp";
static NSString* const FQNamespace1 = @"testNamespace1:testApp";
static NSString* const FQNamespace2 = @"testNamespace2:testApp";

@interface RCNUserDefaultsManagerTests : XCTestCase

@end

@implementation RCNUserDefaultsManagerTests

- (void)setUp {
  [super setUp];

  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
  RCNUserDefaultsSampleTimeStamp = [[NSDate date] timeIntervalSince1970];
}

- (void)testUserDefaultsEtagWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastETag:@"eTag1"];
  XCTAssertEqualObjects([manager lastETag], @"eTag1");

  [manager setLastETag:@"eTag2"];
  XCTAssertEqualObjects([manager lastETag], @"eTag2");
}

- (void)testUserDefaultsLastFetchTimeWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastFetchTime:RCNUserDefaultsSampleTimeStamp];
  XCTAssertEqual([manager lastFetchTime], RCNUserDefaultsSampleTimeStamp);

  [manager setLastFetchTime:RCNUserDefaultsSampleTimeStamp - 1000];
  XCTAssertEqual([manager lastFetchTime], RCNUserDefaultsSampleTimeStamp - 1000);
}

- (void)testUserDefaultsLastETagUpdateTimeWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastETagUpdateTime:RCNUserDefaultsSampleTimeStamp];
  XCTAssertEqual([manager lastETagUpdateTime], RCNUserDefaultsSampleTimeStamp);

  [manager setLastETagUpdateTime:RCNUserDefaultsSampleTimeStamp - 1000];
  XCTAssertEqual([manager lastETagUpdateTime], RCNUserDefaultsSampleTimeStamp - 1000);
}

- (void)testUserDefaultsLastFetchStatusWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastFetchStatus:@"Success"];
  XCTAssertEqualObjects([manager lastFetchStatus], @"Success");

  [manager setLastFetchStatus:@"Error"];
  XCTAssertEqualObjects([manager lastFetchStatus], @"Error");
}

- (void)testUserDefaultsisClientThrottledWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setIsClientThrottledWithExponentialBackoff:YES];
  XCTAssertEqual([manager isClientThrottledWithExponentialBackoff], YES);

  [manager setIsClientThrottledWithExponentialBackoff:NO];
  XCTAssertEqual([manager isClientThrottledWithExponentialBackoff], NO);
}

- (void)testUserDefaultsThrottleEndTimeWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 7.0];
  XCTAssertEqual([manager throttleEndTime], RCNUserDefaultsSampleTimeStamp - 7.0);

  [manager setThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 8.0];
  XCTAssertEqual([manager throttleEndTime], RCNUserDefaultsSampleTimeStamp - 8.0);
}

- (void)testUserDefaultsCurrentThrottlingRetryIntervalWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setCurrentThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 1.0];
  XCTAssertEqual([manager currentThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 1.0);

  [manager setCurrentThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 2.0];
  XCTAssertEqual([manager currentThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 2.0);
}

- (void)testUserDefaultsTemplateVersionWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastFetchedTemplateVersion:@"1"];
  XCTAssertEqual([manager lastFetchedTemplateVersion], @"1");
}

- (void)testUserDefaultsActiveTemplateVersionWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastActiveTemplateVersion:@"1"];
  XCTAssertEqual([manager lastActiveTemplateVersion], @"1");
}

- (void)testUserDefaultsRealtimeThrottleEndTimeWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setRealtimeThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 7.0];
  XCTAssertEqual([manager realtimeThrottleEndTime], RCNUserDefaultsSampleTimeStamp - 7.0);

  [manager setRealtimeThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 8.0];
  XCTAssertEqual([manager realtimeThrottleEndTime], RCNUserDefaultsSampleTimeStamp - 8.0);
}

- (void)testUserDefaultsCurrentRealtimeThrottlingRetryIntervalWriteAndRead {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setCurrentRealtimeThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 1.0];
  XCTAssertEqual([manager currentRealtimeThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 1.0);

  [manager setCurrentRealtimeThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 2.0];
  XCTAssertEqual([manager currentRealtimeThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 2.0);
}

- (void)testUserDefaultsForMultipleNamespaces {
  RCNUserDefaultsManager* manager1 =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];

  RCNUserDefaultsManager* manager2 =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace2];

  /// Last ETag.
  [manager1 setLastETag:@"eTag1ForNamespace1"];
  [manager2 setLastETag:@"eTag1ForNamespace2"];
  XCTAssertEqualObjects([manager1 lastETag], @"eTag1ForNamespace1");
  XCTAssertEqualObjects([manager2 lastETag], @"eTag1ForNamespace2");

  /// Last fetch time.
  [manager1 setLastFetchTime:RCNUserDefaultsSampleTimeStamp - 1000.0];
  [manager2 setLastFetchTime:RCNUserDefaultsSampleTimeStamp - 7000.0];
  XCTAssertEqual([manager1 lastFetchTime], RCNUserDefaultsSampleTimeStamp - 1000);
  XCTAssertEqual([manager2 lastFetchTime], RCNUserDefaultsSampleTimeStamp - 7000);

  /// Last fetch status.
  [manager1 setLastFetchStatus:@"Success"];
  [manager2 setLastFetchStatus:@"Error"];
  XCTAssertEqualObjects([manager1 lastFetchStatus], @"Success");
  XCTAssertEqualObjects([manager2 lastFetchStatus], @"Error");

  /// Is client throttled.
  [manager1 setIsClientThrottledWithExponentialBackoff:YES];
  [manager2 setIsClientThrottledWithExponentialBackoff:NO];
  XCTAssertEqual([manager1 isClientThrottledWithExponentialBackoff], YES);
  XCTAssertEqual([manager2 isClientThrottledWithExponentialBackoff], NO);

  /// Throttle end time.
  [manager1 setThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 7.0];
  [manager2 setThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 8.0];
  XCTAssertEqual([manager1 throttleEndTime], RCNUserDefaultsSampleTimeStamp - 7.0);
  XCTAssertEqual([manager2 throttleEndTime], RCNUserDefaultsSampleTimeStamp - 8.0);

  /// Throttling retry interval.
  [manager1 setCurrentThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 1.0];
  [manager2 setCurrentThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 2.0];
  XCTAssertEqual([manager1 currentThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 1.0);
  XCTAssertEqual([manager2 currentThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 2.0);

  /// Realtime throttle end time.
  [manager1 setRealtimeThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 7.0];
  [manager2 setRealtimeThrottleEndTime:RCNUserDefaultsSampleTimeStamp - 8.0];
  XCTAssertEqual([manager1 realtimeThrottleEndTime], RCNUserDefaultsSampleTimeStamp - 7.0);
  XCTAssertEqual([manager2 realtimeThrottleEndTime], RCNUserDefaultsSampleTimeStamp - 8.0);

  /// Realtime throttling retry interval.
  [manager1 setCurrentRealtimeThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 1.0];
  [manager2 setCurrentRealtimeThrottlingRetryIntervalSeconds:RCNUserDefaultsSampleTimeStamp - 2.0];
  XCTAssertEqual([manager1 currentRealtimeThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 1.0);
  XCTAssertEqual([manager2 currentRealtimeThrottlingRetryIntervalSeconds],
                 RCNUserDefaultsSampleTimeStamp - 2.0);

  /// Realtime retry count;
  [manager1 setRealtimeRetryCount:1];
  [manager2 setRealtimeRetryCount:2];
  XCTAssertEqual([manager1 realtimeRetryCount], 1);
  XCTAssertEqual([manager2 realtimeRetryCount], 2);

  /// Fetch template version.
  [manager1 setLastFetchedTemplateVersion:@"1"];
  [manager2 setLastFetchedTemplateVersion:@"2"];
  XCTAssertEqualObjects([manager1 lastFetchedTemplateVersion], @"1");
  XCTAssertEqualObjects([manager2 lastFetchedTemplateVersion], @"2");

  /// Active template version.
  [manager1 setLastActiveTemplateVersion:@"1"];
  [manager2 setLastActiveTemplateVersion:@"2"];
  XCTAssertEqualObjects([manager1 lastActiveTemplateVersion], @"1");
  XCTAssertEqualObjects([manager2 lastActiveTemplateVersion], @"2");
}

- (void)testUserDefaultsReset {
  RCNUserDefaultsManager* manager =
      [[RCNUserDefaultsManager alloc] initWithAppName:AppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:FQNamespace1];
  [manager setLastETag:@"testETag"];
  [manager resetUserDefaults];
  XCTAssertNil([manager lastETag]);
}

@end
