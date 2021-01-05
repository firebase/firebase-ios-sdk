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

#import "FirebaseDatabase/Tests/Integration/FPersist.h"
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseReference_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseDatabase/Tests/Helpers/FDevice.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@implementation FPersist

- (void)setUp {
  [super setUp];

  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSString *baseDir = [FPersist getFirebaseDir];
  // HACK: We want to clean up old persistence files from previous test runs, but on OSX, baseDir is
  // going to be something like /Users/michael/Documents/firebase, and we probably shouldn't blindly
  // delete it, since somebody might have actual documents there.  We should probably change the
  // directory where we store persistence on OSX to .firebase or something to avoid colliding with
  // real files, but for now, we'll leave it and just manually delete each of the /0, /1, /2, etc.
  // directories that may exist from previous test runs.  As of now (2014/09/07), these directories
  // only go up to ~50, but if we add a ton more tests, we may need to increase the 100.  But I'm
  // guessing we'll rewrite persistence and move the persistence folder before then though.
  for (int i = 0; i < 100; i++) {
    // TODO: This hack is uneffective because the format now follows different rules. Persistence
    // really needs a purge option
    NSString *dir = [NSString stringWithFormat:@"%@/%d", baseDir, i];
    if ([fileManager fileExistsAtPath:dir]) {
      NSError *error;
      [[NSFileManager defaultManager] removeItemAtPath:dir error:&error];
      if (error) {
        XCTFail(@"Failed to clear persisted data at %@: %@", dir, error);
      }
    }
  }
}

- (void)testSetIsResentAfterRestart {
  FIRDatabaseReference *readerRef = [FTestHelpers getRandomNode];
  NSString *url = [readerRef description];
  FDevice *device = [[FDevice alloc] initOfflineWithUrl:url];

  // Monitor the data at this location.
  __block FIRDataSnapshot *readSnapshot = nil;
  [readerRef observeEventType:FIRDataEventTypeValue
                    withBlock:^(FIRDataSnapshot *snapshot) {
                      readSnapshot = snapshot;
                    }];

  // Do some sets while offline and then "kill" the app, so it doesn't get sent to Firebase.
  [device do:^(FIRDatabaseReference *ref) {
    [ref setValue:@{
      @"a" : @42,
      @"b" : @3.1415,
      @"c" : @"hello",
      @"d" : @{@"dd" : @"dd-val", @".priority" : @"d-pri"}
    }];
    [[ref child:@"a"] setValue:@"a-val"];
    [[ref child:@"c"] setPriority:@"c-pri"];
    [ref updateChildValues:@{@"b" : @"b-val"}];
  }];

  // restart and wait for "idle" (so all pending puts should have been sent).
  [device restartOnline];
  [device waitForIdleUsingWaiter:self];

  // Pending sets should have gone through.
  id expected = @{
    @"a" : @"a-val",
    @"b" : @"b-val",
    @"c" : @{@".value" : @"hello", @".priority" : @"c-pri"},
    @"d" : @{@"dd" : @"dd-val", @".priority" : @"d-pri"}
  };
  [self waitForExportValueOf:readerRef toBe:expected];

  // Set the value to something else (12).
  [readerRef setValue:@12];

  // "restart" the app again and make sure it doesn't set it to 42 again.
  [device restartOnline];
  [device waitForIdleUsingWaiter:self];

  // Make sure data is still 12.
  [self waitForRoundTrip:readerRef];
  XCTAssertEqual(readSnapshot.value, @12, @"Read data should still be 12.");
  [device dispose];
}

- (void)testSetIsReappliedAfterRestart {
  FDevice *device = [[FDevice alloc] initOffline];

  // Do some sets while offline and then "kill" the app, so it doesn't get sent to Firebase.
  [device do:^(FIRDatabaseReference *ref) {
    [ref setValue:@{@"a" : @42, @"b" : @3.1415, @"c" : @"hello"}];
    [[ref child:@"a"] setValue:@"a-val"];
    [[ref child:@"c"] setPriority:@"c-pri"];
    [ref updateChildValues:@{@"b" : @"b-val"}];
  }];

  // restart the app offline and observe the data.
  [device restartOffline];

  // Pending sets should be visible
  id expected =
      @{@"a" : @"a-val", @"b" : @"b-val", @"c" : @{@".value" : @"hello", @".priority" : @"c-pri"}};
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForExportValueOf:ref toBe:expected];
  }];
  [device dispose];
}

- (void)testServerDataCachedOffline1 {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];
  __block BOOL done = NO;
  id data = @{@"a" : @1, @"b" : @2};
  [writerRef setValue:data
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];
  WAIT_FOR(done);

  // Wait for the data to get it cached.
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:ref toBe:data];
  }];

  // Should still be there after restart, offline.
  [device restartOffline];
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:ref toBe:data];
  }];

  // Children should be there too.
  [device restartOffline];
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:[ref child:@"a"] toBe:@1];
  }];
  [device dispose];
}

- (void)testServerDataCompleteness1 {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];
  id data = @{@"child" : @{@"a" : @1, @"b" : @2}, @"other" : @"blah"};
  [self waitForCompletionOf:writerRef setValue:data];

  // Wait for each child to get it cached (but not the parent).
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:[ref child:@"child/a"] toBe:@1];
    [self waitForValueOf:[ref child:@"child/b"] toBe:@2];
    [self waitForValueOf:[ref child:@"other"] toBe:@"blah"];
  }];

  // Restart, offline, should get child_added events, but not value.
  [device restartOffline];
  __block BOOL gotA, gotB;
  [device do:^(FIRDatabaseReference *ref) {
    FIRDatabaseReference *childRef = [ref child:@"child"];
    [childRef observeEventType:FIRDataEventTypeChildAdded
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       if ([snapshot.key isEqualToString:@"a"]) {
                         XCTAssertEqualObjects(snapshot.value, @1, @"Got a");
                         gotA = YES;
                       } else if ([snapshot.key isEqualToString:@"b"]) {
                         XCTAssertEqualObjects(snapshot.value, @2, @"Got a");
                         gotB = YES;
                       } else {
                         XCTFail(@"Unexpected child event.");
                       }
                     }];

    // Listen for value events (which we should *not* get).
    [childRef observeEventType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       XCTFail(@"Got a value event with incomplete data!");
                     }];

    // Wait for another location just to make sure we wait long enough that we /would/ get a value
    // event if it was coming.
    [self waitForValueOf:[ref child:@"other"] toBe:@"blah"];
  }];

  XCTAssertTrue(gotA && gotB, @"Got a and b.");
  [device dispose];
}

- (void)testServerDataCompleteness2 {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];
  id data = @{@"a" : @1, @"b" : @2};
  [self waitForCompletionOf:writerRef setValue:data];

  // Wait for the children individually.
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:[ref child:@"a"] toBe:@1];
    [self waitForValueOf:[ref child:@"b"] toBe:@2];
  }];

  // Should still be there after restart, offline.
  [device restartOffline];
  [device do:^(FIRDatabaseReference *ref) {
    [ref observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot){
                    // No-op.  Just triggering a listen at this location.
                }];
    [self waitForValueOf:[ref child:@"a"] toBe:@1];
    [self waitForValueOf:[ref child:@"b"] toBe:@2];
  }];
  [device dispose];
}

- (void)testServerDataLimit {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];
  [self waitForCompletionOf:writerRef setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}];

  // Cache limit(2) of the data.
  [device do:^(FIRDatabaseReference *ref) {
    FIRDatabaseQuery *limitRef = [ref queryLimitedToLast:2];
    [self waitForValueOf:limitRef toBe:@{@"b" : @2, @"c" : @3}];
  }];

  // We should be able to get limit(2) data offline, but not the whole node.
  [device restartOffline];
  [device do:^(FIRDatabaseReference *ref) {
    [ref observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          XCTFail(@"Got value event for whole node!");
                        }];

    FIRDatabaseQuery *limitRef = [ref queryLimitedToLast:2];
    [self waitForValueOf:limitRef toBe:@{@"b" : @2, @"c" : @3}];
  }];
  [device dispose];
}

- (void)testRemoveWhileOfflineAndRestart {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];

  [[writerRef child:@"test"] setValue:@"test"];
  [device do:^(FIRDatabaseReference *ref) {
    // Cache this location.
    __block id val = nil;
    [ref observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  val = snapshot.value;
                }];
    [self waitUntil:^BOOL {
      return [val isEqual:@{@"test" : @"test"}];
    }];
  }];
  [device restartOffline];

  __block BOOL done = NO;
  [writerRef removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
    done = YES;
  }];
  WAIT_FOR(done);

  [device goOnline];
  [device waitForIdleUsingWaiter:self];
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:ref toBe:[NSNull null]];
  }];
  [device dispose];
}

- (void)testDeltaSyncAfterRestart {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];

  [writerRef setValue:@"test"];

  [device do:^(FIRDatabaseReference *ref) {
    // Cache this location.
    __block id val = nil;
    [ref observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  val = snapshot.value;
                }];
    [self waitUntil:^BOOL {
      return [val isEqual:@"test"];
    }];
    XCTAssertEqual(ref.repo.dataUpdateCount, 1L, @"Should have gotten one update.");
  }];
  [device restartOnline];

  [device waitForIdleUsingWaiter:self];
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForValueOf:ref toBe:@"test"];
    XCTAssertEqual(ref.repo.dataUpdateCount, 0L, @"Should have gotten no updates.");
  }];
  [device dispose];
}

- (void)testDeltaSyncWorksWithUnfilteredQuery {
  FIRDatabaseReference *writerRef = [FTestHelpers getRandomNode];
  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writerRef description]];

  // List must be large enough to trigger delta sync.
  NSMutableDictionary *longList = [[NSMutableDictionary alloc] init];
  for (NSInteger i = 0; i < 50; i++) {
    NSString *key = [[writerRef childByAutoId] key];
    longList[key] = @{@"order" : @1, @"text" : @"This is an awesome message!"};
  }

  [writerRef setValue:longList];

  [device do:^(FIRDatabaseReference *ref) {
    // Cache this location.
    [self waitForValueOf:[ref queryOrderedByChild:@"order"] toBe:longList];
    XCTAssertEqual(ref.repo.dataUpdateCount, 1L, @"Should have gotten one update.");
  }];
  [device restartOffline];

  // Add a new child while the device is offline.
  FIRDatabaseReference *newChildRef = [writerRef childByAutoId];
  NSDictionary *newChild = @{@"order" : @50, @"text" : @"This is a new appended child!"};

  [self waitForCompletionOf:newChildRef setValue:newChild];
  longList[[newChildRef key]] = newChild;

  [device goOnline];
  [device do:^(FIRDatabaseReference *ref) {
    // Wait for updated value with new child.
    [self waitForValueOf:[ref queryOrderedByChild:@"order"] toBe:longList];
    XCTAssertEqual(ref.repo.rangeMergeUpdateCount, 1L, @"Should have gotten a range merge update.");
  }];
  [device dispose];
}

- (void)testPutsAreRestoredInOrder {
  FDevice *device = [[FDevice alloc] initOffline];

  // Store puts which should have a putId with 10 which is lexiographical small than 9
  [device do:^(FIRDatabaseReference *ref) {
    for (int i = 0; i < 11; i++) {
      [ref setValue:[NSNumber numberWithInt:i]];
    }
  }];

  // restart the app offline and observe the data.
  [device restartOffline];

  // Make sure that the write with putId 10 wins, not 9
  id expected = @10;
  [device do:^(FIRDatabaseReference *ref) {
    [self waitForExportValueOf:ref toBe:expected];
  }];
  [device dispose];
}

- (void)testStoreSetsPerf1 {
  if (!runPerfTests) return;
  // Disable persistence in FDevice for comparison without persistence
  FDevice *device = [[FDevice alloc] initOnline];

  __block BOOL done = NO;
  [device do:^(FIRDatabaseReference *ref) {
    NSDate *start = [NSDate date];
    [self writeChildren:ref count:1000 size:100 waitForComplete:NO];

    [self waitForQueue:ref];

    NSLog(@"Elapsed: %f", [[NSDate date] timeIntervalSinceDate:start]);
    done = YES;
  }];

  WAIT_FOR(done);
  [device dispose];
}

- (void)testStoreListenPerf1 {
  if (!runPerfTests) return;
  // Disable persistence in FDevice for comparison without persistence

  // Write 1000 x 100-byte children, to read back.
  unsigned int count = 1000;
  FIRDatabaseReference *writer = [FTestHelpers getRandomNode];
  [self writeChildren:writer count:count size:100];

  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writer description]];

  __block BOOL done = NO;
  [device do:^(FIRDatabaseReference *ref) {
    NSDate *start = [NSDate date];
    [ref observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          // Wait to make sure we're done persisting everything.
                          [self waitForQueue:ref];
                          XCTAssertEqual(snapshot.childrenCount, count, @"Got correct data.");
                          NSLog(@"Elapsed: %f", [[NSDate date] timeIntervalSinceDate:start]);
                          done = YES;
                        }];
  }];

  WAIT_FOR(done);
  [device dispose];
}

- (void)testRestoreListenPerf1 {
  if (!runPerfTests) return;

  // NOTE: Since this is testing restoration of data from cache after restarting, it only works with
  // persistence on.

  // Write 1000 * 100-byte children, to read back.
  unsigned int count = 1000;
  FIRDatabaseReference *writer = [FTestHelpers getRandomNode];
  [self writeChildren:writer count:count size:100];

  FDevice *device = [[FDevice alloc] initOnlineWithUrl:[writer description]];

  // Get the data cached.
  __block BOOL done = NO;
  [device do:^(FIRDatabaseReference *ref) {
    [ref observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          XCTAssertEqual(snapshot.childrenCount, count, @"Got correct data.");
                          done = YES;
                        }];
  }];
  WAIT_FOR(done);

  // Restart offline and see how long it takes to restore the data from cache.
  [device restartOffline];
  done = NO;
  [device do:^(FIRDatabaseReference *ref) {
    NSDate *start = [NSDate date];
    [ref observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          // Wait to make sure we're done persisting everything.
                          XCTAssertEqual(snapshot.childrenCount, count, @"Got correct data.");
                          [self waitForQueue:ref];
                          NSLog(@"Elapsed: %f", [[NSDate date] timeIntervalSinceDate:start]);
                          done = YES;
                        }];
  }];

  WAIT_FOR(done);
  [device dispose];
}

- (void)writeChildren:(FIRDatabaseReference *)writer
                count:(unsigned int)count
                 size:(unsigned int)size {
  [self writeChildren:writer count:count size:size waitForComplete:YES];
}

- (void)writeChildren:(FIRDatabaseReference *)writer
                count:(unsigned int)count
                 size:(unsigned int)size
      waitForComplete:(BOOL)waitForComplete {
  __block BOOL done = NO;

  NSString *data = [self randomStringOfLength:size];
  for (int i = 0; i < count; i++) {
    [[writer childByAutoId] setValue:data
                 withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                   if (i == (count - 1)) {
                     done = YES;
                   }
                 }];
  }
  if (waitForComplete) {
    WAIT_FOR(done);
  }
}

NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
- (NSString *)randomStringOfLength:(unsigned int)len {
  NSMutableString *randomString = [NSMutableString stringWithCapacity:len];

  for (int i = 0; i < len; i++) {
    [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random() % [letters length]]];
  }
  return randomString;
}

+ (NSString *)getFirebaseDir {
  NSArray *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDir = [dirPaths objectAtIndex:0];
  NSString *firebaseDir = [documentsDir stringByAppendingPathComponent:@"firebase"];

  return firebaseDir;
}

@end
