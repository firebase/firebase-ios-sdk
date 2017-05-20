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

@protocol FStorageEngine;
@protocol FClock;
@protocol FCachePolicy;
@class FQuerySpec;
@class FPath;
@class FTrackedQuery;
@class FPruneForest;

@interface FTrackedQueryManager : NSObject

- (id)initWithStorageEngine:(id<FStorageEngine>)storageEngine clock:(id<FClock>)clock;

- (FTrackedQuery *)findTrackedQuery:(FQuerySpec *)query;

- (BOOL)isQueryComplete:(FQuerySpec *)query;

- (void)removeTrackedQuery:(FQuerySpec *)query;
- (void)setQueryComplete:(FQuerySpec *)query;
- (void)setQueriesCompleteAtPath:(FPath *)path;
- (void)setQueryActive:(FQuerySpec *)query;
- (void)setQueryInactive:(FQuerySpec *)query;

- (BOOL)hasActiveDefaultQueryAtPath:(FPath *)path;
- (void)ensureCompleteTrackedQueryAtPath:(FPath *)path;

- (FPruneForest *)pruneOldQueries:(id<FCachePolicy>)cachePolicy;
- (NSUInteger)numberOfPrunableQueries;
- (NSSet *)knownCompleteChildrenAtPath:(FPath *)path;

// For testing
- (void)verifyCache;

@end
