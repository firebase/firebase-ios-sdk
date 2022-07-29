/*
 * Copyright 2022 Google LLC
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

#import "FIRAggregateListenSource.h"
#import "FIRAggregateSource.h"
#import "FIRListenerRegistration.h"

@class FIRAggregateQuerySnapshot;
@class FIRQuery;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AggregateQuery)
@interface FIRAggregateQuery : NSObject
/** :nodoc: */
- (id)init NS_UNAVAILABLE;

@property(nonatomic, readonly) FIRQuery *query;

#pragma mark - Retrieving Data

- (void)aggregationWithSource:(FIRAggregateSource)source completion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))completion NS_SWIFT_NAME(aggregation(source:completion:));
- (void)aggregationWithCompletion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))completion NS_SWIFT_NAME(aggregation(completion:));
- (void)aggregationWithSource:(FIRAggregateSource)source completion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))completion NS_SWIFT_NAME(aggregation(source:completion:));

- (id<FIRListenerRegistration>)addSnapshotListener:
    (void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(_:));

- (id<FIRListenerRegistration>)addSnapshotListenerWithIncludeMetadataChanges:
    (BOOL)includeMetadataChanges
    listener:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(includeMetadataChanges:listener:));

- (id<FIRListenerRegistration>)addSnapshotListenerWithSource:
    (FIRAggregateListenSource)source
    listener:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(source:listener:));

- (id<FIRListenerRegistration>)addSnapshotListenerWithSource:
    (FIRAggregateListenSource)source
    includeMetadataChanges:(BOOL)includeMetadataChanges
    listener:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(source:includeMetadataChanges:listener:));

@end

NS_ASSUME_NONNULL_END
