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

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRPipelineBridge+Internal.h"
#import "Firestore/Source/API/FSTUserDataReader.h"
#import "Firestore/Source/API/FSTUserDataWriter.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"

#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/pipeline.h"
#include "Firestore/core/src/api/pipeline_result.h"
#include "Firestore/core/src/api/pipeline_snapshot.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_apple.h"

using firebase::firestore::api::CollectionSource;
using firebase::firestore::api::Constant;
using firebase::firestore::api::DocumentReference;
using firebase::firestore::api::Expr;
using firebase::firestore::api::Field;
using firebase::firestore::api::FunctionExpr;
using firebase::firestore::api::Pipeline;
using firebase::firestore::api::Where;
using firebase::firestore::util::MakeCallback;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;

NS_ASSUME_NONNULL_BEGIN

@implementation FIRExprBridge
@end

@implementation FIRFieldBridge {
  std::shared_ptr<Field> field;
}

- (id)init:(NSString *)name {
  self = [super init];
  if (self) {
    field = std::make_shared<Field>(MakeString(name));
  }
  return self;
}

- (std::shared_ptr<api::Expr>)cppExprWithReader:(FSTUserDataReader *)reader {
  return field;
}

@end

@implementation FIRConstantBridge {
  std::shared_ptr<Constant> constant;
  id _input;
  Boolean isUserDataRead;
}
- (id)init:(id)input {
  self = [super init];
  _input = input;
  isUserDataRead = NO;
  return self;
}

- (std::shared_ptr<api::Expr>)cppExprWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    constant = std::make_shared<Constant>([reader parsedQueryValue:_input]);
  }

  isUserDataRead = YES;
  return constant;
}

@end

@implementation FIRFunctionExprBridge {
  std::shared_ptr<FunctionExpr> eq;
  NSString *_name;
  NSArray<FIRExprBridge *> *_args;
  Boolean isUserDataRead;
}

- (nonnull id)initWithName:(NSString *)name Args:(nonnull NSArray<FIRExprBridge *> *)args {
  self = [super init];
  _name = name;
  _args = args;
  isUserDataRead = NO;
  return self;
}

- (std::shared_ptr<api::Expr>)cppExprWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<std::shared_ptr<Expr>> cpp_args;
    for (FIRExprBridge *arg in _args) {
      cpp_args.push_back([arg cppExprWithReader:reader]);
    }
    eq = std::make_shared<FunctionExpr>(MakeString(_name), std::move(cpp_args));
  }

  isUserDataRead = YES;
  return eq;
}

@end

@implementation FIRStageBridge
@end

@implementation FIRCollectionSourceStageBridge {
  std::shared_ptr<CollectionSource> collection_source;
}

- (id)initWithPath:(NSString *)path {
  self = [super init];
  if (self) {
    collection_source = std::make_shared<CollectionSource>(MakeString(path));
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  return collection_source;
}

@end

@implementation FIRWhereStageBridge {
  FIRExprBridge *_exprBridge;
  Boolean isUserDataRead;
  std::shared_ptr<Where> where;
}

- (id)initWithExpr:(FIRExprBridge *)expr {
  self = [super init];
  if (self) {
    _exprBridge = expr;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    where = std::make_shared<Where>([_exprBridge cppExprWithReader:reader]);
  }

  isUserDataRead = YES;
  return where;
}

@end

@interface __FIRPipelineSnapshotBridge ()

@property(nonatomic, strong, readwrite) NSArray<__FIRPipelineSnapshotBridge *> *results;

@end

@implementation __FIRPipelineSnapshotBridge {
  absl::optional<api::PipelineSnapshot> snapshot_;
  NSMutableArray<__FIRPipelineResultBridge *> *results_;
}

- (id)initWithCppSnapshot:(api::PipelineSnapshot)snapshot {
  self = [super init];
  if (self) {
    snapshot_ = std::move(snapshot);
    if (!snapshot_.has_value()) {
      results_ = nil;
    } else {
      NSMutableArray<__FIRPipelineResultBridge *> *results = [NSMutableArray array];
      for (auto &result : snapshot_.value().results()) {
        [results addObject:[[__FIRPipelineResultBridge alloc]
                               initWithCppResult:result
                                              db:snapshot_.value().firestore()]];
      }
      results_ = results;
    }
  }

  return self;
}

- (NSArray<__FIRPipelineResultBridge *> *)results {
  return results_;
}

@end

@implementation __FIRPipelineResultBridge {
  api::PipelineResult _result;
  std::shared_ptr<api::Firestore> _db;
}

- (FIRDocumentReference *)reference {
  if (!_result.internal_key().has_value()) return nil;

  return [[FIRDocumentReference alloc] initWithKey:_result.internal_key().value() firestore:_db];
}

- (NSString *)documentID {
  if (!_result.document_id().has_value()) {
    return nil;
  }

  return MakeNSString(_result.document_id().value());
}

- (id)initWithCppResult:(api::PipelineResult)result db:(std::shared_ptr<api::Firestore>)db {
  self = [super init];
  if (self) {
    _result = std::move(result);
    _db = std::move(db);
  }

  return self;
}

- (nullable NSDictionary<NSString *, id> *)data {
  return [self dataWithServerTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (nullable NSDictionary<NSString *, id> *)dataWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior {
  absl::optional<firebase::firestore::google_firestore_v1_Value> data =
      _result.internal_value()->Get();
  if (!data) return nil;

  FSTUserDataWriter *dataWriter =
      [[FSTUserDataWriter alloc] initWithFirestore:_db
                           serverTimestampBehavior:serverTimestampBehavior];
  return [dataWriter convertedValue:*data];
}

@end

@implementation FIRPipelineBridge {
  NSArray<FIRStageBridge *> *_stages;
  FIRFirestore *firestore;
  std::shared_ptr<Pipeline> pipeline;
}

- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db {
  _stages = stages;
  firestore = db;
  return [super init];
}

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion {
  std::vector<std::shared_ptr<firebase::firestore::api::Stage>> cpp_stages;
  for (FIRStageBridge *stage in _stages) {
    cpp_stages.push_back([stage cppStageWithReader:firestore.dataReader]);
  }
  pipeline = std::make_shared<Pipeline>(cpp_stages, firestore.wrapped);

  pipeline->execute([completion](StatusOr<api::PipelineSnapshot> maybe_value) {
    if (maybe_value.ok()) {
      __FIRPipelineSnapshotBridge *bridge = [[__FIRPipelineSnapshotBridge alloc]
          initWithCppSnapshot:std::move(maybe_value).ValueOrDie()];
      completion(bridge, nil);
    } else {
      completion(nil, MakeNSError(std::move(maybe_value).status()));
    }
  });
}

@end

NS_ASSUME_NONNULL_END
