/*
 * Copyright 2025 Google LLC
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

#import "FIRFirestore.h"

#import <Foundation/Foundation.h>

#import "FIRDocumentSnapshot.h"

@class FIRTimestamp;
@class FIRVectorValue;
@class FIRPipelineBridge;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ExprBridge)
@interface FIRExprBridge : NSObject
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(FieldBridge)
@interface FIRFieldBridge : FIRExprBridge
- (id)init:(NSString *)name;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ConstantBridge)
@interface FIRConstantBridge : FIRExprBridge
- (id)init:(id)input;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(FunctionExprBridge)
@interface FIRFunctionExprBridge : FIRExprBridge
- (id)initWithName:(NSString *)name Args:(NSArray<FIRExprBridge *> *)args;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(AggregateFunctionBridge)
@interface FIRAggregateFunctionBridge : NSObject
- (id)initWithName:(NSString *)name Args:(NSArray<FIRExprBridge *> *)args;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(OrderingBridge)
@interface FIROrderingBridge : NSObject
- (id)initWithExpr:(FIRExprBridge *)expr Direction:(NSString *)direction;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(StageBridge)
@interface FIRStageBridge : NSObject
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(CollectionSourceStageBridge)
@interface FIRCollectionSourceStageBridge : FIRStageBridge

- (id)initWithPath:(NSString *)path;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(DatabaseSourceStageBridge)
@interface FIRDatabaseSourceStageBridge : FIRStageBridge

- (id)init;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(CollectionGroupSourceStageBridge)
@interface FIRCollectionGroupSourceStageBridge : FIRStageBridge

- (id)initWithCollectionId:(NSString *)id;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(DocumentsSourceStageBridge)
@interface FIRDocumentsSourceStageBridge : FIRStageBridge

- (id)initWithDocuments:(NSArray<NSString *> *)documents;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(WhereStageBridge)
@interface FIRWhereStageBridge : FIRStageBridge

- (id)initWithExpr:(FIRExprBridge *)expr;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(LimitStageBridge)
@interface FIRLimitStageBridge : FIRStageBridge

- (id)initWithLimit:(NSInteger)value;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(OffsetStageBridge)
@interface FIROffsetStageBridge : FIRStageBridge

- (id)initWithOffset:(NSInteger)value;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(AddFieldsStageBridge)
@interface FIRAddFieldsStageBridge : FIRStageBridge
- (id)initWithFields:(NSDictionary<NSString *, FIRExprBridge *> *)fields;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(RemoveFieldsStageBridge)
@interface FIRRemoveFieldsStageBridge : FIRStageBridge
- (id)initWithFields:(NSArray<NSString *> *)fields;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(SelectStageBridge)
@interface FIRSelectStageBridge : FIRStageBridge
- (id)initWithSelections:(NSDictionary<NSString *, FIRExprBridge *> *)selections;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(DistinctStageBridge)
@interface FIRDistinctStageBridge : FIRStageBridge
- (id)initWithGroups:(NSDictionary<NSString *, FIRExprBridge *> *)groups;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(AggregateStageBridge)
@interface FIRAggregateStageBridge : FIRStageBridge
- (id)initWithAccumulators:(NSDictionary<NSString *, FIRAggregateFunctionBridge *> *)accumulators
                    groups:(NSDictionary<NSString *, FIRExprBridge *> *)groups;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(FindNearestStageBridge)
@interface FIRFindNearestStageBridge : FIRStageBridge
- (id)initWithField:(FIRFieldBridge *)field
        vectorValue:(FIRVectorValue *)vectorValue
    distanceMeasure:(NSString *)distanceMeasure
              limit:(NSNumber *_Nullable)limit
      distanceField:(NSString *_Nullable)distanceField;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(SortStageBridge)
@interface FIRSorStageBridge : FIRStageBridge
- (id)initWithOrderings:(NSArray<id> *)orderings;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ReplaceWithStageBridge)
@interface FIRReplaceWithStageBridge : FIRStageBridge
- (id)initWithExpr:(FIRExprBridge *)expr;
- (id)initWithFieldName:(NSString *)fieldName;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(SampleStageBridge)
@interface FIRSampleStageBridge : FIRStageBridge
- (id)initWithCount:(int64_t)count;
- (id)initWithPercentage:(double)percentage;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(UnionStageBridge)
@interface FIRUnionStageBridge : FIRStageBridge
- (id)initWithOther:(FIRPipelineBridge *)other;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(UnnestStageBridge)
@interface FIRUnnestStageBridge : FIRStageBridge
- (id)initWithField:(FIRExprBridge *)field indexField:(NSString *_Nullable)indexField;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(GenericStageBridge)
@interface FIRGenericStageBridge : FIRStageBridge
- (id)initWithName:(NSString *)name
            params:(NSArray<FIRExprBridge *> *)params
           options:(NSDictionary<NSString *, FIRExprBridge *> *_Nullable)options;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineResultBridge)
@interface __FIRPipelineResultBridge : NSObject

@property(nonatomic, strong, readonly, nullable) FIRDocumentReference *reference;

@property(nonatomic, copy, readonly, nullable) NSString *documentID;

@property(nonatomic, strong, readonly, nullable) FIRTimestamp *create_time;

@property(nonatomic, strong, readonly, nullable) FIRTimestamp *update_time;

- (NSDictionary<NSString *, id> *)data;

- (NSDictionary<NSString *, id> *)dataWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior;

- (nullable id)get:(id)field;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineSnapshotBridge)
@interface __FIRPipelineSnapshotBridge : NSObject

@property(nonatomic, strong, readonly) NSArray<__FIRPipelineResultBridge *> *results;

@property(nonatomic, strong, readonly) FIRTimestamp *execution_time;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(PipelineBridge)
@interface FIRPipelineBridge : NSObject

/** :nodoc: */
- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db;

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
