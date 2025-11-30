/*
 * Copyright 2025 Google LLC
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
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"

@interface RCNConfigDBManagerTests : XCTestCase
@end

@implementation RCNConfigDBManagerTests

- (void)testIsNewDatabaseThreadSafety {
  RCNConfigDBManager *dbManager = [RCNConfigDBManager sharedInstance];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Concurrent access to isNewDatabase"];
  expectation.expectedFulfillmentCount = 100;

  for (int i = 0; i < 100; i++) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [dbManager isNewDatabase];
      [expectation fulfill];
    });
  }

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
