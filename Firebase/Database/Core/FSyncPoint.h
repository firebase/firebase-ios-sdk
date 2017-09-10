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

#import <Foundation/Foundation.h>

@protocol FOperation;
@class FWriteTreeRef;
@protocol FNode;
@protocol FEventRegistration;
@class FQuerySpec;
@class FChildrenNode;
@class FTupleRemovedQueriesEvents;
@class FView;
@class FPath;
@class FCacheNode;
@class FPersistenceManager;

@interface FSyncPoint : NSObject

- (id)initWithPersistenceManager:(FPersistenceManager *)persistence;

- (BOOL)isEmpty;

/**
 * Returns array of FEvent
 */
- (NSArray *)applyOperation:(id<FOperation>)operation
                writesCache:(FWriteTreeRef *)writesCache
                serverCache:(id<FNode>)optCompleteServerCache;

/**
 * Returns array of FEvent
 */
- (NSArray *)addEventRegistration:(id<FEventRegistration>)eventRegistration
       forNonExistingViewForQuery:(FQuerySpec *)query
                      writesCache:(FWriteTreeRef *)writesCache
                      serverCache:(FCacheNode *)serverCache;

- (NSArray *)addEventRegistration:(id<FEventRegistration>)eventRegistration
          forExistingViewForQuery:(FQuerySpec *)query;

- (FTupleRemovedQueriesEvents *)removeEventRegistration:
                                    (id<FEventRegistration>)eventRegistration
                                               forQuery:(FQuerySpec *)query
                                            cancelError:(NSError *)cancelError;
/**
 * Returns array of FViews
 */
- (NSArray *)queryViews;
- (id<FNode>)completeServerCacheAtPath:(FPath *)path;
- (FView *)viewForQuery:(FQuerySpec *)query;
- (BOOL)viewExistsForQuery:(FQuerySpec *)query;
- (BOOL)hasCompleteView;
- (FView *)completeView;

@end
