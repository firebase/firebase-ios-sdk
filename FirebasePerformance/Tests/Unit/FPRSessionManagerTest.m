// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager+Private.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

#import <OCMock/OCMock.h>

NSString *const testSessionId = @"testSessionId";

@interface FPRSessionManagerTest : XCTestCase

@end

@implementation FPRSessionManagerTest

/** Validate the instance gets created and it is a singleton. */
- (void)testInstanceCreation {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  XCTAssertNotNil(instance);
  XCTAssertEqual(instance, [FPRSessionManager sharedInstance]);
}

/** Validate that gauge collection does not change when calling renew method immediately. */
- (void)testGaugeDoesNotStopBeforeMaxDuration {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance updateSessionId:testSessionId forceGauges:true];
  [instance stopGaugesIfRunningTooLong:[NSDate date]];
  XCTAssertNotNil([FPRGaugeManager sharedInstance].cpuGaugeCollector);
  XCTAssertNotNil([FPRGaugeManager sharedInstance].memoryGaugeCollector);
}

/** Validate that gauge collection stops when calling renew method after max duration reached. */
- (void)testGaugeStopsAfterMaxDuration {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance updateSessionId:testSessionId forceGauges:true];
  NSTimeInterval maxDurationSeconds =
      [[FPRConfigurations sharedInstance] maxSessionLengthInMinutes] * 60;
  [instance stopGaugesIfRunningTooLong:[[NSDate date] dateByAddingTimeInterval:maxDurationSeconds]];
  XCTAssertNil([FPRGaugeManager sharedInstance].cpuGaugeCollector);
  XCTAssertNil([FPRGaugeManager sharedInstance].memoryGaugeCollector);
}

/** Validate that sessionId changes on new session. */
- (void)testUpdateSessionId {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance updateSessionId:testSessionId];
  NSString *sessionId = instance.sessionDetails.sessionId;
  [instance updateSessionId:@"testSessionId2"];
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications. */
- (void)testUpdateSessionIdPostsNotification {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance updateSessionId:testSessionId];
  NSString *sessionId = instance.sessionDetails.sessionId;

  __block BOOL receivedNotification = NO;
  [instance.sessionNotificationCenter addObserverForName:kFPRSessionIdUpdatedNotification
                                                  object:instance
                                                   queue:[NSOperationQueue mainQueue]
                                              usingBlock:^(NSNotification *note) {
                                                receivedNotification = YES;
                                              }];

  [instance updateSessionId:@"testSessionId2"];

  XCTAssertTrue(receivedNotification);
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications with the session details. */
- (void)testSessionIdUpdationSendsNotificationWithSessionDetails {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance updateSessionId:testSessionId];
  NSString *sessionId = instance.sessionDetails.sessionId;

  __block BOOL containsSessionDetails = NO;
  __block FPRSessionDetails *updatedSessionDetails = nil;
  [instance.sessionNotificationCenter
      addObserverForName:kFPRSessionIdUpdatedNotification
                  object:instance
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                NSDictionary<NSString *, FPRSessionDetails *> *userInfo = note.userInfo;
                FPRSessionDetails *sessionDetails =
                    [userInfo valueForKey:kFPRSessionIdNotificationKey];
                if (sessionDetails != nil) {
                  containsSessionDetails = YES;
                  updatedSessionDetails = sessionDetails;
                }
              }];

  [instance updateSessionId:@"testSessionId2"];

  XCTAssertTrue(containsSessionDetails);
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
  XCTAssertEqual(updatedSessionDetails.sessionId, instance.sessionDetails.sessionId);
}

@end
