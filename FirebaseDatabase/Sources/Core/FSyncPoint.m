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

#import "FirebaseDatabase/Sources/Core/FSyncPoint.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FWriteTreeRef.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperation.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperationSource.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Core/View/FCacheNode.h"
#import "FirebaseDatabase/Sources/Core/View/FDataEvent.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRegistration.h"
#import "FirebaseDatabase/Sources/Core/View/FView.h"
#import "FirebaseDatabase/Sources/Core/View/FViewCache.h"
#import "FirebaseDatabase/Sources/Persistence/FPersistenceManager.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseQuery.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleRemovedQueriesEvents.h"

/**
 * SyncPoint represents a single location in a SyncTree with 1 or more event
 * registrations, meaning we need to maintain 1 or more Views at this location
 * to cache server data and raise appropriate events for server changes and user
 * writes (set, transaction, update).
 *
 * It's responsible for:
 *  - Maintaining the set of 1 or more views necessary at this location (a
 * SyncPoint with 0 views should be removed).
 *  - Proxying user / server operations to the views as appropriate (i.e.
 * applyServerOverwrite, applyUserOverwrite, etc.)
 */
@interface FSyncPoint ()
/**
 * The Views being tracked at this location in the tree, stored as a map where
 * the key is a queryParams and the value is the View for that query.
 *
 * NOTE: This list will be quite small (usually 1, but perhaps 2 or 3; any more
 * is an odd use case).
 *
 * Maps NSString -> FView
 */
@property(nonatomic, strong) NSMutableDictionary *views;

@property(nonatomic, strong) FPersistenceManager *persistenceManager;
@end

@implementation FSyncPoint

- (id)initWithPersistenceManager:(FPersistenceManager *)persistence {
    self = [super init];
    if (self) {
        self.persistenceManager = persistence;
        self.views = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)isEmpty {
    return [self.views count] == 0;
}

- (NSArray *)applyOperation:(id<FOperation>)operation
                     toView:(FView *)view
                writesCache:(FWriteTreeRef *)writesCache
                serverCache:(id<FNode>)optCompleteServerCache {
    FViewOperationResult *result = [view applyOperation:operation
                                            writesCache:writesCache
                                            serverCache:optCompleteServerCache];
    if (!view.query.loadsAllData) {
        NSMutableSet *removed = [NSMutableSet set];
        NSMutableSet *added = [NSMutableSet set];
        [result.changes enumerateObjectsUsingBlock:^(
                            FChange *change, NSUInteger idx, BOOL *stop) {
          if (change.type == FIRDataEventTypeChildAdded) {
              [added addObject:change.childKey];
          } else if (change.type == FIRDataEventTypeChildRemoved) {
              [removed addObject:change.childKey];
          }
        }];
        if ([removed count] > 0 || [added count] > 0) {
            [self.persistenceManager
                updateTrackedQueryKeysWithAddedKeys:added
                                        removedKeys:removed
                                           forQuery:view.query];
        }
    }
    return result.events;
}

- (NSArray *)applyOperation:(id<FOperation>)operation
                writesCache:(FWriteTreeRef *)writesCache
                serverCache:(id<FNode>)optCompleteServerCache {
    FQueryParams *queryParams = operation.source.queryParams;
    if (queryParams != nil) {
        FView *view = [self.views objectForKey:queryParams];
        NSAssert(view != nil, @"SyncTree gave us an op for an invalid query.");
        return [self applyOperation:operation
                             toView:view
                        writesCache:writesCache
                        serverCache:optCompleteServerCache];
    } else {
        NSMutableArray *events = [[NSMutableArray alloc] init];
        [self.views enumerateKeysAndObjectsUsingBlock:^(
                        FQueryParams *key, FView *view, BOOL *stop) {
          NSArray *eventsForView = [self applyOperation:operation
                                                 toView:view
                                            writesCache:writesCache
                                            serverCache:optCompleteServerCache];
          [events addObjectsFromArray:eventsForView];
        }];
        return events;
    }
}

/**
 * Add an event callback for the specified query
 * Returns Array of FEvent events to raise.
 */
- (NSArray *)addEventRegistration:(id<FEventRegistration>)eventRegistration
       forNonExistingViewForQuery:(FQuerySpec *)query
                      writesCache:(FWriteTreeRef *)writesCache
                      serverCache:(FCacheNode *)serverCache {
    NSAssert(self.views[query.params] == nil, @"Found view for query: %@",
             query.params);
    // TODO: make writesCache take flag for complete server node
    id<FNode> eventCache = [writesCache
        calculateCompleteEventCacheWithCompleteServerCache:
            serverCache.isFullyInitialized ? serverCache.node : nil];
    BOOL eventCacheComplete;
    if (eventCache != nil) {
        eventCacheComplete = YES;
    } else {
        eventCache = [writesCache
            calculateCompleteEventChildrenWithCompleteServerChildren:serverCache
                                                                         .node];
        eventCacheComplete = NO;
    }

    FIndexedNode *indexed = [FIndexedNode indexedNodeWithNode:eventCache
                                                        index:query.index];
    FCacheNode *eventCacheNode =
        [[FCacheNode alloc] initWithIndexedNode:indexed
                             isFullyInitialized:eventCacheComplete
                                     isFiltered:NO];
    FViewCache *viewCache =
        [[FViewCache alloc] initWithEventCache:eventCacheNode
                                   serverCache:serverCache];
    FView *view = [[FView alloc] initWithQuery:query
                              initialViewCache:viewCache];
    // If this is a non-default query we need to tell persistence our current
    // view of the data
    if (!query.loadsAllData) {
        NSMutableSet *allKeys = [NSMutableSet set];
        [view.eventCache enumerateChildrenUsingBlock:^(
                             NSString *key, id<FNode> node, BOOL *stop) {
          [allKeys addObject:key];
        }];
        [self.persistenceManager setTrackedQueryKeys:allKeys forQuery:query];
    }
    self.views[query.params] = view;
    return [self addEventRegistration:eventRegistration
              forExistingViewForQuery:query];
}

- (NSArray *)addEventRegistration:(id<FEventRegistration>)eventRegistration
          forExistingViewForQuery:(FQuerySpec *)query {
    FView *view = self.views[query.params];
    NSAssert(view != nil, @"No view for query: %@", query);
    [view addEventRegistration:eventRegistration];
    return [view initialEvents:eventRegistration];
}

/**
 * Remove event callback(s). Return cancelEvents if a cancelError is specified.
 *
 * If query is the default query, we'll check all views for the specified
 * eventRegistration. If eventRegistration is nil, we'll remove all callbacks
 * for the specified view(s).
 *
 * @return FTupleRemovedQueriesEvents removed queries and any cancel events
 */
- (FTupleRemovedQueriesEvents *)removeEventRegistration:
                                    (id<FEventRegistration>)eventRegistration
                                               forQuery:(FQuerySpec *)query
                                            cancelError:(NSError *)cancelError {
    NSMutableArray *removedQueries = [[NSMutableArray alloc] init];
    __block NSMutableArray *cancelEvents = [[NSMutableArray alloc] init];
    BOOL hadCompleteView = [self hasCompleteView];
    if ([query isDefault]) {
        // When you do [ref removeObserverWithHandle:], we search all views for
        // the registration to remove.
        [self.views enumerateKeysAndObjectsUsingBlock:^(
                        FQueryParams *viewQueryParams, FView *view,
                        BOOL *stop) {
          [cancelEvents
              addObjectsFromArray:[view
                                      removeEventRegistration:eventRegistration
                                                  cancelError:cancelError]];
          if ([view isEmpty]) {
              [self.views removeObjectForKey:viewQueryParams];

              // We'll deal with complete views later
              if (![view.query loadsAllData]) {
                  [removedQueries addObject:view.query];
              }
          }
        }];
    } else {
        // remove the callback from the specific view
        FView *view = [self.views objectForKey:query.params];
        if (view != nil) {
            [cancelEvents addObjectsFromArray:
                              [view removeEventRegistration:eventRegistration
                                                cancelError:cancelError]];

            if ([view isEmpty]) {
                [self.views removeObjectForKey:query.params];

                // We'll deal with complete views later
                if (![view.query loadsAllData]) {
                    [removedQueries addObject:view.query];
                }
            }
        }
    }

    if (hadCompleteView && ![self hasCompleteView]) {
        // We removed our last complete view
        [removedQueries addObject:[FQuerySpec defaultQueryAtPath:query.path]];
    }

    return [[FTupleRemovedQueriesEvents alloc]
        initWithRemovedQueries:removedQueries
                  cancelEvents:cancelEvents];
}

- (NSArray *)queryViews {
    __block NSMutableArray *filteredViews = [[NSMutableArray alloc] init];

    [self.views enumerateKeysAndObjectsUsingBlock:^(FQueryParams *key,
                                                    FView *view, BOOL *stop) {
      if (![view.query loadsAllData]) {
          [filteredViews addObject:view];
      }
    }];

    return filteredViews;
}

- (id<FNode>)completeServerCacheAtPath:(FPath *)path {
    __block id<FNode> serverCache = nil;
    [self.views enumerateKeysAndObjectsUsingBlock:^(FQueryParams *key,
                                                    FView *view, BOOL *stop) {
      serverCache = [view completeServerCacheFor:path];
      *stop = (serverCache != nil);
    }];
    return serverCache;
}

- (FView *)viewForQuery:(FQuerySpec *)query {
    return [self.views objectForKey:query.params];
}

- (BOOL)viewExistsForQuery:(FQuerySpec *)query {
    return [self viewForQuery:query] != nil;
}

- (BOOL)hasCompleteView {
    return [self completeView] != nil;
}

- (FView *)completeView {
    __block FView *completeView = nil;

    [self.views enumerateKeysAndObjectsUsingBlock:^(FQueryParams *key,
                                                    FView *view, BOOL *stop) {
      if ([view.query loadsAllData]) {
          completeView = view;
          *stop = YES;
      }
    }];

    return completeView;
}

@end
