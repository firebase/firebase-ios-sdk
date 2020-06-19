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

#import "FViewCache.h"
#import "FCacheNode.h"
#import "FEmptyNode.h"
#import "FNode.h"

@interface FViewCache ()
@property(nonatomic, strong, readwrite) FCacheNode *cachedEventSnap;
@property(nonatomic, strong, readwrite) FCacheNode *cachedServerSnap;
@end

@implementation FViewCache

- (id)initWithEventCache:(FCacheNode *)eventCache
             serverCache:(FCacheNode *)serverCache {
    self = [super init];
    if (self) {
        self.cachedEventSnap = eventCache;
        self.cachedServerSnap = serverCache;
    }
    return self;
}

- (FViewCache *)updateEventSnap:(FIndexedNode *)eventSnap
                     isComplete:(BOOL)complete
                     isFiltered:(BOOL)filtered {
    FCacheNode *updatedEventCache =
        [[FCacheNode alloc] initWithIndexedNode:eventSnap
                             isFullyInitialized:complete
                                     isFiltered:filtered];
    return [[FViewCache alloc] initWithEventCache:updatedEventCache
                                      serverCache:self.cachedServerSnap];
}

- (FViewCache *)updateServerSnap:(FIndexedNode *)serverSnap
                      isComplete:(BOOL)complete
                      isFiltered:(BOOL)filtered {
    FCacheNode *updatedServerCache =
        [[FCacheNode alloc] initWithIndexedNode:serverSnap
                             isFullyInitialized:complete
                                     isFiltered:filtered];
    return [[FViewCache alloc] initWithEventCache:self.cachedEventSnap
                                      serverCache:updatedServerCache];
}

- (id<FNode>)completeEventSnap {
    return (self.cachedEventSnap.isFullyInitialized) ? self.cachedEventSnap.node
                                                     : nil;
}

- (id<FNode>)completeServerSnap {
    return (self.cachedServerSnap.isFullyInitialized)
               ? self.cachedServerSnap.node
               : nil;
}

@end
