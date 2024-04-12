/*
 * Copyright 2017 Google
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

#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMBookKeeper.h"

@interface FIRIAMBookKeeperViaUserDefaultsTests : XCTestCase
@property(nonatomic) GULUserDefaults *userDefaultsForTesting;
@end

extern NSString *FIRIAM_UserDefaultsKeyForImpressions;
extern NSString *FIRIAM_UserDefaultsKeyForLastImpressionTimestamp;

extern NSString *FIRIAM_ImpressionDictKeyForID;
extern NSString *FIRIAM_ImpressionDictKeyForTimestamp;

static NSString *const kSuiteName = @"FIRIAMBookKeeperViaUserDefaultsTests";

@implementation FIRIAMBookKeeperViaUserDefaultsTests
- (void)setUp {
  [super setUp];
  self.userDefaultsForTesting = [[GULUserDefaults alloc] initWithSuiteName:kSuiteName];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
  [[[NSUserDefaults alloc] initWithSuiteName:kSuiteName] removePersistentDomainForName:kSuiteName];
}

- (void)testRecordImpressionRecords {
  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];

  NSArray<FIRIAMImpressionRecord *> *impressions = [bookKeeper getImpressions];
  XCTAssertEqual(0, [impressions count]);

  double impression1_ts = 12345;
  double impression2_ts = 34567;

  [bookKeeper recordNewImpressionForMessage:@"m1" withStartTimestampInSeconds:impression1_ts];
  [bookKeeper recordNewImpressionForMessage:@"m1" withStartTimestampInSeconds:impression2_ts];

  impressions = [bookKeeper getImpressions];
  // For the same message, we only record the last impression record.
  XCTAssertEqual(1, [impressions count]);
  XCTAssertEqualWithAccuracy(impression2_ts, impressions[0].impressionTimeInSeconds, 0.1);

  // Verify the last display time.
  XCTAssertEqualWithAccuracy(impression2_ts, [bookKeeper lastDisplayTime], 0.1);

  double impression3_ts = 45000;

  [bookKeeper recordNewImpressionForMessage:@"m2" withStartTimestampInSeconds:impression3_ts];
  impressions = [bookKeeper getImpressions];
  // Now we should see two different impression records for two different messages.
  XCTAssertEqual(2, [impressions count]);
  // Verify the last display time is updated again.
  XCTAssertEqualWithAccuracy(impression3_ts, [bookKeeper lastDisplayTime], 0.1);
}

- (void)testRecordFetchTimes {
  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];

  double fetch1_ts = 12345;
  double fetch2_ts = 34567;
  [bookKeeper recordNewFetchWithFetchCount:10
                    withTimestampInSeconds:fetch1_ts
                         nextFetchWaitTime:nil];
  [bookKeeper recordNewFetchWithFetchCount:10
                    withTimestampInSeconds:fetch2_ts
                         nextFetchWaitTime:nil];

  XCTAssertEqualWithAccuracy(fetch2_ts, [bookKeeper lastFetchTime], 0.1);
}

- (void)testRecordFetchTimesWithFetchWaitTime {
  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];

  double fetch1_ts = 12345;
  NSNumber *fetchWaitTime = [NSNumber numberWithInt:30000];
  [bookKeeper recordNewFetchWithFetchCount:10
                    withTimestampInSeconds:fetch1_ts
                         nextFetchWaitTime:fetchWaitTime];
  XCTAssertEqualWithAccuracy(fetchWaitTime.doubleValue, [bookKeeper nextFetchWaitTime], 0.1);
}

- (void)testRecordFetchTimesWithFetchWaitTimeOverCap {
  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];

  double fetch1_ts = 12345;
  NSNumber *fetchWaitTime = [NSNumber numberWithInt:30000];
  [bookKeeper recordNewFetchWithFetchCount:10
                    withTimestampInSeconds:fetch1_ts
                         nextFetchWaitTime:fetchWaitTime];
  XCTAssertEqualWithAccuracy(fetchWaitTime.doubleValue, [bookKeeper nextFetchWaitTime], 0.1);

  // Second recording use a very large fetch wait time: 30000000 is to large to be accepted.
  NSNumber *fetchWaitTime2 = [NSNumber numberWithInt:30000000];
  [bookKeeper recordNewFetchWithFetchCount:10
                    withTimestampInSeconds:fetch1_ts
                         nextFetchWaitTime:fetchWaitTime2];
  // Next fetch wait time is still the same as from fetchWaitTime
  XCTAssertEqualWithAccuracy(fetchWaitTime.doubleValue, [bookKeeper nextFetchWaitTime], 0.1);
}

- (void)testFetchImpressions {
  NSString *message1 = @"message1 id";
  double message1ImpressionTime = 1000.0;

  NSString *message2 = @"message2 id";
  double message2ImpressionTime = 2000.0;

  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];
  // Set up existing impressions.
  [bookKeeper recordNewImpressionForMessage:message1
                withStartTimestampInSeconds:message1ImpressionTime];
  [bookKeeper recordNewImpressionForMessage:message2
                withStartTimestampInSeconds:message2ImpressionTime];

  NSArray<FIRIAMImpressionRecord *> *fetchedImpressions = [bookKeeper getImpressions];

  XCTAssertEqual(2, fetchedImpressions.count);

  FIRIAMImpressionRecord *first = fetchedImpressions[0];
  XCTAssertEqualObjects(first.messageID, message1);
  XCTAssertEqualWithAccuracy((double)first.impressionTimeInSeconds, message1ImpressionTime, 0.1);

  FIRIAMImpressionRecord *second = fetchedImpressions[1];
  XCTAssertEqualObjects(second.messageID, message2);
  XCTAssertEqualWithAccuracy((double)second.impressionTimeInSeconds, message2ImpressionTime, 0.1);

  NSArray<NSString *> *messageIDs = [bookKeeper getMessageIDsFromImpressions];
  XCTAssertEqualObjects(messageIDs[0], message1);
  XCTAssertEqualObjects(messageIDs[1], message2);
}

- (void)testClearImpressionsForMessageIDs {
  FIRIAMBookKeeperViaUserDefaults *bookKeeper =
      [[FIRIAMBookKeeperViaUserDefaults alloc] initWithUserDefaults:self.userDefaultsForTesting];
  [bookKeeper cleanupImpressions];

  NSArray<FIRIAMImpressionRecord *> *impressions = [bookKeeper getImpressions];
  XCTAssertEqual(0, [impressions count]);

  double impression1_ts = 12345;
  double impression2_ts = 34567;
  double impression3_ts = 34567;

  [bookKeeper recordNewImpressionForMessage:@"m1" withStartTimestampInSeconds:impression1_ts];
  [bookKeeper recordNewImpressionForMessage:@"m2" withStartTimestampInSeconds:impression2_ts];
  [bookKeeper recordNewImpressionForMessage:@"m3" withStartTimestampInSeconds:impression3_ts];

  [bookKeeper clearImpressionsWithMessageList:@[ @"m1", @"m3" ]];

  impressions = [bookKeeper getImpressions];

  // Only impressions about m2 remains.
  XCTAssertEqual(1, [impressions count]);
  XCTAssertEqualObjects(impressions[0].messageID, @"m2");
}

@end
