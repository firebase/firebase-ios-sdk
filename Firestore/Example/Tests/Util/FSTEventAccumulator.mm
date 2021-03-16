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

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/XCTestCase+Await.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRDocumentSnapshot.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRQuerySnapshot.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRSnapshotMetadata.h"

#include "Firestore/core/src/util/hard_assert.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTEventAccumulator ()
- (instancetype)initForTest:(XCTestCase *)testCase NS_DESIGNATED_INITIALIZER;

@property(nonatomic, weak, readonly) XCTestCase *testCase;

@property(nonatomic, assign) NSUInteger maxEvents;
@property(nonatomic, strong, nullable) XCTestExpectation *expectation;
@end

@implementation FSTEventAccumulator {
  NSMutableArray<id> *_events;
  bool _rejectAdditionalEvents;
}

+ (instancetype)accumulatorForTest:(XCTestCase *)testCase {
  return [[FSTEventAccumulator alloc] initForTest:testCase];
}

- (instancetype)initForTest:(XCTestCase *)testCase {
  if (self = [super init]) {
    _testCase = testCase;
    _events = [NSMutableArray array];
    _rejectAdditionalEvents = false;
  }
  return self;
}

- (NSArray<id> *)awaitEvents:(NSUInteger)events name:(NSString *)name {
  @synchronized(self) {
    HARD_ASSERT(!self.expectation, "Existing expectation still pending?");
    self.expectation = [self.testCase expectationWithDescription:name];
    self.maxEvents = self.maxEvents + events;
    [self checkFulfilled];
  }

  // Don't await within @synchronized block to avoid deadlocking.
  [self.testCase awaitExpectations];

  return [_events subarrayWithRange:NSMakeRange(self.maxEvents - events, events)];
}

- (id)awaitEventWithName:(NSString *)name {
  NSArray<id> *events = [self awaitEvents:1 name:name];
  return events[0];
}

- (id)awaitLocalEvent {
  id event;
  do {
    event = [self awaitEventWithName:@"Local Event"];
  } while (![self hasPendingWrites:event]);
  return event;
}

- (id)awaitRemoteEvent {
  id event;
  do {
    event = [self awaitEventWithName:@"Remote Event"];
  } while ([self hasPendingWrites:event]);
  return event;
}

- (BOOL)hasPendingWrites:(id)event {
  if ([event isKindOfClass:[FIRDocumentSnapshot class]]) {
    return ((FIRDocumentSnapshot *)event).metadata.hasPendingWrites;
  } else {
    HARD_ASSERT([event isKindOfClass:[FIRQuerySnapshot class]], "Unexpected event: %s", event);
    return ((FIRQuerySnapshot *)event).metadata.hasPendingWrites;
  }
}

- (void (^)(id _Nullable, NSError *_Nullable))valueEventHandler {
  return ^void(id _Nullable value, NSError *) {
    // We can't store nil in the _events array, but these are still interesting to tests so store
    // NSNull instead.
    id event = value ? value : [NSNull null];

    @synchronized(self) {
      HARD_ASSERT(!self->_rejectAdditionalEvents, "Unexpected event: %s", event);

      [self->_events addObject:event];
      [self checkFulfilled];
    }
  };
}

- (void)assertNoAdditionalEvents {
  @synchronized(self) {
    _rejectAdditionalEvents = true;
  }
}

- (void)checkFulfilled {
  if (_events.count >= self.maxEvents) {
    [self.expectation fulfill];
    self.expectation = nil;
  }
}

@end

NS_ASSUME_NONNULL_END
