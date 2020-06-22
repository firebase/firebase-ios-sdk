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
@protocol FCompleteChildSource;
@class FChildChangeAccumulator;
@protocol FIndex;
@class FPath;

/**
 * FNodeFilter is used to update nodes and complete children of nodes while
 * applying queries on the fly and keeping track of any child changes. This
 * class does not track value changes as value changes depend on more than just
 * the node itself. Different kind of queries require different kind of
 * implementations of this interface.
 */
@protocol FNodeFilter <NSObject>

/**
 * Update a single complete child in the snap. If the child equals the old child
 * in the snap, this is a no-op. The method expects an indexed snap.
 */
- (FIndexedNode *)updateChildIn:(FIndexedNode *)oldSnap
                    forChildKey:(NSString *)childKey
                       newChild:(id<FNode>)newChildSnap
                   affectedPath:(FPath *)affectedPath
                     fromSource:(id<FCompleteChildSource>)source
                    accumulator:(FChildChangeAccumulator *)optChangeAccumulator;

/**
 * Update a node in full and output any resulting change from this complete
 * update.
 */
- (FIndexedNode *)updateFullNode:(FIndexedNode *)oldSnap
                     withNewNode:(FIndexedNode *)newSnap
                     accumulator:
                         (FChildChangeAccumulator *)optChangeAccumulator;

/**
 * Update the priority of the root node
 */
- (FIndexedNode *)updatePriority:(id<FNode>)priority
                         forNode:(FIndexedNode *)oldSnap;

/**
 * Returns true if children might be filtered due to query critiera
 */
- (BOOL)filtersNodes;

/**
 * Returns the index filter that this filter uses to get a NodeFilter that
 * doesn't filter any children.
 */
@property(nonatomic, strong, readonly) id<FNodeFilter> indexedFilter;

/**
 * Returns the index that this filter uses
 */
@property(nonatomic, strong, readonly) id<FIndex> index;

@end
