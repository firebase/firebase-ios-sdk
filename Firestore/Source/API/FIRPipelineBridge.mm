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

#import <FirebaseCore/FIRTimestamp.h>

#include <memory>

#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/API/FIRPipelineBridge+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FSTUserDataReader.h"
#import "Firestore/Source/API/FSTUserDataWriter.h"
#import "Firestore/Source/API/converters.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRVectorValue.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"

#include "Firestore/core/src/api/aggregate_expressions.h"
#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/ordering.h"
#include "Firestore/core/src/api/pipeline.h"
#include "Firestore/core/src/api/pipeline_result.h"
#include "Firestore/core/src/api/pipeline_result_change.h"
#include "Firestore/core/src/api/pipeline_snapshot.h"
#include "Firestore/core/src/api/query_listener_registration.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/realtime_pipeline_snapshot.h"
#include "Firestore/core/src/api/snapshot_metadata.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/core/firestore_client.h"
#include "Firestore/core/src/core/listen_options.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_apple.h"

using firebase::firestore::api::AddFields;
using firebase::firestore::api::AggregateFunction;
using firebase::firestore::api::AggregateStage;
using firebase::firestore::api::CollectionGroupSource;
using firebase::firestore::api::CollectionSource;
using firebase::firestore::api::Constant;
using firebase::firestore::api::DatabaseSource;
using firebase::firestore::api::DistinctStage;
using firebase::firestore::api::DocumentChange;
using firebase::firestore::api::DocumentReference;
using firebase::firestore::api::DocumentsSource;
using firebase::firestore::api::Expr;
using firebase::firestore::api::Field;
using firebase::firestore::api::FindNearestStage;
using firebase::firestore::api::FunctionExpr;
using firebase::firestore::api::LimitStage;
using firebase::firestore::api::MakeFIRTimestamp;
using firebase::firestore::api::OffsetStage;
using firebase::firestore::api::Ordering;
using firebase::firestore::api::Pipeline;
using firebase::firestore::api::PipelineResultChange;
using firebase::firestore::api::QueryListenerRegistration;
using firebase::firestore::api::RawStage;
using firebase::firestore::api::RealtimePipeline;
using firebase::firestore::api::RealtimePipelineSnapshot;
using firebase::firestore::api::RemoveFieldsStage;
using firebase::firestore::api::ReplaceWith;
using firebase::firestore::api::Sample;
using firebase::firestore::api::SelectStage;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::api::SortStage;
using firebase::firestore::api::Union;
using firebase::firestore::api::Unnest;
using firebase::firestore::api::Where;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DeepClone;
using firebase::firestore::model::FieldPath;
using firebase::firestore::nanopb::MakeSharedMessage;
using firebase::firestore::nanopb::SharedMessage;
using firebase::firestore::util::ComparisonResult;
using firebase::firestore::util::MakeCallback;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::ThrowInvalidArgument;

NS_ASSUME_NONNULL_BEGIN

inline std::string EnsureLeadingSlash(const std::string &path) {
  if (!path.empty() && path[0] == '/') {
    return path;
  }
  return "/" + path;
}

@implementation FIRExprBridge
@end

@implementation FIRFieldBridge {
  FIRFieldPath *field_path;
  std::shared_ptr<Field> field;
}

- (id)initWithName:(NSString *)name {
  self = [super init];
  if (self) {
    field_path = [FIRFieldPath pathWithDotSeparatedString:name];
    field = std::make_shared<Field>([field_path internalValue].CanonicalString());
  }
  return self;
}

- (id)initWithPath:(FIRFieldPath *)path {
  self = [super init];
  if (self) {
    field_path = path;
    field = std::make_shared<Field>([field_path internalValue].CanonicalString());
  }
  return self;
}

- (std::shared_ptr<api::Expr>)cppExprWithReader:(FSTUserDataReader *)reader {
  return field;
}

- (NSString *)field_name {
  return MakeNSString([field_path internalValue].CanonicalString());
}

@end

@implementation FIRConstantBridge {
  std::shared_ptr<Constant> cpp_constant;
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
    cpp_constant = std::make_shared<Constant>([reader parsedQueryValue:_input]);
  }

  isUserDataRead = YES;
  return cpp_constant;
}

@end

@implementation FIRFunctionExprBridge {
  std::shared_ptr<FunctionExpr> cpp_function;
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
    cpp_function = std::make_shared<FunctionExpr>(MakeString(_name), std::move(cpp_args));
  }

  isUserDataRead = YES;
  return cpp_function;
}

@end

@implementation FIRAggregateFunctionBridge {
  std::shared_ptr<AggregateFunction> cpp_function;
  NSString *_name;
  NSArray<FIRExprBridge *> *_args;
  Boolean isUserDataRead;
}

- (nonnull id)initWithName:(NSString *)name Args:(nonnull NSArray<FIRExprBridge *> *)args {
  _name = name;
  _args = args;
  isUserDataRead = NO;
  return self;
}

- (std::shared_ptr<AggregateFunction>)cppExprWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<std::shared_ptr<Expr>> cpp_args;
    for (FIRExprBridge *arg in _args) {
      cpp_args.push_back([arg cppExprWithReader:reader]);
    }
    cpp_function = std::make_shared<AggregateFunction>(MakeString(_name), std::move(cpp_args));
  }

  isUserDataRead = YES;
  return cpp_function;
}

@end

@implementation FIROrderingBridge {
  std::unique_ptr<Ordering> cpp_ordering;
  NSString *_direction;
  FIRExprBridge *_expr;
  Boolean isUserDataRead;
}

- (nonnull id)initWithExpr:(FIRExprBridge *)expr Direction:(NSString *)direction {
  _expr = expr;
  _direction = direction;
  isUserDataRead = NO;
  return self;
}

- (Ordering)cppOrderingWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    cpp_ordering = std::make_unique<Ordering>(
        [_expr cppExprWithReader:reader], Ordering::DirectionFromString(MakeString(_direction)));
  }

  isUserDataRead = YES;
  return *cpp_ordering;
}

@end

@implementation FIRStageBridge
- (NSString *)name {
  [NSException raise:NSInternalInconsistencyException
              format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
  return nil;
}
@end

@implementation FIRCollectionSourceStageBridge {
  std::shared_ptr<CollectionSource> collection_source;
}

- (id)initWithRef:(FIRCollectionReference *)ref firestore:(FIRFirestore *)db {
  self = [super init];
  if (self) {
    if (ref.firestore.databaseID.CompareTo(db.databaseID) != ComparisonResult::Same) {
      ThrowInvalidArgument(
          "Invalid CollectionReference. The project ID (\"%s\") or the database (\"%s\") does not "
          "match "
          "the project ID (\"%s\") and database (\"%s\") of the target database of this Pipeline.",
          ref.firestore.databaseID.project_id(), ref.firestore.databaseID.database_id(),
          db.databaseID.project_id(), db.databaseID.project_id());
    }
    collection_source =
        std::make_shared<CollectionSource>(EnsureLeadingSlash(MakeString(ref.path)));
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  return collection_source;
}

- (id)initWithCppStage:(std::shared_ptr<const api::CollectionSource>)stage {
  self = [super init];
  if (self) {
    collection_source = std::const_pointer_cast<api::CollectionSource>(stage);
  }
  return self;
}

- (NSString *)name {
  return @"collection";
}
@end

@implementation FIRDatabaseSourceStageBridge {
  std::shared_ptr<DatabaseSource> cpp_database_source;
}

- (id)init {
  self = [super init];
  if (self) {
    cpp_database_source = std::make_shared<DatabaseSource>();
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  return cpp_database_source;
}

- (id)initWithCppStage:(std::shared_ptr<const api::DatabaseSource>)stage {
  self = [super init];
  if (self) {
    cpp_database_source = std::const_pointer_cast<api::DatabaseSource>(stage);
  }
  return self;
}

- (NSString *)name {
  return @"database";
}
@end

@implementation FIRCollectionGroupSourceStageBridge {
  std::shared_ptr<CollectionGroupSource> cpp_collection_group_source;
}

- (id)initWithCollectionId:(NSString *)id {
  self = [super init];
  if (self) {
    cpp_collection_group_source = std::make_shared<CollectionGroupSource>(MakeString(id));
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  return cpp_collection_group_source;
}

- (id)initWithCppStage:(std::shared_ptr<const api::CollectionGroupSource>)stage {
  self = [super init];
  if (self) {
    cpp_collection_group_source = std::const_pointer_cast<api::CollectionGroupSource>(stage);
  }
  return self;
}

- (NSString *)name {
  return @"collection_group";
}
@end

@implementation FIRDocumentsSourceStageBridge {
  std::shared_ptr<DocumentsSource> cpp_document_source;
}

- (id)initWithDocuments:(NSArray<FIRDocumentReference *> *)documents firestore:(FIRFirestore *)db {
  self = [super init];
  if (self) {
    std::vector<std::string> cpp_documents;
    for (FIRDocumentReference *doc in documents) {
      if (doc.firestore.databaseID.CompareTo(db.databaseID) != ComparisonResult::Same) {
        ThrowInvalidArgument("Invalid DocumentReference. The project ID (\"%s\") or the database "
                             "(\"%s\") does not match "
                             "the project ID (\"%s\") and database (\"%s\") of the target database "
                             "of this Pipeline.",
                             doc.firestore.databaseID.project_id(),
                             doc.firestore.databaseID.database_id(), db.databaseID.project_id(),
                             db.databaseID.project_id());
      }
      cpp_documents.push_back(EnsureLeadingSlash(MakeString(doc.path)));
    }
    cpp_document_source = std::make_shared<DocumentsSource>(std::move(cpp_documents));
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  return cpp_document_source;
}

- (id)initWithCppStage:(std::shared_ptr<const api::DocumentsSource>)stage {
  self = [super init];
  if (self) {
    cpp_document_source = std::const_pointer_cast<api::DocumentsSource>(stage);
  }
  return self;
}

- (NSString *)name {
  return @"documents";
}
@end

@implementation FIRWhereStageBridge {
  FIRExprBridge *_exprBridge;
  Boolean isUserDataRead;
  std::shared_ptr<Where> cpp_where;
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
    cpp_where = std::make_shared<Where>([_exprBridge cppExprWithReader:reader]);
  }

  isUserDataRead = YES;
  return cpp_where;
}

- (id)initWithCppStage:(std::shared_ptr<const api::Where>)stage {
  self = [super init];
  if (self) {
    cpp_where = std::const_pointer_cast<api::Where>(stage);
    isUserDataRead = YES;
  }
  return self;
}

- (NSString *)name {
  return @"where";
}
@end

@implementation FIRLimitStageBridge {
  Boolean isUserDataRead;
  std::shared_ptr<LimitStage> cpp_limit_stage;
  int32_t limit;
}

- (id)initWithLimit:(NSInteger)value {
  self = [super init];
  if (self) {
    isUserDataRead = NO;
    limit = static_cast<int32_t>(value);
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    cpp_limit_stage = std::make_shared<LimitStage>(limit);
  }

  isUserDataRead = YES;
  return cpp_limit_stage;
}

- (id)initWithCppStage:(std::shared_ptr<const api::LimitStage>)stage {
  self = [super init];
  if (self) {
    cpp_limit_stage = std::const_pointer_cast<api::LimitStage>(stage);
    isUserDataRead = YES;
  }
  return self;
}

- (NSString *)name {
  return @"limit";
}
@end

@implementation FIROffsetStageBridge {
  Boolean isUserDataRead;
  std::shared_ptr<OffsetStage> cpp_offset_stage;
  int32_t offset;
}

- (id)initWithOffset:(NSInteger)value {
  self = [super init];
  if (self) {
    isUserDataRead = NO;
    offset = static_cast<int32_t>(value);
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    cpp_offset_stage = std::make_shared<OffsetStage>(offset);
  }

  isUserDataRead = YES;
  return cpp_offset_stage;
}

- (id)initWithCppStage:(std::shared_ptr<const api::OffsetStage>)stage {
  self = [super init];
  if (self) {
    cpp_offset_stage = std::const_pointer_cast<api::OffsetStage>(stage);
    isUserDataRead = YES;
  }
  return self;
}

- (NSString *)name {
  return @"offset";
}
@end

// TBD

@implementation FIRAddFieldsStageBridge {
  NSDictionary<NSString *, FIRExprBridge *> *_fields;
  Boolean isUserDataRead;
  std::shared_ptr<AddFields> cpp_add_fields;
}

- (id)initWithFields:(NSDictionary<NSString *, FIRExprBridge *> *)fields {
  self = [super init];
  if (self) {
    _fields = fields;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::unordered_map<std::string, std::shared_ptr<Expr>> cpp_fields;
    for (NSString *key in _fields) {
      cpp_fields[MakeString(key)] = [_fields[key] cppExprWithReader:reader];
    }
    cpp_add_fields = std::make_shared<AddFields>(std::move(cpp_fields));
  }

  isUserDataRead = YES;
  return cpp_add_fields;
}

- (NSString *)name {
  return @"add_fields";
}
@end

@implementation FIRRemoveFieldsStageBridge {
  NSArray<NSString *> *_fields;
  Boolean isUserDataRead;
  std::shared_ptr<RemoveFieldsStage> cpp_remove_fields;
}

- (id)initWithFields:(NSArray<id> *)fields {
  self = [super init];
  if (self) {
    _fields = fields;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<Field> cpp_fields;
    for (id field in _fields) {
      cpp_fields.push_back(Field(MakeString(field)));
    }
    cpp_remove_fields = std::make_shared<RemoveFieldsStage>(std::move(cpp_fields));
  }

  isUserDataRead = YES;
  return cpp_remove_fields;
}

- (NSString *)name {
  return @"remove_fields";
}
@end

@implementation FIRSelectStageBridge {
  NSDictionary<NSString *, FIRExprBridge *> *_selections;
  Boolean isUserDataRead;
  std::shared_ptr<SelectStage> cpp_select;
}

- (id)initWithSelections:(NSDictionary<NSString *, FIRExprBridge *> *)selections {
  self = [super init];
  if (self) {
    _selections = selections;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::unordered_map<std::string, std::shared_ptr<Expr>> cpp_selections;
    for (NSString *key in _selections) {
      cpp_selections[MakeString(key)] = [_selections[key] cppExprWithReader:reader];
    }
    cpp_select = std::make_shared<SelectStage>(std::move(cpp_selections));
  }

  isUserDataRead = YES;
  return cpp_select;
}

- (NSString *)name {
  return @"select";
}
@end

@implementation FIRDistinctStageBridge {
  NSDictionary<NSString *, FIRExprBridge *> *_groups;
  Boolean isUserDataRead;
  std::shared_ptr<DistinctStage> cpp_distinct;
}

- (id)initWithGroups:(NSDictionary<NSString *, FIRExprBridge *> *)groups {
  self = [super init];
  if (self) {
    _groups = groups;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::unordered_map<std::string, std::shared_ptr<Expr>> cpp_groups;
    for (NSString *key in _groups) {
      cpp_groups[MakeString(key)] = [_groups[key] cppExprWithReader:reader];
    }
    cpp_distinct = std::make_shared<DistinctStage>(std::move(cpp_groups));
  }

  isUserDataRead = YES;
  return cpp_distinct;
}

- (NSString *)name {
  return @"distinct";
}
@end

@implementation FIRAggregateStageBridge {
  NSDictionary<NSString *, FIRAggregateFunctionBridge *> *_accumulators;
  NSDictionary<NSString *, FIRExprBridge *> *_groups;
  Boolean isUserDataRead;
  std::shared_ptr<AggregateStage> cpp_aggregate;
}

- (id)initWithAccumulators:(NSDictionary<NSString *, FIRAggregateFunctionBridge *> *)accumulators
                    groups:(NSDictionary<NSString *, FIRExprBridge *> *)groups {
  self = [super init];
  if (self) {
    _accumulators = accumulators;
    _groups = groups;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::unordered_map<std::string, std::shared_ptr<AggregateFunction>> cpp_accumulators;
    for (NSString *key in _accumulators) {
      cpp_accumulators[MakeString(key)] = [_accumulators[key] cppExprWithReader:reader];
    }

    std::unordered_map<std::string, std::shared_ptr<Expr>> cpp_groups;
    for (NSString *key in _groups) {
      cpp_groups[MakeString(key)] = [_groups[key] cppExprWithReader:reader];
    }
    cpp_aggregate =
        std::make_shared<AggregateStage>(std::move(cpp_accumulators), std::move(cpp_groups));
  }

  isUserDataRead = YES;
  return cpp_aggregate;
}

- (NSString *)name {
  return @"aggregate";
}
@end

@implementation FIRFindNearestStageBridge {
  FIRFieldBridge *_field;
  FIRVectorValue *_vectorValue;
  NSString *_distanceMeasure;
  NSNumber *_limit;
  FIRExprBridge *_Nullable _distanceField;
  Boolean isUserDataRead;
  std::shared_ptr<FindNearestStage> cpp_find_nearest;
}

- (id)initWithField:(FIRFieldBridge *)field
        vectorValue:(FIRVectorValue *)vectorValue
    distanceMeasure:(NSString *)distanceMeasure
              limit:(NSNumber *_Nullable)limit
      distanceField:(FIRExprBridge *_Nullable)distanceField {
  self = [super init];
  if (self) {
    _field = field;
    _vectorValue = vectorValue;
    _distanceMeasure = distanceMeasure;
    _limit = limit;
    _distanceField = distanceField;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::unordered_map<std::string, firebase::firestore::google_firestore_v1_Value> optional_value;
    if (_limit) {
      optional_value.emplace(std::make_pair(
          std::string("limit"), *DeepClone(*[reader parsedQueryValue:_limit]).release()));
    }

    if (_distanceField) {
      std::shared_ptr<Expr> cpp_distance_field = [_distanceField cppExprWithReader:reader];
      optional_value.emplace(
          std::make_pair(std::string("distance_field"), cpp_distance_field->to_proto()));
    }

    FindNearestStage::DistanceMeasure::Measure measure_enum;
    if ([_distanceMeasure isEqualToString:@"cosine"]) {
      measure_enum = FindNearestStage::DistanceMeasure::COSINE;
    } else if ([_distanceMeasure isEqualToString:@"dot_product"]) {
      measure_enum = FindNearestStage::DistanceMeasure::DOT_PRODUCT;
    } else {
      measure_enum = FindNearestStage::DistanceMeasure::EUCLIDEAN;
    }

    cpp_find_nearest = std::make_shared<FindNearestStage>(
        [_field cppExprWithReader:reader], [reader parsedQueryValue:_vectorValue],
        FindNearestStage::DistanceMeasure(measure_enum), optional_value);
  }

  isUserDataRead = YES;
  return cpp_find_nearest;
}

- (NSString *)name {
  return @"find_nearest";
}
@end

@implementation FIRSorStageBridge {
  NSArray<FIROrderingBridge *> *_orderings;
  Boolean isUserDataRead;
  std::shared_ptr<SortStage> cpp_sort;
}

- (id)initWithOrderings:(NSArray<id> *)orderings {
  self = [super init];
  if (self) {
    _orderings = orderings;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<Ordering> cpp_orderings;
    for (FIROrderingBridge *ordering in _orderings) {
      cpp_orderings.push_back([ordering cppOrderingWithReader:reader]);
    }
    cpp_sort = std::make_shared<SortStage>(std::move(cpp_orderings));
  }

  isUserDataRead = YES;
  return cpp_sort;
}

- (id)initWithCppStage:(std::shared_ptr<const api::SortStage>)stage {
  self = [super init];
  if (self) {
    cpp_sort = std::const_pointer_cast<api::SortStage>(stage);
    isUserDataRead = YES;
  }
  return self;
}

- (NSString *)name {
  return @"sort";
}
@end

@implementation FIRReplaceWithStageBridge {
  FIRExprBridge *_expr;
  Boolean isUserDataRead;
  std::shared_ptr<ReplaceWith> cpp_replace_with;
}

- (id)initWithExpr:(FIRExprBridge *)expr {
  self = [super init];
  if (self) {
    _expr = expr;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    cpp_replace_with = std::make_shared<ReplaceWith>([_expr cppExprWithReader:reader]);
  }

  isUserDataRead = YES;
  return cpp_replace_with;
}

- (NSString *)name {
  return @"replace_with";
}
@end

@implementation FIRSampleStageBridge {
  int64_t _count;
  double _percentage;
  Boolean isUserDataRead;
  NSString *type;
  std::shared_ptr<Sample> cpp_sample;
}

- (id)initWithCount:(int64_t)count {
  self = [super init];
  if (self) {
    _count = count;
    _percentage = 0;
    type = @"count";
    isUserDataRead = NO;
  }
  return self;
}

- (id)initWithPercentage:(double)percentage {
  self = [super init];
  if (self) {
    _percentage = percentage;
    _count = 0;
    type = @"percentage";
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    if ([type isEqualToString:@"count"]) {
      cpp_sample =
          std::make_shared<Sample>(Sample::SampleMode(Sample::SampleMode::DOCUMENTS), _count, 0);
    } else {
      cpp_sample =
          std::make_shared<Sample>(Sample::SampleMode(Sample::SampleMode::PERCENT), 0, _percentage);
    }
  }

  isUserDataRead = YES;
  return cpp_sample;
}

- (NSString *)name {
  return @"sample";
}
@end

@implementation FIRUnionStageBridge {
  FIRPipelineBridge *_other;
  Boolean isUserDataRead;
  std::shared_ptr<Union> cpp_union_stage;
}

- (id)initWithOther:(FIRPipelineBridge *)other {
  self = [super init];
  if (self) {
    _other = other;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    cpp_union_stage = std::make_shared<Union>([_other cppPipelineWithReader:reader]);
  }

  isUserDataRead = YES;
  return cpp_union_stage;
}

- (NSString *)name {
  return @"union";
}
@end

@implementation FIRUnnestStageBridge {
  FIRExprBridge *_field;
  FIRExprBridge *_Nullable _index_field;
  FIRExprBridge *_alias;
  Boolean isUserDataRead;
  std::shared_ptr<Unnest> cpp_unnest;
}

- (id)initWithField:(FIRExprBridge *)field
              alias:(FIRExprBridge *)alias
         indexField:(FIRExprBridge *_Nullable)index_field {
  self = [super init];
  if (self) {
    _field = field;
    _alias = alias;
    _index_field = index_field;
    isUserDataRead = NO;
  }
  return self;
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    absl::optional<std::shared_ptr<Expr>> cpp_index_field;
    if (_index_field != nil) {
      cpp_index_field = [_index_field cppExprWithReader:reader];
    } else {
      cpp_index_field = absl::nullopt;
    }
    cpp_unnest = std::make_shared<Unnest>([_field cppExprWithReader:reader],
                                          [_alias cppExprWithReader:reader], cpp_index_field);
  }

  isUserDataRead = YES;
  return cpp_unnest;
}

- (NSString *)name {
  return @"unnest";
}
@end

@implementation FIRRawStageBridge {
  NSString *_name;
  NSArray<id> *_params;
  NSDictionary<NSString *, FIRExprBridge *> *_Nullable _options;
  Boolean isUserDataRead;
  std::shared_ptr<RawStage> cpp_generic_stage;
}

- (id)initWithName:(NSString *)name
            params:(NSArray<id> *)params
           options:(NSDictionary<NSString *, FIRExprBridge *> *_Nullable)options {
  self = [super init];
  if (self) {
    _name = name;
    _params = params;
    _options = options;
    isUserDataRead = NO;
  }
  return self;
}

- (firebase::firestore::google_firestore_v1_Value)convertIdToV1Value:(id)value
                                                              reader:(FSTUserDataReader *)reader {
  if ([value isKindOfClass:[FIRExprBridge class]]) {
    return [((FIRExprBridge *)value) cppExprWithReader:reader]->to_proto();
  } else if ([value isKindOfClass:[FIRAggregateFunctionBridge class]]) {
    return [((FIRAggregateFunctionBridge *)value) cppExprWithReader:reader]->to_proto();
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    NSDictionary<NSString *, id> *dictionary = (NSDictionary<NSString *, id> *)value;

    std::unordered_map<std::string, firebase::firestore::google_firestore_v1_Value> cpp_dictionary;
    for (NSString *key in dictionary) {
      if ([dictionary[key] isKindOfClass:[FIRExprBridge class]]) {
        cpp_dictionary[MakeString(key)] =
            [((FIRExprBridge *)dictionary[key]) cppExprWithReader:reader]->to_proto();
      } else if ([dictionary[key] isKindOfClass:[FIRAggregateFunctionBridge class]]) {
        cpp_dictionary[MakeString(key)] =
            [((FIRAggregateFunctionBridge *)dictionary[key]) cppExprWithReader:reader]->to_proto();
      } else {
        ThrowInvalidArgument(
            "Dictionary value must be an FIRExprBridge or FIRAggregateFunctionBridge.");
      }
    }

    firebase::firestore::google_firestore_v1_Value result;
    result.which_value_type = google_firestore_v1_Value_map_value_tag;

    nanopb::SetRepeatedField(
        &result.map_value.fields, &result.map_value.fields_count, cpp_dictionary,
        [](const std::pair<std::string, firebase::firestore::google_firestore_v1_Value> &entry) {
          return firebase::firestore::_google_firestore_v1_MapValue_FieldsEntry{
              nanopb::MakeBytesArray(entry.first), entry.second};
        });
    return result;
  } else {
    ThrowInvalidArgument("Invalid value to convert to google_firestore_v1_Value.");
  }
}

- (std::shared_ptr<api::Stage>)cppStageWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<firebase::firestore::google_firestore_v1_Value> cpp_params;
    for (id param in _params) {
      cpp_params.push_back([self convertIdToV1Value:param reader:reader]);
    }

    std::unordered_map<std::string, std::shared_ptr<Expr>> cpp_options;
    if (_options) {
      for (NSString *key in _options) {
        cpp_options[MakeString(key)] = [_options[key] cppExprWithReader:reader];
      }
    }
    cpp_generic_stage = std::make_shared<RawStage>(MakeString(_name), std::move(cpp_params),
                                                   std::move(cpp_options));
  }

  isUserDataRead = YES;
  return cpp_generic_stage;
}

- (NSString *)name {
  return _name;
}
@end

@interface __FIRPipelineSnapshotBridge ()

@property(nonatomic, strong, readwrite) NSArray<__FIRPipelineResultBridge *> *results;

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

- (FIRTimestamp *)execution_time {
  if (!snapshot_.has_value()) {
    return nil;
  } else {
    return MakeFIRTimestamp(snapshot_.value().execution_time().timestamp());
  }
}

@end

@implementation __FIRPipelineResultBridge {
  api::PipelineResult _result;
  std::shared_ptr<api::Firestore> _db;
}

- (nullable FIRDocumentReference *)reference {
  if (!_result.internal_key().has_value()) return nil;

  return [[FIRDocumentReference alloc] initWithKey:_result.internal_key().value() firestore:_db];
}

- (nullable NSString *)documentID {
  if (!_result.document_id().has_value()) {
    return nil;
  }

  return MakeNSString(_result.document_id().value());
}

- (nullable FIRTimestamp *)create_time {
  if (!_result.create_time().has_value()) {
    return nil;
  }

  return MakeFIRTimestamp(_result.create_time().value().timestamp());
}

- (nullable FIRTimestamp *)update_time {
  if (!_result.update_time().has_value()) {
    return nil;
  }

  return MakeFIRTimestamp(_result.update_time().value().timestamp());
}

- (id)initWithCppResult:(api::PipelineResult)result db:(std::shared_ptr<api::Firestore>)db {
  self = [super init];
  if (self) {
    _result = std::move(result);
    _db = std::move(db);
  }

  return self;
}

- (NSDictionary<NSString *, id> *)data {
  return [self dataWithServerTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (NSDictionary<NSString *, id> *)dataWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior {
  absl::optional<firebase::firestore::google_firestore_v1_Value> data =
      _result.internal_value()->Get();
  if (!data) return [NSDictionary dictionary];

  FSTUserDataWriter *dataWriter =
      [[FSTUserDataWriter alloc] initWithFirestore:_db
                           serverTimestampBehavior:serverTimestampBehavior];
  NSDictionary<NSString *, id> *dictionary = [dataWriter convertedValue:*data];
  NSLog(@"Dictionary contents: %@", dictionary);
  return dictionary;
}

- (nullable id)get:(id)field {
  return [self get:field serverTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (nullable id)get:(id)field
    serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  FieldPath fieldPath;
  if ([field isKindOfClass:[NSString class]]) {
    fieldPath = FieldPath::FromDotSeparatedString(MakeString(field));
  } else if ([field isKindOfClass:[FIRFieldPath class]]) {
    fieldPath = ((FIRFieldPath *)field).internalValue;
  } else {
    ThrowInvalidArgument("Subscript key must be an NSString or FIRFieldPath.");
  }
  absl::optional<firebase::firestore::google_firestore_v1_Value> fieldValue =
      _result.internal_value()->Get(fieldPath);
  if (!fieldValue) return nil;
  FSTUserDataWriter *dataWriter =
      [[FSTUserDataWriter alloc] initWithFirestore:_db
                           serverTimestampBehavior:serverTimestampBehavior];
  return [dataWriter convertedValue:*fieldValue];
}

@end

@implementation __FIRPipelineResultChangeBridge {
  api::PipelineResultChange change_;
  std::shared_ptr<api::Firestore> db_;
}

- (FIRDocumentChangeType)type {
  switch (change_.type()) {
    case PipelineResultChange::Type::Added:
      return FIRDocumentChangeTypeAdded;
    case PipelineResultChange::Type::Modified:
      return FIRDocumentChangeTypeModified;
    case PipelineResultChange::Type::Removed:
      return FIRDocumentChangeTypeRemoved;
  }

  HARD_FAIL("Unknown PipelineResultChange::Type: %s", change_.type());
}

- (__FIRPipelineResultBridge *)result {
  return [[__FIRPipelineResultBridge alloc] initWithCppResult:change_.result() db:db_];
}

- (NSUInteger)oldIndex {
  return change_.old_index() == PipelineResultChange::npos ? NSNotFound : change_.old_index();
}

- (NSUInteger)newIndex {
  return change_.new_index() == PipelineResultChange::npos ? NSNotFound : change_.new_index();
}

- (id)initWithCppChange:(api::PipelineResultChange)change db:(std::shared_ptr<api::Firestore>)db {
  self = [super init];
  if (self) {
    change_ = std::move(change);
    db_ = std::move(db);
  }

  return self;
}

@end

@implementation FIRPipelineBridge {
  NSArray<FIRStageBridge *> *_stages;
  FIRFirestore *firestore;
  Boolean isUserDataRead;
  std::shared_ptr<Pipeline> cpp_pipeline;
}

- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db {
  _stages = stages;
  firestore = db;
  isUserDataRead = NO;
  return [super init];
}

- (void)executeWithCompletion:(void (^)(__FIRPipelineSnapshotBridge *_Nullable result,
                                        NSError *_Nullable error))completion {
  [self cppPipelineWithReader:firestore.dataReader]->execute(
      [completion](StatusOr<api::PipelineSnapshot> maybe_value) {
        if (maybe_value.ok()) {
          __FIRPipelineSnapshotBridge *bridge = [[__FIRPipelineSnapshotBridge alloc]
              initWithCppSnapshot:std::move(maybe_value).ValueOrDie()];
          completion(bridge, nil);
        } else {
          completion(nil, MakeNSError(std::move(maybe_value).status()));
        }
      });
}

- (std::shared_ptr<api::Pipeline>)cppPipelineWithReader:(FSTUserDataReader *)reader {
  if (!isUserDataRead) {
    std::vector<std::shared_ptr<firebase::firestore::api::Stage>> cpp_stages;
    for (FIRStageBridge *stage in _stages) {
      cpp_stages.push_back([stage cppStageWithReader:firestore.dataReader]);
    }
    cpp_pipeline = std::make_shared<Pipeline>(cpp_stages, firestore.wrapped);
  }

  isUserDataRead = YES;
  return cpp_pipeline;
}

+ (NSArray<FIRStageBridge *> *)createStageBridgesFromQuery:(FIRQuery *)query {
  std::vector<std::shared_ptr<api::EvaluableStage>> evaluable_stages =
      firebase::firestore::core::ToPipelineStages(query.query);
  std::vector<std::shared_ptr<api::Stage>> cpp_stages(evaluable_stages.begin(),
                                                      evaluable_stages.end());
  NSMutableArray<FIRStageBridge *> *stageBridges = [NSMutableArray array];

  for (const auto &cpp_stage_base : cpp_stages) {
    if (auto cpp_stage = std::dynamic_pointer_cast<api::CollectionSource>(cpp_stage_base)) {
      [stageBridges addObject:[[FIRCollectionSourceStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage =
                   std::dynamic_pointer_cast<api::CollectionGroupSource>(cpp_stage_base)) {
      [stageBridges
          addObject:[[FIRCollectionGroupSourceStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage = std::dynamic_pointer_cast<api::DocumentsSource>(cpp_stage_base)) {
      [stageBridges addObject:[[FIRDocumentsSourceStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage = std::dynamic_pointer_cast<api::Where>(cpp_stage_base)) {
      [stageBridges addObject:[[FIRWhereStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage = std::dynamic_pointer_cast<api::LimitStage>(cpp_stage_base)) {
      [stageBridges addObject:[[FIRLimitStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage = std::dynamic_pointer_cast<api::SortStage>(cpp_stage_base)) {
      [stageBridges addObject:[[FIRSorStageBridge alloc] initWithCppStage:cpp_stage]];
    } else if (auto cpp_stage = std::dynamic_pointer_cast<api::OffsetStage>(cpp_stage_base)) {
      [stageBridges addObject:[[FIROffsetStageBridge alloc] initWithCppStage:cpp_stage]];
    } else {
      ThrowInvalidArgument(
          "Unknown or unhandled stage type '%s' encountered when converting from FIRQuery.",
          cpp_stage_base->name().c_str());
    }
  }
  return [stageBridges copy];
}

@end

@interface __FIRRealtimePipelineSnapshotBridge ()

@property(nonatomic, strong, readwrite) NSArray<__FIRPipelineResultBridge *> *results;

@property(nonatomic, strong, readwrite) NSArray<__FIRPipelineResultChangeBridge *> *changes;

@end

@implementation __FIRRealtimePipelineSnapshotBridge {
  absl::optional<api::RealtimePipelineSnapshot> snapshot_;
  NSMutableArray<__FIRPipelineResultBridge *> *results_;
  NSMutableArray<__FIRPipelineResultChangeBridge *> *changes_;
  FIRSnapshotMetadata *_metadata;
}

- (id)initWithCppSnapshot:(api::RealtimePipelineSnapshot)snapshot {
  self = [super init];
  if (self) {
    snapshot_ = std::move(snapshot);
    if (!snapshot_.has_value()) {
      results_ = nil;
    } else {
      _metadata =
          [[FIRSnapshotMetadata alloc] initWithMetadata:snapshot_.value().snapshot_metadata()];

      NSMutableArray<__FIRPipelineResultBridge *> *results = [NSMutableArray array];
      for (auto &result : snapshot_.value().view_snapshot().documents()) {
        [results addObject:[[__FIRPipelineResultBridge alloc]
                               initWithCppResult:api::PipelineResult(result)
                                              db:snapshot_.value().firestore()]];
      }
      results_ = results;

      NSMutableArray<__FIRPipelineResultChangeBridge *> *changes = [NSMutableArray array];
      for (auto &change : snapshot_.value().CalculateResultChanges(false)) {
        [changes addObject:[[__FIRPipelineResultChangeBridge alloc]
                               initWithCppChange:change
                                              db:snapshot_.value().firestore()]];
      }
      changes_ = changes;
    }
  }

  return self;
}

- (NSArray<__FIRPipelineResultBridge *> *)results {
  return results_;
}

- (NSArray<__FIRPipelineResultChangeBridge *> *)changes {
  return changes_;
}

- (FIRSnapshotMetadata *)metadata {
  return _metadata;
}

@end

@implementation __FIRPipelineListenOptionsBridge

- (instancetype)initWithServerTimestampBehavior:(NSString *)serverTimestampBehavior
                                includeMetadata:(BOOL)includeMetadata
                                         source:(FIRListenSource)source {
  // Call the designated initializer of the superclass (NSObject).
  self = [super init];
  if (self) {
    // Assign the passed-in values to the backing instance variables
    // for the readonly properties.
    // We use `copy` here for the string to ensure our object owns an immutable version.
    _serverTimestampBehavior = [serverTimestampBehavior copy];
    _includeMetadata = includeMetadata;
    _source = source;
  }
  return self;
}

@end

@implementation FIRRealtimePipelineBridge {
  NSArray<FIRStageBridge *> *_stages;
  FIRFirestore *firestore;
  std::shared_ptr<api::RealtimePipeline> cpp_pipeline;
}

- (id)initWithStages:(NSArray<FIRStageBridge *> *)stages db:(FIRFirestore *)db {
  _stages = stages;
  firestore = db;
  return [super init];
}

core::ListenOptions ToListenOptions(__FIRPipelineListenOptionsBridge *_Nullable bridge) {
  // If the bridge object is nil, return a default-constructed ListenOptions.
  if (bridge == nil) {
    return core::ListenOptions::DefaultOptions();
  }

  // 1. Translate include_metadata_changes
  bool include_metadata = bridge.includeMetadata;

  // 2. Translate ListenSource
  core::ListenSource source = core::ListenSource::Default;
  switch (bridge.source) {
    case FIRListenSourceDefault:
      source = core::ListenSource::Default;
      break;
    case FIRListenSourceCache:
      source = core::ListenSource::Cache;
      break;
  }

  // 3. Translate ServerTimestampBehavior
  core::ListenOptions::ServerTimestampBehavior behavior =
      core::ListenOptions::ServerTimestampBehavior::kNone;
  if ([bridge.serverTimestampBehavior isEqual:@"estimate"]) {
    behavior = core::ListenOptions::ServerTimestampBehavior::kEstimate;
  } else if ([bridge.serverTimestampBehavior isEqual:@"previous"]) {
    behavior = core::ListenOptions::ServerTimestampBehavior::kPrevious;
  } else {
    // "none" or any other value defaults to kNone.
    behavior = core::ListenOptions::ServerTimestampBehavior::kNone;
  }

  // 4. Construct the final C++ object using the canonical private constructor.
  // Note: wait_for_sync_when_online is not part of the bridge, so we use 'false'
  // to match the behavior of the existing static factories.
  return core::ListenOptions(
      /*include_query_metadata_changes=*/include_metadata,
      /*include_document_metadata_changes=*/include_metadata,
      /*wait_for_sync_when_online=*/false, source, behavior);
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerWithOptions:(__FIRPipelineListenOptionsBridge *)options
                          listener:
                              (void (^)(__FIRRealtimePipelineSnapshotBridge *_Nullable snapshot,
                                        NSError *_Nullable error))listener {
  std::shared_ptr<api::Firestore> wrapped_firestore = firestore.wrapped;

  std::vector<std::shared_ptr<firebase::firestore::api::EvaluableStage>> cpp_stages;
  for (FIRStageBridge *stage in _stages) {
    auto evaluable_stage = std::dynamic_pointer_cast<api::EvaluableStage>(
        [stage cppStageWithReader:firestore.dataReader]);
    if (evaluable_stage) {
      cpp_stages.push_back(evaluable_stage);
    } else {
      HARD_FAIL("Failed to convert cpp stage to EvaluableStage for RealtimePipeline");
    }
  }

  cpp_pipeline = std::make_shared<RealtimePipeline>(
      cpp_stages, std::make_unique<remote::Serializer>(wrapped_firestore->database_id()));

  // Convert from ViewSnapshots to RealtimePipelineSnapshots.
  auto view_listener = EventListener<ViewSnapshot>::Create(
      [listener, wrapped_firestore](StatusOr<ViewSnapshot> maybe_snapshot) {
        if (!maybe_snapshot.status().ok()) {
          listener(nil, MakeNSError(maybe_snapshot.status()));
          return;
        }

        ViewSnapshot snapshot = std::move(maybe_snapshot).ValueOrDie();
        SnapshotMetadata metadata(snapshot.has_pending_writes(), snapshot.from_cache());

        listener(
            [[__FIRRealtimePipelineSnapshotBridge alloc]
                initWithCppSnapshot:RealtimePipelineSnapshot(wrapped_firestore, std::move(snapshot),
                                                             std::move(metadata))],
            nil);
      });

  // Call the view_listener on the user Executor.
  auto async_listener = core::AsyncEventListener<ViewSnapshot>::Create(
      wrapped_firestore->client()->user_executor(), std::move(view_listener));

  std::shared_ptr<core::QueryListener> query_listener = wrapped_firestore->client()->ListenToQuery(
      core::QueryOrPipeline(*cpp_pipeline), ToListenOptions(options), async_listener);

  return [[FSTListenerRegistration alloc]
      initWithRegistration:absl::make_unique<QueryListenerRegistration>(wrapped_firestore->client(),
                                                                        std::move(async_listener),
                                                                        std::move(query_listener))];
}

- (std::shared_ptr<api::RealtimePipeline>)cppPipelineWithReader:(FSTUserDataReader *)reader {
  return cpp_pipeline;
}

@end

NS_ASSUME_NONNULL_END
