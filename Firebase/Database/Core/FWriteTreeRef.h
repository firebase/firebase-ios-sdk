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
@class FChildrenNode;
@class FPath;
@class FNamedNode;
@class FWriteRecord;
@class FWriteTree;
@protocol FIndex;
@class FCacheNode;

@interface FWriteTreeRef : NSObject

- (id) initWithPath:(FPath *)aPath writeTree:(FWriteTree *)tree;

- (id <FNode>) calculateCompleteEventCacheWithCompleteServerCache:(id <FNode>)completeServerCache;

- (FChildrenNode *) calculateCompleteEventChildrenWithCompleteServerChildren:(FChildrenNode *)completeServerChildren;

- (id<FNode>) calculateEventCacheAfterServerOverwriteWithChildPath:(FPath *)childPath
                                                 existingEventSnap:(id<FNode>)existingEventSnap
                                                existingServerSnap:(id<FNode>)existingServerSnap;

- (id<FNode>) shadowingWriteAtPath:(FPath *)path;

- (FNamedNode *) calculateNextNodeAfterPost:(FNamedNode *)post
                         completeServerData:(id<FNode>)completeServerData
                                    reverse:(BOOL)reverse
                                      index:(id<FIndex>)index;

- (id<FNode>) calculateCompleteChild:(NSString *)childKey cache:(FCacheNode *)existingServerCache;

- (FWriteTreeRef *) childWriteTreeRef:(NSString *)childKey;

@end
