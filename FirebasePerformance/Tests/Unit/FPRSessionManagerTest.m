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

#import <OCMock/OCMock.h>

@interface FPRSessionManagerTest : XCTestCase

@end

@implementation FPRSessionManagerTest

/** Validate the instance gets created and it is a singleton. */
- (void)testInstanceCreation {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  XCTAssertNotNil(instance);
  XCTAssertEqual(instance, [FPRSessionManager sharedInstance]);
}

/** Validate that valid sessionId always exists. */
- (void)testSessionIdExistance {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance startTrackingAppStateChanges];

  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                                    object:[UIApplication sharedApplication]];

  XCTAssertNotNil(instance.sessionDetails.sessionId);

  NSString *lowercaseSessionId = [instance.sessionDetails.sessionId lowercaseString];
  XCTAssertEqualObjects(lowercaseSessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId does not change when calling renew method immediately. */
- (void)testSessionIdNotGettingRenewed {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance startTrackingAppStateChanges];
  NSString *sessionId = instance.sessionDetails.sessionId;
  [instance renewSessionIdIfRunningTooLong];
  XCTAssertEqualObjects(sessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes on application state changes. */
- (void)testSessionIdUpdation {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance startTrackingAppStateChanges];
  NSString *sessionId = instance.sessionDetails.sessionId;
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                                    object:[UIApplication sharedApplication]];
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications. */
- (void)testSessionIdUpdationThrowsNotification {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance startTrackingAppStateChanges];
  NSString *sessionId = instance.sessionDetails.sessionId;

  __block BOOL receivedNotification = NO;
  [instance.sessionNotificationCenter addObserverForName:kFPRSessionIdUpdatedNotification
                                                  object:instance
                                                   queue:[NSOperationQueue mainQueue]
                                              usingBlock:^(NSNotification *note) {
                                                receivedNotification = YES;
                                              }];

  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                                    object:[UIApplication sharedApplication]];

  XCTAssertTrue(receivedNotification);
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
}

/** Validate that sessionId changes sends notifications with the session details. */
- (void)testSessionIdUpdationSendsNotificationWithSessionDetails {
  FPRSessionManager *instance = [FPRSessionManager sharedInstance];
  [instance startTrackingAppStateChanges];
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

  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                                    object:[UIApplication sharedApplication]];

  XCTAssertTrue(containsSessionDetails);
  XCTAssertNotEqual(sessionId, instance.sessionDetails.sessionId);
  XCTAssertEqual(updatedSessionDetails.sessionId, instance.sessionDetails.sessionId);
}

@end
