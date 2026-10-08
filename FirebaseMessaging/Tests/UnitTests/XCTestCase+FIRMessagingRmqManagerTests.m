/*
 * Copyright 2020 Google LLC
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

#import "FirebaseMessaging/Tests/UnitTests/XCTestCase+FIRMessagingRmqManagerTests.h"

#import <Foundation/Foundation.h>

#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"

@interface FIRMessagingRmqManager (FIRMessagingRmqManagerTests)
- (dispatch_queue_t)databaseOperationQueue;
@end

// Opening or creating a database can be slow on heavily loaded CI simulators. A generous timeout
// only delays tests that are already failing.
static const NSTimeInterval kDrainDatabaseQueueTimeout = 10.0;

@implementation XCTestCase (FIRMessagingRmqManagerTests)

- (void)waitForDrainDatabaseQueueForRmqManager:(FIRMessagingRmqManager *)manager {
  dispatch_queue_t databaseQueue = [manager databaseOperationQueue];
  if (databaseQueue == nil) {
    return;
  }

  XCTestExpectation *drainDatabaseQueueExpectation =
      [self expectationWithDescription:@"drainDatabaseQueue"];
  dispatch_async([manager databaseOperationQueue], ^{
    [drainDatabaseQueueExpectation fulfill];
  });
  [self waitForExpectations:@[ drainDatabaseQueueExpectation ] timeout:kDrainDatabaseQueueTimeout];
}

@end
