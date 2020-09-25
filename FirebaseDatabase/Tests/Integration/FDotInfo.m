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

#import "FirebaseDatabase/Tests/Integration/FDotInfo.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@implementation FDotInfo

- (void)testCanGetReferenceToInfoNodes {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  [ref.root child:@".info"];
  [ref.root child:@".info/foo"];
}

- (void)testCantWriteToInfo {
  FIRDatabaseReference *ref = [[FTestHelpers getRandomNode].root child:@".info"];
  XCTAssertThrows([ref setValue:@"hi"], @"Cannot write to path at /.info");
  XCTAssertThrows([ref setValue:@"hi" andPriority:@5], @"Cannot write to path at /.info");
  XCTAssertThrows([ref setPriority:@"hi"], @"Cannot write to path at /.info");
  XCTAssertThrows([ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
                    return [FIRTransactionResult successWithValue:currentData];
                  }],
                  @"Cannot write to path at /.info");
  XCTAssertThrows([ref removeValue], @"Cannot write to path at /.info");
  XCTAssertThrows([[ref child:@"test"] setValue:@"hi"], @"Cannot write to path at /.info");
}

- (void)testCanWatchInfoConnected {
  FIRDatabaseReference *rootRef = [FTestHelpers getRandomNode].root;
  __block BOOL done = NO;
  [[rootRef child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                             withBlock:^(FIRDataSnapshot *snapshot) {
                                               if ([[snapshot value] boolValue]) {
                                                 done = YES;
                                               }
                                             }];
  [self waitUntil:^{
    return done;
  }];
}

- (void)testInfoConnectedGoesToFalseOnDisconnect {
  FIRDatabaseConfig *cfg = [FTestHelpers configForName:@"test-config"];
  FIRDatabaseReference *rootRef = [[FTestHelpers databaseForConfig:cfg] reference];
  __block BOOL everConnected = NO;
  __block NSMutableString *connectedHistory = [[NSMutableString alloc] init];
  [[rootRef child:@".info/connected"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               if ([[snapshot value] boolValue]) {
                 everConnected = YES;
               }

               if (everConnected) {
                 [connectedHistory appendString:([[snapshot value] boolValue] ? @"YES," : @"NO,")];
               }
             }];
  [self waitUntil:^{
    return everConnected;
  }];

  [FRepoManager interrupt:cfg];
  [FRepoManager resume:cfg];

  [self waitUntil:^BOOL {
    return [connectedHistory isEqualToString:@"YES,NO,YES,"];
  }];

  [FRepoManager interrupt:cfg];
  [FRepoManager disposeRepos:cfg];
}

- (void)testInfoServerTimeOffset {
  FIRDatabaseConfig *cfg = [FTestHelpers configForName:@"test-config"];
  FIRDatabaseReference *ref = [[FTestHelpers databaseForConfig:cfg] reference];

  // make sure childByAutoId works
  [ref childByAutoId];

  NSMutableArray *offsets = [[NSMutableArray alloc] init];

  [[ref child:@".info/serverTimeOffset"] observeEventType:FIRDataEventTypeValue
                                                withBlock:^(FIRDataSnapshot *snapshot) {
                                                  NSLog(@"got value: %@", snapshot.value);
                                                  [offsets addObject:snapshot.value];
                                                }];

  WAIT_FOR(offsets.count == 1);

  XCTAssertTrue([[offsets objectAtIndex:0] isKindOfClass:[NSNumber class]],
                @"Second element should be a number, in milliseconds");

  // make sure childByAutoId still works
  [ref childByAutoId];

  [FRepoManager interrupt:cfg];
  [FRepoManager disposeRepos:cfg];
}

- (void)testManualConnectionManagement {
  FIRDatabaseConfig *cfg = [FTestHelpers configForName:@"test-config"];
  FIRDatabaseConfig *altCfg = [FTestHelpers configForName:@"alt-config"];

  FIRDatabaseReference *ref = [[FTestHelpers databaseForConfig:cfg] reference];
  FIRDatabaseReference *refAlt = [[FTestHelpers databaseForConfig:altCfg] reference];

  // Wait until we're connected to both Firebases
  __block BOOL ready = NO;
  [[ref child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           ready = [[snapshot value] boolValue];
                                         }];
  [self waitUntil:^{
    return ready;
  }];
  [[ref child:@".info/connected"] removeAllObservers];

  ready = NO;
  [[refAlt child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot *snapshot) {
                                              ready = [[snapshot value] boolValue];
                                            }];
  [self waitUntil:^{
    return ready;
  }];
  [[refAlt child:@".info/connected"] removeAllObservers];

  [FIRDatabaseReference goOffline];

  // Ensure we're disconnected from both Firebases
  ready = NO;

  [[ref child:@".info/connected"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       XCTAssertFalse([[snapshot value] boolValue],
                                      @".info/connected should be false");
                       ready = YES;
                     }];
  [self waitUntil:^{
    return ready;
  }];
  ready = NO;
  [[refAlt child:@".info/connected"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       XCTAssertFalse([[snapshot value] boolValue],
                                      @".info/connected should be false");
                       ready = YES;
                     }];
  [self waitUntil:^{
    return ready;
  }];

  // Ensure that we don't automatically reconnect upon new Firebase creation
  FIRDatabaseReference *refDup = [[refAlt database] reference];
  [[refDup child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot *snapshot) {
                                              if ([[snapshot value] boolValue]) {
                                                XCTFail(@".info/connected should remain false");
                                              }
                                            }];

  // Wait for 1.5 seconds to make sure connected remains false
  [NSThread sleepForTimeInterval:1.5];
  [[refDup child:@".info/connected"] removeAllObservers];

  [FIRDatabaseReference goOnline];

  // Ensure we're reconnected to both Firebases
  ready = NO;
  [[ref child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           ready = [[snapshot value] boolValue];
                                         }];
  [self waitUntil:^{
    return ready;
  }];
  [[ref child:@".info/connected"] removeAllObservers];

  ready = NO;
  [[refAlt child:@".info/connected"] observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot *snapshot) {
                                              ready = [[snapshot value] boolValue];
                                            }];
  [self waitUntil:^{
    return ready;
  }];
  [[refAlt child:@".info/connected"] removeAllObservers];
}
@end
