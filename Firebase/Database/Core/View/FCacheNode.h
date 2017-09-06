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

@protocol FNode;
@class FIndexedNode;
@class FPath;

/**
 * A cache node only stores complete children. Additionally it holds a flag
 * whether the node can be considered fully initialized in the sense that we
 * know at one point in time, this represented a valid state of the world, e.g.
 * initialized with data from the server, or a complete overwrite by the client.
 * It is not necessarily complete because it may have been from a tagged query.
 * The filtered flag also tracks whether a node potentially had children removed
 * due to a filter.
 */
@interface FCacheNode : NSObject

- (id)initWithIndexedNode:(FIndexedNode *)indexedNode
       isFullyInitialized:(BOOL)fullyInitialized
               isFiltered:(BOOL)filtered;

- (BOOL)isCompleteForPath:(FPath *)path;
- (BOOL)isCompleteForChild:(NSString *)childKey;

@property(nonatomic, readonly) BOOL isFullyInitialized;
@property(nonatomic, readonly) BOOL isFiltered;
@property(nonatomic, strong, readonly) FIndexedNode *indexedNode;
@property(nonatomic, strong, readonly) id<FNode> node;

@end
