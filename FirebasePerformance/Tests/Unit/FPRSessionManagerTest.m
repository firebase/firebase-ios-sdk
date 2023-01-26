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
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager+Private.h"

#import <OCMock/OCMock.h>

NSString *const testSessionId = @"testSessionId";

@interface FPRSessionManagerTest : XCTestCase

@property FPRSessionManager *instance;

@property FPRGaugeManager *gaugeManager;

@end

@implementation FPRSessionManagerTest

- (void)setUp {
  [super setUp];
  NSNotificationCenter *notificationCenter = [[NSNotificationCenter alloc] init];
  _gaugeManager = [[FPRGaugeManager alloc] initWithGauges:FPRGaugeCPU | FPRGaugeMemory];
  _instance = [[FPRSessionManager alloc] initWithGaugeManager:_gaugeManager
                                           notificationCenter:notificationCenter];
}

/** Validate the instance gets created and it is a singleton. */
- (void)testInstanceCreation {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  XCTAssertNotNil(instance);
  XCTAssertEqual(instance, [FPRSessionManager sharedInstance]);
}

/** Validate that gauge collection does not change when calling renew method immediately. */
- (void)testGaugeDoesNotStopBeforeMaxDuration {
  FPRSessionManager *manager =
      [[FPRSessionManager alloc] initWithGaugeManager:self.gaugeManager
                                   notificationCenter:[NSNotificationCenter defaultCenter]];
  id mockInstance = [OCMockObject partialMockForObject:[FPRConfigurations sharedInstance]];
  OCMStub([mockInstance sessionsSamplingPercentage]).andReturn(100);
  [manager updateSessionId:testSessionId];
  XCTAssertTrue(manager.gaugeManager.activeGauges > 0);

  OCMStub([mockInstance maxSessionLengthInMinutes]).andReturn(5);
  XCTAssertTrue(manager.gaugeManager.activeGauges > 0);

  [mockInstance stopMocking];
}

/** Validate that gauge collection stops when calling renew method after max duration reached. */
- (void)testGaugeStopsAfterMaxDuration {
  FPRSessionManager *manager =
      [[FPRSessionManager alloc] initWithGaugeManager:self.gaugeManager
                                   notificationCenter:[NSNotificationCenter defaultCenter]];
  id mockInstance = [OCMockObject partialMockForObject:[FPRConfigurations sharedInstance]];
  OCMStub([mockInstance sessionsSamplingPercentage]).andReturn(100);
  [manager updateSessionId:testSessionId];
  XCTAssertTrue(manager.gaugeManager.activeGauges > 0);

  XCTAssertEqual(manager.sessionDetails.options & FPRSessionOptionsGauges, FPRSessionOptionsGauges);
  OCMStub([mockInstance maxSessionLengthInMinutes]).andReturn(0);
  [manager stopGaugesIfRunningTooLong];
  XCTAssertEqual(manager.gaugeManager.activeGauges, 0);

  [mockInstance stopMocking];
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
