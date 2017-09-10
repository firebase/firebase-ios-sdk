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
@class FPruneForest;
@class FPath;
@class FCompoundWrite;
@class FQuerySpec;
@class FTrackedQuery;

@protocol FStorageEngine <NSObject>

- (void)close;

- (void)saveUserOverwrite:(id<FNode>)node
                   atPath:(FPath *)path
                  writeId:(NSUInteger)writeId;
- (void)saveUserMerge:(FCompoundWrite *)merge
               atPath:(FPath *)path
              writeId:(NSUInteger)writeId;
- (void)removeUserWrite:(NSUInteger)writeId;
- (void)removeAllUserWrites;
- (NSArray *)userWrites;

- (id<FNode>)serverCacheAtPath:(FPath *)path;
- (id<FNode>)serverCacheForKeys:(NSSet *)keys atPath:(FPath *)path;
- (void)updateServerCache:(id<FNode>)node
                   atPath:(FPath *)path
                    merge:(BOOL)merge;
- (void)updateServerCacheWithMerge:(FCompoundWrite *)merge atPath:(FPath *)path;
- (NSUInteger)serverCacheEstimatedSizeInBytes;

- (void)pruneCache:(FPruneForest *)pruneForest atPath:(FPath *)path;

- (NSArray *)loadTrackedQueries;
- (void)removeTrackedQuery:(NSUInteger)queryId;
- (void)saveTrackedQuery:(FTrackedQuery *)query;

- (void)setTrackedQueryKeys:(NSSet *)keys forQueryId:(NSUInteger)queryId;
- (void)updateTrackedQueryKeysWithAddedKeys:(NSSet *)added
                                removedKeys:(NSSet *)removed
                                 forQueryId:(NSUInteger)queryId;
- (NSSet *)trackedQueryKeysForQuery:(NSUInteger)queryId;

@end
