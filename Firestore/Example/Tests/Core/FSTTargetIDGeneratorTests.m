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

#import "Firestore/Source/Core/FSTTargetIDGenerator.h"

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FSTTargetIDGenerator ()
- (instancetype)initWithGeneratorID:(NSInteger)generatorID startingAfterID:(FSTTargetID)after;
@end

@interface FSTTargetIDGeneratorTests : XCTestCase
@end

@implementation FSTTargetIDGeneratorTests

- (void)testConstructor {
  XCTAssertEqual([[[FSTTargetIDGenerator alloc] initWithGeneratorID:0 startingAfterID:0] nextID],
                 2);
  XCTAssertEqual([[[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:0] nextID],
                 1);

  XCTAssertEqual([[FSTTargetIDGenerator generatorForLocalStoreStartingAfterID:0] nextID], 2);
  XCTAssertEqual([[FSTTargetIDGenerator generatorForSyncEngineStartingAfterID:0] nextID], 1);
}

- (void)testSkipPast {
  FSTTargetIDGenerator *gen =
      [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:-1];
  XCTAssertEqual([gen nextID], 1);

  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:2];
  XCTAssertEqual([gen nextID], 3);

  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:4];
  XCTAssertEqual([gen nextID], 5);

  for (int i = 4; i < 12; ++i) {
    FSTTargetIDGenerator *gen0 =
        [[FSTTargetIDGenerator alloc] initWithGeneratorID:0 startingAfterID:i];
    FSTTargetIDGenerator *gen1 =
        [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:i];
    XCTAssertEqual([gen0 nextID], i + 2 & ~1, @"Skip failed for index %d", i);
    XCTAssertEqual([gen1 nextID], i + 1 | 1, @"Skip failed for index %d", i);
  }

  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:12];
  XCTAssertEqual([gen nextID], 13);

  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:0 startingAfterID:22];
  XCTAssertEqual([gen nextID], 24);
}

- (void)testIncrement {
  FSTTargetIDGenerator *gen =
      [[FSTTargetIDGenerator alloc] initWithGeneratorID:0 startingAfterID:0];
  XCTAssertEqual([gen nextID], 2);
  XCTAssertEqual([gen nextID], 4);
  XCTAssertEqual([gen nextID], 6);
  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:0 startingAfterID:46];
  XCTAssertEqual([gen nextID], 48);
  XCTAssertEqual([gen nextID], 50);
  XCTAssertEqual([gen nextID], 52);
  XCTAssertEqual([gen nextID], 54);

  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:0];
  XCTAssertEqual([gen nextID], 1);
  XCTAssertEqual([gen nextID], 3);
  XCTAssertEqual([gen nextID], 5);
  gen = [[FSTTargetIDGenerator alloc] initWithGeneratorID:1 startingAfterID:46];
  XCTAssertEqual([gen nextID], 47);
  XCTAssertEqual([gen nextID], 49);
  XCTAssertEqual([gen nextID], 51);
  XCTAssertEqual([gen nextID], 53);
}

@end

NS_ASSUME_NONNULL_END
