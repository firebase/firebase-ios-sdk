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

#import "FirebaseDatabase/Sources/FEventGenerator.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/View/FChange.h"
#import "FirebaseDatabase/Sources/Core/View/FDataEvent.h"
#import "FirebaseDatabase/Sources/Core/View/FEvent.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRegistration.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FEventGenerator ()
@property(nonatomic, strong) FQuerySpec *query;
@end

/**
 * An EventGenerator is used to convert "raw" changes (fb.core.view.Change) as
 * computed by the CacheDiffer into actual events (fb.core.view.Event) that can
 * be raised.  See generateEventsForChanges() for details.
 */
@implementation FEventGenerator

- (id)initWithQuery:(FQuerySpec *)query {
    self = [super init];
    if (self) {
        self.query = query;
    }
    return self;
}

/**
 * Given a set of raw changes (no moved events, and prevName not specified yet),
 * and a set of EventRegistrations that should be notified of these changes,
 * generate the actual events to be raised.
 *
 * Notes:
 * - child_moved events will be synthesized at this time for any child_changed
 * events that affect our index
 * - prevName will be calculated based on the index ordering
 *
 * @param changes NSArray of FChange, not necessarily in order.
 * @param registrations is NSArray of FEventRegistration.
 * @return NSArray of FEvent.
 */
- (NSArray *)generateEventsForChanges:(NSArray *)changes
                           eventCache:(FIndexedNode *)eventCache
                   eventRegistrations:(NSArray *)registrations {
    NSMutableArray *events = [[NSMutableArray alloc] init];

    // child_moved is index-specific, so check all our child_changed events to
    // see if we need to materialize child_moved events with this view's index
    NSMutableArray *moves = [[NSMutableArray alloc] init];
    for (FChange *change in changes) {
        if (change.type == FIRDataEventTypeChildChanged &&
            [self.query.index
                indexedValueChangedBetween:change.oldIndexedNode.node
                                       and:change.indexedNode.node]) {
            FChange *moveChange =
                [[FChange alloc] initWithType:FIRDataEventTypeChildMoved
                                  indexedNode:change.indexedNode
                                     childKey:change.childKey
                               oldIndexedNode:nil];
            [moves addObject:moveChange];
        }
    }

    [self generateEvents:events
                   forType:FIRDataEventTypeChildRemoved
                   changes:changes
                eventCache:eventCache
        eventRegistrations:registrations];
    [self generateEvents:events
                   forType:FIRDataEventTypeChildAdded
                   changes:changes
                eventCache:eventCache
        eventRegistrations:registrations];
    [self generateEvents:events
                   forType:FIRDataEventTypeChildMoved
                   changes:moves
                eventCache:eventCache
        eventRegistrations:registrations];
    [self generateEvents:events
                   forType:FIRDataEventTypeChildChanged
                   changes:changes
                eventCache:eventCache
        eventRegistrations:registrations];
    [self generateEvents:events
                   forType:FIRDataEventTypeValue
                   changes:changes
                eventCache:eventCache
        eventRegistrations:registrations];

    return events;
}

- (void)generateEvents:(NSMutableArray *)events
               forType:(FIRDataEventType)eventType
               changes:(NSArray *)changes
            eventCache:(FIndexedNode *)eventCache
    eventRegistrations:(NSArray *)registrations {
    NSMutableArray *filteredChanges = [[NSMutableArray alloc] init];
    for (FChange *change in changes) {
        if (change.type == eventType) {
            [filteredChanges addObject:change];
        }
    }

    id<FIndex> index = self.query.index;

    [filteredChanges
        sortUsingComparator:^NSComparisonResult(FChange *one, FChange *two) {
          if (one.childKey == nil || two.childKey == nil) {
              @throw [[NSException alloc]
                  initWithName:@"InternalInconsistencyError"
                        reason:@"Should only compare child_ events"
                      userInfo:nil];
          }
          return [index compareKey:one.childKey
                           andNode:one.indexedNode.node
                        toOtherKey:two.childKey
                           andNode:two.indexedNode.node];
        }];

    for (FChange *change in filteredChanges) {
        for (id<FEventRegistration> registration in registrations) {
            if ([registration responseTo:eventType]) {
                id<FEvent> event = [self generateEventForChange:change
                                                   registration:registration
                                                     eventCache:eventCache];
                [events addObject:event];
            }
        }
    }
}

- (id<FEvent>)generateEventForChange:(FChange *)change
                        registration:(id<FEventRegistration>)registration
                          eventCache:(FIndexedNode *)eventCache {
    FChange *materializedChange;
    if (change.type == FIRDataEventTypeValue ||
        change.type == FIRDataEventTypeChildRemoved) {
        materializedChange = change;
    } else {
        NSString *prevChildKey =
            [eventCache predecessorForChildKey:change.childKey
                                     childNode:change.indexedNode.node
                                         index:self.query.index];
        materializedChange = [change changeWithPrevKey:prevChildKey];
    }
    return [registration createEventFrom:materializedChange query:self.query];
}

@end
