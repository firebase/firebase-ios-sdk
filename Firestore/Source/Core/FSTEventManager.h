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

#import "Firestore/Source/Core/FSTViewSnapshot.h"

#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTQuery;
@class FSTSyncEngine;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTListenOptions

@interface FSTListenOptions : NSObject

+ (instancetype)defaultOptions;

- (instancetype)initWithIncludeQueryMetadataChanges:(BOOL)includeQueryMetadataChanges
                     includeDocumentMetadataChanges:(BOOL)includeDocumentMetadataChanges
                              waitForSyncWhenOnline:(BOOL)waitForSyncWhenOnline
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, assign, readonly) BOOL includeQueryMetadataChanges;

@property(nonatomic, assign, readonly) BOOL includeDocumentMetadataChanges;

@property(nonatomic, assign, readonly) BOOL waitForSyncWhenOnline;

@end

#pragma mark - FSTQueryListener

/**
 * FSTQueryListener takes a series of internal view snapshots and determines when to raise
 * user-facing events.
 */
@interface FSTQueryListener : NSObject

- (instancetype)initWithQuery:(FSTQuery *)query
                      options:(FSTListenOptions *)options
          viewSnapshotHandler:(FSTViewSnapshotHandler)viewSnapshotHandler NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)queryDidChangeViewSnapshot:(FSTViewSnapshot *)snapshot;
- (void)queryDidError:(NSError *)error;
- (void)applyChangedOnlineState:(firebase::firestore::model::OnlineState)onlineState;

@property(nonatomic, strong, readonly) FSTQuery *query;

@end

#pragma mark - FSTEventManager

/**
 * EventManager is responsible for mapping queries to query event emitters. It handles "fan-out."
 * (Identical queries will re-use the same watch on the backend.)
 */
@interface FSTEventManager : NSObject

+ (instancetype)eventManagerWithSyncEngine:(FSTSyncEngine *)syncEngine;

- (instancetype)init __attribute__((unavailable("Use static constructor method.")));

- (firebase::firestore::model::TargetId)addListener:(FSTQueryListener *)listener;
- (void)removeListener:(FSTQueryListener *)listener;

- (void)applyChangedOnlineState:(firebase::firestore::model::OnlineState)onlineState;

@end

NS_ASSUME_NONNULL_END
