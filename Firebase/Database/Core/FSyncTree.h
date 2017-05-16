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

@class FListenProvider;
@protocol FNode;
@class FPath;
@protocol FEventRegistration;
@protocol FPersistedServerCache;
@class FQuerySpec;
@class FCompoundWrite;
@class FPersistenceManager;
@class FCompoundHash;
@protocol FClock;

@protocol FSyncTreeHash <NSObject>

- (NSString *)simpleHash;
- (FCompoundHash *)compoundHash;
- (BOOL)includeCompoundHash;

@end

@interface FSyncTree : NSObject

- (id) initWithListenProvider:(FListenProvider *)provider;
- (id) initWithPersistenceManager:(FPersistenceManager *)persistenceManager
                   listenProvider:(FListenProvider *)provider;

// These methods all return NSArray of FEvent
- (NSArray *) applyUserOverwriteAtPath:(FPath *)path newData:(id <FNode>)newData writeId:(NSInteger)writeId isVisible:(BOOL)visible;
- (NSArray *) applyUserMergeAtPath:(FPath *)path changedChildren:(FCompoundWrite *)changedChildren writeId:(NSInteger)writeId;
- (NSArray *) ackUserWriteWithWriteId:(NSInteger)writeId revert:(BOOL)revert persist:(BOOL)persist clock:(id<FClock>)clock;
- (NSArray *) applyServerOverwriteAtPath:(FPath *)path newData:(id<FNode>)newData;
- (NSArray *) applyServerMergeAtPath:(FPath *)path changedChildren:(FCompoundWrite *)changedChildren;
- (NSArray *) applyServerRangeMergeAtPath:(FPath *)path updates:(NSArray *)ranges;
- (NSArray *) applyTaggedQueryOverwriteAtPath:(FPath *)path newData:(id <FNode>)newData tagId:(NSNumber *)tagId;
- (NSArray *) applyTaggedQueryMergeAtPath:(FPath *)path changedChildren:(FCompoundWrite *)changedChildren tagId:(NSNumber *)tagId;
- (NSArray *) applyTaggedServerRangeMergeAtPath:(FPath *)path updates:(NSArray *)ranges tagId:(NSNumber *)tagId;
- (NSArray *) addEventRegistration:(id<FEventRegistration>)eventRegistration forQuery:(FQuerySpec *)query;
- (NSArray *) removeEventRegistration:(id <FEventRegistration>)eventRegistration forQuery:(FQuerySpec *)query cancelError:(NSError *)cancelError;
- (void)keepQuery:(FQuerySpec *)query synced:(BOOL)keepSynced;
- (NSArray *) removeAllWrites;

- (id<FNode>) calcCompleteEventCacheAtPath:(FPath *)path excludeWriteIds:(NSArray *)writeIdsToExclude;

@end
