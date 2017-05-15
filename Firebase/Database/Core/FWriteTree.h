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

@class FPath;
@protocol FNode;
@class FCompoundWrite;
@class FWriteTreeRef;
@class FChildrenNode;
@class FNamedNode;
@class FWriteRecord;
@protocol FIndex;
@class FCacheNode;

@interface FWriteTree : NSObject

- (FWriteTreeRef *) childWritesForPath:(FPath *)path;
- (void) addOverwriteAtPath:(FPath *)path newData:(id<FNode>)newData writeId:(NSInteger)writeId isVisible:(BOOL)visible;
- (void) addMergeAtPath:(FPath *)path changedChildren:(FCompoundWrite *)changedChildren writeId:(NSInteger)writeId;
- (BOOL) removeWriteId:(NSInteger)writeId;
- (NSArray *) removeAllWrites;
- (FWriteRecord *)writeForId:(NSInteger)writeId;

- (id<FNode>) calculateCompleteEventCacheAtPath:(FPath *)treePath
                            completeServerCache:(id<FNode>)completeServerCache
                                excludeWriteIds:(NSArray *)writeIdsToExclude
                            includeHiddenWrites:(BOOL)includeHiddenWrites;

- (id<FNode>) calculateCompleteEventChildrenAtPath:(FPath *)treePath
                            completeServerChildren:(id<FNode>)completeServerChildren;

- (id<FNode>) calculateEventCacheAfterServerOverwriteAtPath:(FPath *)treePath
                                                  childPath:(FPath *)childPath
                                          existingEventSnap:(id<FNode>)existingEventSnap
                                         existingServerSnap:(id<FNode>)existingServerSnap;

- (id<FNode>) calculateCompleteChildAtPath:(FPath *)treePath
                                  childKey:(NSString *)childKey
                                     cache:(FCacheNode *)existingServerCache;

- (id<FNode>) shadowingWriteAtPath:(FPath *)path;

- (FNamedNode *) calculateNextNodeAfterPost:(FNamedNode *)post
                                     atPath:(FPath *)path
                         completeServerData:(id<FNode>)completeServerData
                                    reverse:(BOOL)reverse
                                      index:(id<FIndex>)index;

@end
