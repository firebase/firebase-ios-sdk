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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FIRTestAuthTokenProvider.h"
#import "FirebaseDatabase/Tests/Helpers/FTestAuthTokenGenerator.h"
#import "FirebaseDatabase/Tests/Helpers/FTestBase.h"
#import "SharedTestUtilities/FIROptionsMock.h"

@implementation FTestBase

+ (void)setUp {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    [FIROptionsMock mockFIROptions];
    [FIRApp configure];
  });
}

- (void)setUp {
  [super setUp];

  [FIRDatabase setLoggingEnabled:YES];
  _databaseURL = [FTestHelpers databaseURL];

  // Disabled normally since they slow down the tests and don't actually assert anything (they just
  // NSLog timings).
  runPerfTests = NO;
}

- (void)snapWaiter:(FIRDatabaseReference *)path withBlock:(fbt_void_datasnapshot)fn {
  __block BOOL done = NO;

  [path observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot *snap) {
                         fn(snap);
                         done = YES;
                       }];

  NSTimeInterval timeTaken = [self
      waitUntil:^BOOL {
        return done;
      }
        timeout:kFirebaseTestWaitUntilTimeout];

  NSLog(@"snapWaiter:withBlock: timeTaken:%f", timeTaken);

  XCTAssertTrue(done, @"Properly finished.");
}

- (void)waitUntilConnected:(FIRDatabaseReference *)ref {
  __block BOOL connected = NO;
  FIRDatabaseHandle handle =
      [[ref.root child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                                  withBlock:^(FIRDataSnapshot *snapshot) {
                                                    connected = [snapshot.value boolValue];
                                                  }];
  WAIT_FOR(connected);
  [ref.root removeObserverWithHandle:handle];
}

- (void)waitForRoundTrip:(FIRDatabaseReference *)ref {
  // HACK: Do a deep setPriority (which we expect to fail because there's no data there) to do a
  // no-op roundtrip.
  __block BOOL done = NO;
  [[ref.root child:@"ENTOHTNUHOE/ONTEHNUHTOE"]
              setPriority:@"blah"
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];
  WAIT_FOR(done);
}

- (void)waitForQueue:(FIRDatabaseReference *)ref {
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
                });
}

- (void)waitForEvents:(FIRDatabaseReference *)ref {
  [self waitForQueue:ref];
  __block BOOL done = NO;
  dispatch_async(dispatch_get_main_queue(), ^{
    done = YES;
  });
  WAIT_FOR(done);
}

- (void)waitForValueOf:(FIRDatabaseQuery *)ref toBe:(id)expected {
  __block id value;
  FIRDatabaseHandle handle = [ref observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           value = snapshot.value;
                                         }];

  @try {
    [self waitUntil:^BOOL {
      return [value isEqual:expected];
    }];
  } @catch (NSException *exception) {
    @throw [NSException exceptionWithName:@"DidNotGetValue"
                                   reason:@"Did not get expected value"
                                 userInfo:@{
                                   @"expected" : (!expected ? @"nil" : expected),
                                   @"actual" : (!value ? @"nil" : value)
                                 }];
  } @finally {
    [ref removeObserverWithHandle:handle];
  }
}

- (void)waitForExportValueOf:(FIRDatabaseQuery *)ref toBe:(id)expected {
  __block id value;
  FIRDatabaseHandle handle = [ref observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           value = snapshot.valueInExportFormat;
                                         }];

  @try {
    [self waitUntil:^BOOL {
      return [value isEqual:expected];
    }];
  } @catch (NSException *exception) {
    if ([exception.name isEqualToString:@"Timed out"]) {
      @throw [NSException exceptionWithName:@"DidNotGetValue"
                                     reason:@"Did not get expected value"
                                   userInfo:@{
                                     @"expected" : (!expected ? @"nil" : expected),
                                     @"actual" : (!value ? @"nil" : value)
                                   }];
    } else {
      @throw exception;
    }
  } @finally {
    [ref removeObserverWithHandle:handle];
  }
}

- (void)waitForCompletionOf:(FIRDatabaseReference *)ref setValue:(id)value {
  [self waitForCompletionOf:ref setValue:value andPriority:nil];
}

- (void)waitForCompletionOf:(FIRDatabaseReference *)ref
                   setValue:(id)value
                andPriority:(id)priority {
  __block BOOL done = NO;
  [ref setValue:value
              andPriority:priority
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  @try {
    WAIT_FOR(done);
  } @catch (NSException *exception) {
    @throw [NSException exceptionWithName:@"DidNotSetValue"
                                   reason:@"Did not complete setting value"
                                 userInfo:@{
                                   @"ref" : [ref description],
                                   @"done" : done ? @"true" : @"false",
                                   @"value" : (!value ? @"nil" : value),
                                   @"priority" : (!priority ? @"nil" : priority)
                                 }];
  }
}

- (void)waitForCompletionOf:(FIRDatabaseReference *)ref updateChildValues:(NSDictionary *)values {
  __block BOOL done = NO;
  [ref updateChildValues:values
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  @try {
    WAIT_FOR(done);
  } @catch (NSException *exception) {
    @throw [NSException
        exceptionWithName:@"DidNotUpdateChildValues"
                   reason:@"Could not finish updating child values"
                 userInfo:@{@"ref" : [ref description], @"values" : (!values ? @"nil" : values)}];
  }
}

@end
