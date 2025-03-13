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
#include "Firestore/core/src/api/pipeline.h"
#include "Firestore/core/src/api/stages.h"

@class FIRFilter;

namespace api = firebase::firestore::api;

NS_ASSUME_NONNULL_BEGIN

@interface FIRExprBridge (Internal)

- (std::shared_ptr<api::Expr>)cpp_expr;

@end

@interface FIRStageBridge (Internal)

- (std::shared_ptr<api::Stage>)cpp_stage;

@end

@interface __FIRPipelineSnapshotBridge (Internal)

- (id)initWithCppSnapshot:(api::PipelineSnapshot)snapshot;

@end

NS_ASSUME_NONNULL_END
