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

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ExprBridge)
@interface FIRExprBridge : NSObject
@end

NS_SWIFT_NAME(FieldBridge)
@interface FIRFieldBridge : FIRExprBridge
- (id)init:(NSString *)name;
@end

NS_SWIFT_NAME(ConstantBridge)
@interface FIRConstantBridge : FIRExprBridge
- (id)init:(NSNumber *)value;
@end

NS_SWIFT_NAME(FunctionExprBridge)
@interface FIRFunctionExprBridge : FIRExprBridge
- (id)initWithName:(NSString *)name Args:(NSArray<FIRExprBridge *> *)args;
@end

NS_SWIFT_NAME(StageBridge)
@interface FIRStageBridge : NSObject
@end

NS_SWIFT_NAME(CollectionSourceStageBridge)
@interface FIRCollectionSourceStageBridge : FIRStageBridge

- (id)initWithPath:(NSString *)path;

@end

NS_SWIFT_NAME(WhereStageBridge)
@interface FIRWhereStageBridge : FIRStageBridge

- (id)initWithExpr:(FIRExprBridge *)expr;

@end

NS_SWIFT_NAME(__PipelineSnapshotBridge)
@interface __FIRPipelineSnapshotBridge : NSObject

@property(nonatomic, strong, readonly) NSArray<__FIRPipelineSnapshotBridge *> *results;

@end

NS_SWIFT_NAME(__PipelineResultBridge)
@interface __FIRPipelineResultBridge : NSObject

@property(nonatomic, strong, readonly) FIRDocumentReference *reference;

@property(nonatomic, copy, readonly) NSString *documentID;

- (nullable NSDictionary<NSString *, id> *)data;

@end

NS_SWIFT_NAME(PipelineBridge)
@interface FIRPipelineBridge : NSObject

/** :nodoc: */
- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db;

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
