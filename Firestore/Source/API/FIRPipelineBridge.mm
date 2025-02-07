//
//  FIRExprBridge.m
//  FirebaseFirestoreInternal
//
//  Created by Hui Wu on 2/25/25.
//

#import "FIRPipelineBridge.h"

#include <memory>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRPipelineBridge+Internal.h"

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
using firebase::firestore::api::Eq;
using firebase::firestore::api::Expr;
using firebase::firestore::api::Field;
using firebase::firestore::api::Pipeline;
using firebase::firestore::api::Where;
using firebase::firestore::util::MakeCallback;
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

- (std::shared_ptr<api::Expr>)cpp_expr {
  return field;
}

@end

@implementation FIRConstantBridge {
  std::shared_ptr<Constant> constant;
}
- (id)init:(NSNumber *)value {
  self = [super init];
  if (self) {
    constant = std::make_shared<Constant>(value.doubleValue);
  }
  return self;
}

- (std::shared_ptr<api::Expr>)cpp_expr {
  return constant;
}

@end

@implementation FIREqFunctionBridge {
  std::shared_ptr<Eq> eq;
}
- (id)initWithLeft:(FIRExprBridge *)left right:(FIRExprBridge *)right {
  self = [super init];
  if (self) {
    eq = std::make_shared<Eq>(left.cpp_expr, right.cpp_expr);
  }
  return self;
}

- (std::shared_ptr<api::Expr>)cpp_expr {
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

- (std::shared_ptr<api::Stage>)cpp_stage {
  return collection_source;
}

@end

@implementation FIRWhereStageBridge {
  std::shared_ptr<Where> where;
}

- (id)initWithExpr:(FIRExprBridge *)expr {
  self = [super init];
  if (self) {
    where = std::make_shared<Where>(expr.cpp_expr);
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cpp_stage {
  return where;
}

@end

@implementation __FIRPipelineSnapshotBridge {
  absl::optional<api::PipelineSnapshot> pipeline;
}

- (id)initWithCppSnapshot:(api::PipelineSnapshot)snapshot {
  self = [super init];
  if (self) {
    pipeline = std::move(snapshot);
  }

  return self;
}

@end

@implementation FIRPipelineBridge {
  std::shared_ptr<Pipeline> pipeline;
}

- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db {
  self = [super init];
  if (self) {
    std::vector<std::shared_ptr<firebase::firestore::api::Stage>> cpp_stages;
    for (FIRStageBridge *stage in stages) {
      cpp_stages.push_back(stage.cpp_stage);
    }
    pipeline = std::make_shared<Pipeline>(cpp_stages, db.wrapped);
  }
  return self;
}

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion {
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
