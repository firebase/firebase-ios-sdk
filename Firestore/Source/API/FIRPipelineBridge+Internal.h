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

#import "FIRPipelineBridge.h"

#include <memory>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/pipeline.h"
#include "Firestore/core/src/api/pipeline_result_change.h"
#include "Firestore/core/src/api/stages.h"

@class FIRFilter;

namespace api = firebase::firestore::api;

NS_ASSUME_NONNULL_BEGIN

@interface FIRExprBridge (Internal)

- (std::shared_ptr<api::Expr>)cppExprWithReader:(FSTUserDataReader *)reader;

@end

@interface FIROrderingBridge (Internal)

- (api::Ordering)cppOrderingWithReader:(FSTUserDataReader *)reader;

@end

@interface FIRStageBridge (Internal)

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader;

@end

@interface FIRCollectionSourceStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::CollectionSource>)stage;
@end

@interface FIRDatabaseSourceStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::DatabaseSource>)stage;
@end

@interface FIRCollectionGroupSourceStageBridge (Internal)
- (id)initWithCppStage:
    (std::shared_ptr<const firebase::firestore::api::CollectionGroupSource>)stage;
@end

@interface FIRDocumentsSourceStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::DocumentsSource>)stage;
@end

@interface FIRWhereStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::Where>)stage;
@end

@interface FIRLimitStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::LimitStage>)stage;
@end

@interface FIROffsetStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::OffsetStage>)stage;
@end

@interface FIRSorStageBridge (Internal)
- (id)initWithCppStage:(std::shared_ptr<const firebase::firestore::api::SortStage>)stage;
@end

@interface __FIRPipelineSnapshotBridge (Internal)

- (id)initWithCppSnapshot:(api::PipelineSnapshot)snapshot;

@end

@interface __FIRPipelineResultBridge (Internal)

- (id)initWithCppResult:(api::PipelineResult)result db:(std::shared_ptr<api::Firestore>)db;

@end

@interface __FIRPipelineResultChangeBridge (Internal)

- (id)initWithCppChange:(api::PipelineResultChange)change db:(std::shared_ptr<api::Firestore>)db;

@end

@interface FIRPipelineBridge (Internal)

- (std::shared_ptr<api::Pipeline>)cppPipelineWithReader:(FSTUserDataReader *)reader;

@end

NS_ASSUME_NONNULL_END
