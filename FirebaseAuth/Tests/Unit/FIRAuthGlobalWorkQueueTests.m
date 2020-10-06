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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"

/** @class FIRAuthGlobalWorkQueueTests
    @brief Tests for @c FIRAuthGlobalWorkQueue .
 */
@interface FIRAuthGlobalWorkQueueTests : XCTestCase
@end
@implementation FIRAuthGlobalWorkQueueTests

- (void)testSingleton {
  dispatch_queue_t queue1 = FIRAuthGlobalWorkQueue();
  XCTAssertNotNil(queue1);
  dispatch_queue_t queue2 = FIRAuthGlobalWorkQueue();
  XCTAssertEqual(queue1, queue2);
}

@end
