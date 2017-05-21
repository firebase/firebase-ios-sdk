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

#import "FNode.h"
#import "FIndex.h"
#import "FNamedNode.h"

/**
 * Represents a node together with an index. The index and node are updated in unison. In the case where the index
 * does not affect the ordering (i.e. the ordering is identical to the key ordering) this class uses a fallback index
 * to save memory. Everything operating on the index must special case the fallback index.
 */
@interface FIndexedNode : NSObject

@property (nonatomic, strong, readonly) id<FNode> node;

+ (FIndexedNode *)indexedNodeWithNode:(id<FNode>)node;
+ (FIndexedNode *)indexedNodeWithNode:(id<FNode>)node index:(id<FIndex>)index;

- (BOOL)hasIndex:(id<FIndex>)index;
- (FIndexedNode *)updateChild:(NSString *)key withNewChild:(id<FNode>)newChildNode;
- (FIndexedNode *)updatePriority:(id<FNode>)priority;

- (FNamedNode *)firstChild;
- (FNamedNode *)lastChild;

- (NSString *)predecessorForChildKey:(NSString *)childKey childNode:(id<FNode>)childNode index:(id<FIndex>)index;

- (void)enumerateChildrenReverse:(BOOL)reverse usingBlock:(void (^)(NSString *key, id<FNode> node, BOOL *stop))block;

- (NSEnumerator *)childEnumerator;

@end
