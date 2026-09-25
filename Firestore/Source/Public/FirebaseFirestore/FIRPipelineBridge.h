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

#import "FIRDocumentChange.h"
#import "FIRDocumentSnapshot.h"
#import "FIRSnapshotListenOptions.h"

@class FIRTimestamp;
@class FIRVectorValue;
@class __FIRPipelineBridge;
@class FIRFieldPath;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__ExprBridge)
@interface __FIRExprBridge : NSObject
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__FieldBridge)
@interface __FIRFieldBridge : __FIRExprBridge
- (id)initWithName:(NSString *)name;
- (id)initWithPath:(FIRFieldPath *)path;
- (NSString *)field_name;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__VariableBridge)
@interface __FIRVariableBridge : __FIRExprBridge
- (id)initWithName:(NSString *)name;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__ConstantBridge)
@interface __FIRConstantBridge : __FIRExprBridge
- (id)init:(id)input;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__FunctionExprBridge)
@interface __FIRFunctionExprBridge : __FIRExprBridge
- (id)initWithName:(NSString *)name
              Args:(NSArray<__FIRExprBridge *> *)args
           Options:(NSDictionary<NSString *, __FIRExprBridge *> *_Nullable)options;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__OrderingBridge)
@interface __FIROrderingBridge : NSObject
- (id)initWithExpr:(__FIRExprBridge *)expr Direction:(NSString *)direction;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__WindowSpecBridge)
@interface __FIRWindowSpecBridge : NSObject
- (id)initWithGroups:(NSArray<__FIRExprBridge *> *)groups
                sort:(NSArray<__FIROrderingBridge *> *_Nullable)sort
           preceding:(id _Nullable)preceding
           following:(id _Nullable)following
                type:(NSString *_Nullable)type
                unit:(id _Nullable)unit;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__AggregateFunctionBridge)
@interface __FIRAggregateFunctionBridge : NSObject
- (id)initWithName:(NSString *)name Args:(NSArray<__FIRExprBridge *> *)args;
- (id)initWithName:(NSString *)name
              Args:(NSArray<__FIRExprBridge *> *)args
            Window:(__FIRWindowSpecBridge *_Nullable)window;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__StageBridge)
@interface __FIRStageBridge : NSObject
@property(nonatomic, readonly) NSString *name;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__CollectionSourceStageBridge)
@interface __FIRCollectionSourceStageBridge : __FIRStageBridge

- (id)initWithRef:(FIRCollectionReference *)ref
        firestore:(FIRFirestore *)db
       forceIndex:(NSString *_Nullable)force_index;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__SubcollectionSourceStageBridge)
@interface __FIRSubcollectionSourceStageBridge : __FIRStageBridge

- (id)initWithPath:(NSString *)path;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__DatabaseSourceStageBridge)
@interface __FIRDatabaseSourceStageBridge : __FIRStageBridge

- (id)init;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__CollectionGroupSourceStageBridge)
@interface __FIRCollectionGroupSourceStageBridge : __FIRStageBridge

- (id)initWithCollectionId:(NSString *)id forceIndex:(NSString *_Nullable)force_index;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__DocumentsSourceStageBridge)
@interface __FIRDocumentsSourceStageBridge : __FIRStageBridge

- (id)initWithDocuments:(NSArray<FIRDocumentReference *> *)documents firestore:(FIRFirestore *)db;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__WhereStageBridge)
@interface __FIRWhereStageBridge : __FIRStageBridge

- (id)initWithExpr:(__FIRExprBridge *)expr;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__LimitStageBridge)
@interface __FIRLimitStageBridge : __FIRStageBridge

- (id)initWithLimit:(NSInteger)value;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__OffsetStageBridge)
@interface __FIROffsetStageBridge : __FIRStageBridge

- (id)initWithOffset:(NSInteger)value;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__AddFieldsStageBridge)
@interface __FIRAddFieldsStageBridge : __FIRStageBridge
- (id)initWithFields:(NSDictionary<NSString *, __FIRExprBridge *> *)fields;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__AddWindowFieldsStageBridge)
@interface __FIRAddWindowFieldsStageBridge : __FIRStageBridge
- (id)initWithWindow:(__FIRWindowSpecBridge *)window
              fields:(NSDictionary<NSString *, __FIRAggregateFunctionBridge *> *)fields
             options:(NSDictionary<NSString *, __FIRExprBridge *> *_Nullable)options;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__RemoveFieldsStageBridge)
@interface __FIRRemoveFieldsStageBridge : __FIRStageBridge
- (id)initWithFields:(NSArray<NSString *> *)fields;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__SelectStageBridge)
@interface __FIRSelectStageBridge : __FIRStageBridge
- (id)initWithSelections:(NSDictionary<NSString *, __FIRExprBridge *> *)selections;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__DefineStageBridge)
@interface __FIRDefineStageBridge : __FIRStageBridge
- (id)initWithVariables:(NSDictionary<NSString *, __FIRExprBridge *> *)variables;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__DistinctStageBridge)
@interface __FIRDistinctStageBridge : __FIRStageBridge
- (id)initWithGroups:(NSDictionary<NSString *, __FIRExprBridge *> *)groups;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__AggregateStageBridge)
@interface __FIRAggregateStageBridge : __FIRStageBridge
- (id)initWithAccumulators:(NSDictionary<NSString *, __FIRAggregateFunctionBridge *> *)accumulators
                    groups:(NSDictionary<NSString *, __FIRExprBridge *> *)groups;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__FindNearestStageBridge)
@interface __FIRFindNearestStageBridge : __FIRStageBridge
- (id)initWithField:(__FIRFieldBridge *)field
        vectorValue:(FIRVectorValue *)vectorValue
    distanceMeasure:(NSString *)distanceMeasure
              limit:(NSNumber *_Nullable)limit
      distanceField:(__FIRExprBridge *_Nullable)distanceField;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__SearchStageBridge)
@interface __FIRSearchStageBridge : __FIRStageBridge
- (id)initWithOptions:(NSDictionary<NSString *, __FIRExprBridge *> *)options
            addFields:(NSDictionary<NSString *, __FIRExprBridge *> *)add_fields
               select:(NSDictionary<NSString *, __FIRExprBridge *> *)select
                 sort:(NSArray<__FIROrderingBridge *> *)sort;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__SortStageBridge)
@interface __FIRSortStageBridge : __FIRStageBridge
- (id)initWithOrderings:(NSArray<id> *)orderings;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__ReplaceWithStageBridge)
@interface __FIRReplaceWithStageBridge : __FIRStageBridge
- (id)initWithExpr:(__FIRExprBridge *)expr;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__SampleStageBridge)
@interface __FIRSampleStageBridge : __FIRStageBridge
- (id)initWithCount:(int64_t)count;
- (id)initWithPercentage:(double)percentage;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__UnionStageBridge)
@interface __FIRUnionStageBridge : __FIRStageBridge
- (id)initWithOther:(__FIRPipelineBridge *)other;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__UnnestStageBridge)
@interface __FIRUnnestStageBridge : __FIRStageBridge
- (id)initWithField:(__FIRExprBridge *)field
              alias:(__FIRExprBridge *)alias
         indexField:(__FIRExprBridge *_Nullable)index_field;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__RawStageBridge)
@interface __FIRRawStageBridge : __FIRStageBridge
- (id)initWithName:(NSString *)name
            params:(NSArray<id> *)params
           options:(NSDictionary<NSString *, __FIRExprBridge *> *_Nullable)options;
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

- (nullable id)get:(id)field
    serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineResultChangeBridge)
@interface __FIRPipelineResultChangeBridge : NSObject

/** The type of change that occurred (added, modified, or removed). */
@property(nonatomic, readonly) FIRDocumentChangeType type;

/** The document affected by this change. */
@property(nonatomic, strong, readonly) __FIRPipelineResultBridge *result;

@property(nonatomic, readonly) NSUInteger oldIndex;

@property(nonatomic, readonly) NSUInteger newIndex;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineSnapshotBridge)
@interface __FIRPipelineSnapshotBridge : NSObject

@property(nonatomic, strong, readonly) NSArray<__FIRPipelineResultBridge *> *results;

@property(nonatomic, strong, readonly) FIRTimestamp *execution_time;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineBridge)
@interface __FIRPipelineBridge : NSObject

/** :nodoc: */
- (id)initWithStages:(NSArray<__FIRStageBridge *> *)stages db:(FIRFirestore *)db;

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion;

+ (NSArray<__FIRStageBridge *> *)createStageBridgesFromQuery:(FIRQuery *)query;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineExprBridge)
@interface __FIRPipelineExprBridge : __FIRExprBridge
- (id)initWithStages:(NSArray<__FIRStageBridge *> *)stages;
@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__RealtimePipelineSnapshotBridge)
@interface __FIRRealtimePipelineSnapshotBridge : NSObject

@property(nonatomic, strong, readonly) NSArray<__FIRPipelineResultBridge *> *results;

@property(nonatomic, strong, readonly) NSArray<__FIRPipelineResultChangeBridge *> *changes;

@property(nonatomic, strong, readonly) FIRSnapshotMetadata *metadata;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__PipelineListenOptionsBridge)
@interface __FIRPipelineListenOptionsBridge : NSObject

@property(nonatomic, readonly) NSString *serverTimestampBehavior;
@property(nonatomic, readonly) BOOL includeMetadata;
@property(nonatomic, readonly) FIRListenSource source;
- (instancetype)initWithServerTimestampBehavior:(NSString *)serverTimestampBehavior
                                includeMetadata:(BOOL)includeMetadata
                                         source:(FIRListenSource)source NS_DESIGNATED_INITIALIZER;

/**
 * The default initializer is unavailable. Please use the designated initializer.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(__RealtimePipelineBridge)
@interface __FIRRealtimePipelineBridge : NSObject

/** :nodoc: */
- (id)initWithStages:(NSArray<__FIRStageBridge *> *)stages db:(FIRFirestore *)db;

- (id<FIRListenerRegistration>)
    addSnapshotListenerWithOptions:(__FIRPipelineListenOptionsBridge *)options
                          listener:
                              (void (^)(__FIRRealtimePipelineSnapshotBridge *_Nullable snapshot,
                                        NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(options:listener:));

@end

NS_ASSUME_NONNULL_END
