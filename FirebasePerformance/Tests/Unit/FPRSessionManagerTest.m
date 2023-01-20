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

@property FPRSessionManager *instance;

@end

@implementation FPRSessionManagerTest

- (void)setUp {
  [super setUp];
  NSNotificationCenter *notificationCenter = [[NSNotificationCenter alloc] init];
  _instance = [[FPRSessionManager alloc] initWithNotificationCenter:notificationCenter];
}

/** Validate the instance gets created and it is a singleton. */
- (void)testInstanceCreation {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  XCTAssertNotNil(instance);
  XCTAssertEqual(instance, [FPRSessionManager sharedInstance]);
}

/** Validate that gauge collection does not change when calling renew method immediately. */
- (void)testGaugeDoesNotStopBeforeMaxDuration {
  id instance = [OCMockObject partialMockForObject:self.instance];
  OCMStub([instance isGaugeCollectionEnabledForSessionId:[OCMArg any]]).andReturn(true);
  [instance updateSessionId:testSessionId];
  BOOL gaugeStopped = [instance stopGaugesIfRunningTooLong:[NSDate date]];
  XCTAssertFalse(gaugeStopped);
}

/** Validate that gauge collection stops when calling renew method after max duration reached. */
- (void)testGaugeStopsAfterMaxDuration {
  id instance = [OCMockObject partialMockForObject:self.instance];
  OCMStub([instance isGaugeCollectionEnabledForSessionId:[OCMArg any]]).andReturn(true);
  [instance updateSessionId:testSessionId];
  NSTimeInterval maxDurationSeconds =
      [[FPRConfigurations sharedInstance] maxSessionLengthInMinutes] * 60;
  BOOL gaugeStopped = [instance
      stopGaugesIfRunningTooLong:[[NSDate date] dateByAddingTimeInterval:maxDurationSeconds]];
  XCTAssertTrue(gaugeStopped);
}

/** Validate that sessionId changes on new session. */
- (void)testUpdateSessionId {
  [self.instance updateSessionId:testSessionId];
  NSString *sessionId = self.instance.sessionDetails.sessionId;
  [self.instance updateSessionId:@"testSessionId2"];
  XCTAssertNotEqual(sessionId, self.instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications. */
- (void)testUpdateSessionIdPostsNotification {
  [self.instance updateSessionId:testSessionId];
  NSString *sessionId = self.instance.sessionDetails.sessionId;

  __block BOOL receivedNotification = NO;
  [self.instance.sessionNotificationCenter addObserverForName:kFPRSessionIdUpdatedNotification
                                                       object:self.instance
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
                                                     receivedNotification = YES;
                                                   }];

  [self.instance updateSessionId:@"testSessionId2"];

  XCTAssertTrue(receivedNotification);
  XCTAssertNotEqual(sessionId, self.instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications with the session details. */
- (void)testUpdateSessionIdPostsNotificationWithSessionDetails {
  [self.instance updateSessionId:testSessionId];
  NSString *sessionId = self.instance.sessionDetails.sessionId;

  __block BOOL containsSessionDetails = NO;
  __block FPRSessionDetails *updatedSessionDetails = nil;
  [self.instance.sessionNotificationCenter
      addObserverForName:kFPRSessionIdUpdatedNotification
                  object:self.instance
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

  [self.instance updateSessionId:@"testSessionId2"];

  XCTAssertTrue(containsSessionDetails);
  XCTAssertNotEqual(sessionId, self.instance.sessionDetails.sessionId);
  XCTAssertEqual(updatedSessionDetails.sessionId, self.instance.sessionDetails.sessionId);
}

@end
