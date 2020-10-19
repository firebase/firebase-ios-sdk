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

#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"

#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"

#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleBoolBlock.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"
#import "FirebaseDatabase/Tests/Helpers/SenTest+FWaiter.h"

@implementation FEventTester

@synthesize lookingFor;
@synthesize callbacksCalled;
@synthesize from;
@synthesize errors;
@synthesize seenFirebaseLocations;
@synthesize initializationEvents;
@synthesize actualPathsAndEvents;

- (id)initFrom:(XCTestCase*)elsewhere {
  self = [super init];
  if (self) {
    self.seenFirebaseLocations = [[NSMutableDictionary alloc] init];
    self.initializationEvents = 0;
    self.lookingFor = [[NSMutableArray alloc] init];
    self.actualPathsAndEvents = [[NSMutableArray alloc] init];
    self.from = elsewhere;
    self.callbacksCalled = 0;
  }
  return self;
}

- (void)addLookingFor:(NSArray*)l {
  // expect them in the order they're given to us
  [self.lookingFor addObjectsFromArray:l];

  // see notes on ordering of listens in init.spec.js
  NSArray* toListen = [l sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    FTupleEventTypeString* a = obj1;
    FTupleEventTypeString* b = obj2;
    NSUInteger lenA = [a.firebase description].length;
    NSUInteger lenB = [b.firebase description].length;
    if (lenA < lenB) {
      return NSOrderedAscending;
    } else if (lenA == lenB) {
      return NSOrderedSame;
    } else {
      return NSOrderedDescending;
    }
  }];

  for (FTupleEventTypeString* fevts in toListen) {
    if (![self.seenFirebaseLocations objectForKey:[fevts.firebase description]]) {
      fevts.vvcallback = [self listenOnPath:fevts.firebase];
      fevts.initialized = NO;
      [self.seenFirebaseLocations setObject:fevts forKey:[fevts.firebase description]];
    }
  }
}

- (void)unregister {
  for (FTupleEventTypeString* fevts in self.lookingFor) {
    if (fevts.vvcallback) {
      fevts.vvcallback();
    }
  }
  [self.lookingFor removeAllObjects];
}

- (fbt_void_void)listenOnPath:(FIRDatabaseReference*)path {
  FIRDatabaseHandle removedHandle =
      [path observeEventType:FIRDataEventTypeChildRemoved
                   withBlock:[self makeEventCallback:FIRDataEventTypeChildRemoved]];
  FIRDatabaseHandle addedHandle =
      [path observeEventType:FIRDataEventTypeChildAdded
                   withBlock:[self makeEventCallback:FIRDataEventTypeChildAdded]];
  FIRDatabaseHandle movedHandle =
      [path observeEventType:FIRDataEventTypeChildMoved
                   withBlock:[self makeEventCallback:FIRDataEventTypeChildMoved]];
  FIRDatabaseHandle changedHandle =
      [path observeEventType:FIRDataEventTypeChildChanged
                   withBlock:[self makeEventCallback:FIRDataEventTypeChildChanged]];
  FIRDatabaseHandle valueHandle =
      [path observeEventType:FIRDataEventTypeValue
                   withBlock:[self makeEventCallback:FIRDataEventTypeValue]];

  fbt_void_void cb = ^() {
    [path removeObserverWithHandle:removedHandle];
    [path removeObserverWithHandle:addedHandle];
    [path removeObserverWithHandle:movedHandle];
    [path removeObserverWithHandle:changedHandle];
    [path removeObserverWithHandle:valueHandle];
  };
  return [cb copy];
}

- (void)wait {
  [self
      waitUntil:^BOOL {
        return self.actualPathsAndEvents.count >= self.lookingFor.count;
      }
        timeout:kFirebaseTestTimeout];

  for (int i = 0; i < self.lookingFor.count; ++i) {
    FTupleEventTypeString* target = [self.lookingFor objectAtIndex:i];
    FTupleEventTypeString* recvd = [self.actualPathsAndEvents objectAtIndex:i];
    XCTAssertTrue([target isEqualTo:recvd], @"Expected %@ to match %@", target, recvd);
  }

  if (self.actualPathsAndEvents.count > self.lookingFor.count) {
    NSLog(@"Too many events: %@", self.actualPathsAndEvents);
    XCTFail(@"Received too many events");
  }
}

- (void)waitForInitialization {
  [self
      waitUntil:^BOOL {
        for (FTupleEventTypeString* evt in [self.seenFirebaseLocations allValues]) {
          if (!evt.initialized) {
            return NO;
          }
        }

        // splice out all of the initialization events
        NSRange theRange;
        theRange.location = 0;
        theRange.length = self.initializationEvents;
        [self.actualPathsAndEvents removeObjectsInRange:theRange];

        return YES;
      }
        timeout:kFirebaseTestTimeout];
}

- (fbt_void_datasnapshot)makeEventCallback:(FIRDataEventType)type {
  fbt_void_datasnapshot cb = ^(FIRDataSnapshot* snap) {
    FIRDatabaseReference* ref = snap.ref;
    NSString* name = nil;
    if (type != FIRDataEventTypeValue) {
      ref = ref.parent;
      name = snap.key;
    }

    FTupleEventTypeString* evt = [[FTupleEventTypeString alloc] initWithFirebase:ref
                                                                       withEvent:type
                                                                      withString:name];
    [self.actualPathsAndEvents addObject:evt];

    NSLog(@"Adding event: %@ (%@)", evt, [snap value]);

    FTupleEventTypeString* targetEvt = [self.seenFirebaseLocations objectForKey:[ref description]];
    if (targetEvt && !targetEvt.initialized) {
      self.initializationEvents++;
      if (type == FIRDataEventTypeValue) {
        targetEvt.initialized = YES;
      }
    }
  };
  return [cb copy];
}

- (void)failWithException:(NSException*)anException {
  // TODO: FIX
  @throw anException;
}

@end
