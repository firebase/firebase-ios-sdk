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

#import "FirebaseDatabase/Tests/Helpers/FTestBase.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FKeepSyncedTest : FTestBase

@end

@implementation FKeepSyncedTest

static NSUInteger fGlobalKeepSyncedTestCounter = 0;

- (void)assertIsKeptSynced:(FIRDatabaseQuery *)query {
  FIRDatabaseReference *ref = query.ref;

  // First set a unique value to the value of child
  fGlobalKeepSyncedTestCounter++;
  NSNumber *currentValue = @(fGlobalKeepSyncedTestCounter);
  __block BOOL done = NO;
  [ref setValue:@{@"child" : currentValue}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertNil(error);
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  // Next go offline, if it's kept synced we should have kept the value, after going offline no way
  // to get the value except from cache
  [FIRDatabaseReference goOffline];

  [query observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          // We should receive an event
                          XCTAssertEqualObjects(snapshot.value, @{@"child" : currentValue});
                          done = YES;
                        }];

  WAIT_FOR(done);
  // All good, go back online
  [FIRDatabaseReference goOnline];
}

- (void)assertNotKeptSynced:(FIRDatabaseQuery *)query {
  FIRDatabaseReference *ref = query.ref;

  // First set a unique value to the value of child
  fGlobalKeepSyncedTestCounter++;
  NSNumber *currentValue = @(fGlobalKeepSyncedTestCounter);
  fGlobalKeepSyncedTestCounter++;
  NSNumber *newValue = @(fGlobalKeepSyncedTestCounter);
  __block BOOL done = NO;
  [ref setValue:@{@"child" : currentValue}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertNil(error);
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  // Next go offline, if it's kept synced we should have kept the value, after going offline no way
  // to get the value except from cache
  [FIRDatabaseReference goOffline];

  [query observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          // We should receive an event
                          XCTAssertEqualObjects(snapshot.value, @{@"child" : newValue});
                          done = YES;
                        }];

  // By now, if we had it synced we should have gotten an event with the wrong value
  // Write a new value so the value event listener will be triggered
  [ref setValue:@{@"child" : newValue}];
  WAIT_FOR(done);

  // All good, go back online
  [FIRDatabaseReference goOnline];
}

- (void)testKeepSynced {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];

  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  [ref keepSynced:NO];
  [self assertNotKeptSynced:ref];
}

- (void)testManyKeepSyncedCallsDontAccumulate {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];

  [ref keepSynced:YES];
  [ref keepSynced:YES];
  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  // If it were balanced, this would not be enough
  [ref keepSynced:NO];
  [ref keepSynced:NO];
  [self assertNotKeptSynced:ref];

  // If it were balanced, this would not be enough
  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  // cleanup
  [ref keepSynced:NO];
}

- (void)testRemoveAllObserversDoesNotAffectKeepSynced {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];

  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  [ref removeAllObservers];
  [self assertIsKeptSynced:ref];

  // cleanup
  [ref keepSynced:NO];
}

- (void)testRemoveSingleObserverDoesNotAffectKeepSynced {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];

  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  __block BOOL done = NO;
  FIRDatabaseHandle handle = [ref observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           done = YES;
                                         }];

  WAIT_FOR(done);
  [ref removeObserverWithHandle:handle];

  [self assertIsKeptSynced:ref];

  // cleanup
  [ref keepSynced:NO];
}

- (void)testKeepSyncedNoDoesNotAffectExistingObserver {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];

  [ref keepSynced:YES];
  [self assertIsKeptSynced:ref];

  __block BOOL done = NO;
  FIRDatabaseHandle handle = [ref observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           done = [snapshot.value isEqual:@"done"];
                                         }];

  // cleanup
  [ref keepSynced:NO];

  [ref setValue:@"done"];

  WAIT_FOR(done);
  [ref removeObserverWithHandle:handle];
}

- (void)testDifferentQueriesAreIndependent {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];
  FIRDatabaseQuery *query1 = [ref queryLimitedToFirst:1];
  FIRDatabaseQuery *query2 = [ref queryLimitedToFirst:2];

  [query1 keepSynced:YES];
  [self assertIsKeptSynced:query1];
  [self assertNotKeptSynced:query2];

  [query2 keepSynced:YES];
  [self assertIsKeptSynced:query1];
  [self assertIsKeptSynced:query2];

  [query1 keepSynced:NO];
  [self assertIsKeptSynced:query2];
  [self assertNotKeptSynced:query1];

  [query2 keepSynced:NO];
  [self assertNotKeptSynced:query1];
  [self assertNotKeptSynced:query2];
}

- (void)testChildIsKeptSynced {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNodeWithoutPersistence];
  FIRDatabaseReference *child = [ref child:@"random-child"];

  [ref keepSynced:YES];
  [self assertIsKeptSynced:child];

  // cleanup
  [ref keepSynced:NO];
}

- (void)testRootIsKeptSynced {
  FIRDatabaseReference *ref = [[FTestHelpers getRandomNodeWithoutPersistence] root];

  [ref keepSynced:YES];
  // Run on random child to make sure writes from this test doesn't interfere with any other tests.
  [self assertIsKeptSynced:[ref childByAutoId]];

  // cleanup
  [ref keepSynced:NO];
}

// TODO[offline]: Cancel listens for keep synced....

@end
