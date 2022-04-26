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

#import "FirebaseDatabase/Tests/Integration/FIRDatabaseGetTests.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"
#import "FirebaseDatabase/Tests/Helpers/FIRFakeApp.h"
#import "FirebaseDatabase/Tests/Helpers/FTestExpectations.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

@implementation FIRDatabaseGetTests

- (void)testGetDoesntTriggerExtraListens {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FIRDatabaseReference* root = [ref root];
  FIRDatabaseReference* list = [root child:@"list"];

  __block BOOL removeDone = NO;
  [root removeValueWithCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
    removeDone = YES;
  }];
  WAIT_FOR(removeDone);

  [self waitForCompletionOf:[list childByAutoId] setValue:@{@"name" : @"child1"}];
  [self waitForCompletionOf:[list childByAutoId] setValue:@{@"name" : @"child2"}];

  // The original report of this issue makes a listen call first, and then
  // performs a getData. However, in the testing environment, if the listen
  // is made first, it will round trip and cache results before get has a
  // chance to run, at which point it reads from cache.
  // https://github.com/firebase/firebase-ios-sdk/issues/8286
  __block BOOL getDone = NO;
  [[[list queryOrderedByChild:@"name"] queryEqualToValue:@"child2"]
      getDataWithCompletionBlock:^(NSError* error, FIRDataSnapshot* snapshot) {
        XCTAssertNil(error);
        XCTAssertEqual(snapshot.childrenCount, 1L);
        getDone = YES;
      }];
  __block NSInteger numListenEvents = 0L;
  FIRDatabaseHandle handle = [list observeEventType:FIRDataEventTypeValue
                                          withBlock:^(FIRDataSnapshot* snapshot) {
                                            XCTAssertEqual(snapshot.childrenCount, 2L);
                                            numListenEvents += 1;
                                          }];
  WAIT_FOR(getDone);
  [NSThread sleepForTimeInterval:1];
  XCTAssertEqual(numListenEvents, 1);
  [list removeObserverWithHandle:handle];
}

@end
