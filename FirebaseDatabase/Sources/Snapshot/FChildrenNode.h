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

#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FImmutableSortedDictionary.h"
#import <Foundation/Foundation.h>

@class FNamedNode;

@interface FChildrenNode : NSObject <FNode>

- (id)initWithChildren:(FImmutableSortedDictionary *)someChildren;
- (id)initWithPriority:(id<FNode>)aPriority
              children:(FImmutableSortedDictionary *)someChildren;

// FChildrenNode specific methods

- (void)enumerateChildrenAndPriorityUsingBlock:(void (^)(NSString *, id<FNode>,
                                                         BOOL *))block;

- (FNamedNode *)firstChild;
- (FNamedNode *)lastChild;

@property(nonatomic, strong) FImmutableSortedDictionary *children;
@property(nonatomic, strong) id<FNode> priorityNode;

@end
