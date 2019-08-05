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

#import "FView.h"
#import "FCacheNode.h"
#import "FCancelEvent.h"
#import "FEmptyNode.h"
#import "FEventGenerator.h"
#import "FEventRegistration.h"
#import "FIRDatabaseQuery.h"
#import "FIRDatabaseQuery_Private.h"
#import "FIndexedFilter.h"
#import "FIndexedNode.h"
#import "FNode.h"
#import "FOperation.h"
#import "FOperationSource.h"
#import "FPath.h"
#import "FQueryParams.h"
#import "FQuerySpec.h"
#import "FViewCache.h"
#import "FViewProcessor.h"
#import "FViewProcessorResult.h"
#import "FWriteTreeRef.h"

@interface FViewOperationResult ()

@property(nonatomic, strong, readwrite) NSArray *changes;
@property(nonatomic, strong, readwrite) NSArray *events;

@end

@implementation FViewOperationResult

- (id)initWithChanges:(NSArray *)changes events:(NSArray *)events {
    self = [super init];
    if (self != nil) {
        self->_changes = changes;
        self->_events = events;
    }
    return self;
}

@end

/**
 * A view represents a specific location and query that has 1 or more event
 * registrations.
 *
 * It does several things:
 * - Maintains the list of event registration for this location/query.
 * - Maintains a cache of the data visible for this location/query.
 * - Applies new operations (via applyOperation), updates the cache, and based
 * on the event registrations returns the set of events to be raised.
 */
@interface FView ()

@property(nonatomic, strong, readwrite) FQuerySpec *query;
@property(nonatomic, strong) FViewProcessor *processor;
@property(nonatomic, strong) FViewCache *viewCache;
@property(nonatomic, strong) NSMutableArray *eventRegistrations;
@property(nonatomic, strong) FEventGenerator *eventGenerator;

@end

@implementation FView
- (id)initWithQuery:(FQuerySpec *)query
    initialViewCache:(FViewCache *)initialViewCache {
    self = [super init];
    if (self) {
        self.query = query;

        FIndexedFilter *indexFilter =
            [[FIndexedFilter alloc] initWithIndex:query.index];
        id<FNodeFilter> filter = query.params.nodeFilter;
        self.processor = [[FViewProcessor alloc] initWithFilter:filter];
        FCacheNode *initialServerCache = initialViewCache.cachedServerSnap;
        FCacheNode *initialEventCache = initialViewCache.cachedEventSnap;

        // Don't filter server node with other filter than index, wait for
        // tagged listen
        FIndexedNode *emptyIndexedNode =
            [FIndexedNode indexedNodeWithNode:[FEmptyNode emptyNode]
                                        index:query.index];
        FIndexedNode *serverSnap =
            [indexFilter updateFullNode:emptyIndexedNode
                            withNewNode:initialServerCache.indexedNode
                            accumulator:nil];
        FIndexedNode *eventSnap =
            [filter updateFullNode:emptyIndexedNode
                       withNewNode:initialEventCache.indexedNode
                       accumulator:nil];
        FCacheNode *newServerCache = [[FCacheNode alloc]
            initWithIndexedNode:serverSnap
             isFullyInitialized:initialServerCache.isFullyInitialized
                     isFiltered:indexFilter.filtersNodes];
        FCacheNode *newEventCache = [[FCacheNode alloc]
            initWithIndexedNode:eventSnap
             isFullyInitialized:initialEventCache.isFullyInitialized
                     isFiltered:filter.filtersNodes];

        self.viewCache = [[FViewCache alloc] initWithEventCache:newEventCache
                                                    serverCache:newServerCache];

        self.eventRegistrations = [[NSMutableArray alloc] init];

        self.eventGenerator = [[FEventGenerator alloc] initWithQuery:query];
    }

    return self;
}

- (id<FNode>)serverCache {
    return self.viewCache.cachedServerSnap.node;
}

- (id<FNode>)eventCache {
    return self.viewCache.cachedEventSnap.node;
}

- (id<FNode>)completeServerCacheFor:(FPath *)path {
    id<FNode> cache = self.viewCache.completeServerSnap;
    if (cache) {
        // If this isn't a "loadsAllData" view, then cache isn't actually a
        // complete cache and we need to see if it contains the child we're
        // interested in.
        if ([self.query loadsAllData] ||
            (!path.isEmpty &&
             ![cache getImmediateChild:path.getFront].isEmpty)) {
            return [cache getChild:path];
        }
    }
    return nil;
}

- (BOOL)isEmpty {
    return self.eventRegistrations.count == 0;
}

- (void)addEventRegistration:(id<FEventRegistration>)eventRegistration {
    [self.eventRegistrations addObject:eventRegistration];
}

/**
 * @param eventRegistration If null, remove all callbacks.
 * @param cancelError If a cancelError is provided, appropriate cancel events
 * will be returned.
 * @return Cancel events, if cancelError was provided.
 */
- (NSArray *)removeEventRegistration:(id<FEventRegistration>)eventRegistration
                         cancelError:(NSError *)cancelError {
    NSMutableArray *cancelEvents = [[NSMutableArray alloc] init];
    if (cancelError != nil) {
        NSAssert(eventRegistration == nil,
                 @"A cancel should cancel all event registrations.");
        FPath *path = self.query.path;
        for (id<FEventRegistration> registration in self.eventRegistrations) {
            FCancelEvent *maybeEvent =
                [registration createCancelEventFromError:cancelError path:path];
            if (maybeEvent) {
                [cancelEvents addObject:maybeEvent];
            }
        }
    }

    if (eventRegistration) {
        NSUInteger i = 0;
        while (i < self.eventRegistrations.count) {
            id<FEventRegistration> existing = self.eventRegistrations[i];
            if ([existing matches:eventRegistration]) {
                [self.eventRegistrations removeObjectAtIndex:i];
            } else {
                i++;
            }
        }
    } else {
        [self.eventRegistrations removeAllObjects];
    }
    return cancelEvents;
}

/**
 * Applies the given Operation, updates our cache, and returns the appropriate
 * events and changes
 */
- (FViewOperationResult *)applyOperation:(id<FOperation>)operation
                             writesCache:(FWriteTreeRef *)writesCache
                             serverCache:(id<FNode>)optCompleteServerCache {
    if (operation.type == FOperationTypeMerge &&
        operation.source.queryParams != nil) {
        NSAssert(self.viewCache.completeServerSnap != nil,
                 @"We should always have a full cache before handling merges");
        NSAssert(self.viewCache.completeEventSnap != nil,
                 @"Missing event cache, even though we have a server cache");
    }
    FViewCache *oldViewCache = self.viewCache;
    FViewProcessorResult *result =
        [self.processor applyOperationOn:oldViewCache
                               operation:operation
                             writesCache:writesCache
                           completeCache:optCompleteServerCache];

    NSAssert(result.viewCache.cachedServerSnap.isFullyInitialized ||
                 !oldViewCache.cachedServerSnap.isFullyInitialized,
             @"Once a server snap is complete, it should never go back.");

    self.viewCache = result.viewCache;
    NSArray *events = [self
        generateEventsForChanges:result.changes
                      eventCache:result.viewCache.cachedEventSnap.indexedNode
                    registration:nil];
    return [[FViewOperationResult alloc] initWithChanges:result.changes
                                                  events:events];
}

- (NSArray *)initialEvents:(id<FEventRegistration>)registration {
    FCacheNode *eventSnap = self.viewCache.cachedEventSnap;
    NSMutableArray *initialChanges = [[NSMutableArray alloc] init];
    [eventSnap.indexedNode.node enumerateChildrenUsingBlock:^(
                                    NSString *key, id<FNode> node, BOOL *stop) {
      FIndexedNode *indexed = [FIndexedNode indexedNodeWithNode:node];
      FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildAdded
                                          indexedNode:indexed
                                             childKey:key];
      [initialChanges addObject:change];
    }];
    if (eventSnap.isFullyInitialized) {
        FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeValue
                                            indexedNode:eventSnap.indexedNode];
        [initialChanges addObject:change];
    }
    return [self generateEventsForChanges:initialChanges
                               eventCache:eventSnap.indexedNode
                             registration:registration];
}

- (NSArray *)generateEventsForChanges:(NSArray *)changes
                           eventCache:(FIndexedNode *)eventCache
                         registration:(id<FEventRegistration>)registration {
    NSArray *registrations;
    if (registration == nil) {
        registrations = [[NSArray alloc] initWithArray:self.eventRegistrations];
    } else {
        registrations = [[NSArray alloc] initWithObjects:registration, nil];
    }
    return [self.eventGenerator generateEventsForChanges:changes
                                              eventCache:eventCache
                                      eventRegistrations:registrations];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FView (%@)", self.query];
}
@end
