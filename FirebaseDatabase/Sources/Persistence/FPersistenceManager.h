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

#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Core/View/FCacheNode.h"
#import "FirebaseDatabase/Sources/Persistence/FCachePolicy.h"
#import "FirebaseDatabase/Sources/Persistence/FStorageEngine.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FPersistenceManager : NSObject

- (id)initWithStorageEngine:(id<FStorageEngine>)storageEngine
                cachePolicy:(id<FCachePolicy>)cachePolicy;
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

- (FCacheNode *)serverCacheForQuery:(FQuerySpec *)spec;
- (void)updateServerCacheWithNode:(id<FNode>)node forQuery:(FQuerySpec *)spec;
- (void)updateServerCacheWithMerge:(FCompoundWrite *)merge atPath:(FPath *)path;

- (void)applyUserWrite:(id<FNode>)write toServerCacheAtPath:(FPath *)path;
- (void)applyUserMerge:(FCompoundWrite *)merge
    toServerCacheAtPath:(FPath *)path;

- (void)setQueryComplete:(FQuerySpec *)spec;
- (void)setQueryActive:(FQuerySpec *)spec;
- (void)setQueryInactive:(FQuerySpec *)spec;

- (void)setTrackedQueryKeys:(NSSet *)keys forQuery:(FQuerySpec *)query;
- (void)updateTrackedQueryKeysWithAddedKeys:(NSSet *)added
                                removedKeys:(NSSet *)removed
                                   forQuery:(FQuerySpec *)query;

@end
