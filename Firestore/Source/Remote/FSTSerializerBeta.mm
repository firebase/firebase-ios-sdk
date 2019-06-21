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

#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include <cinttypes>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "Firestore/Protos/objc/google/firestore/v1/Common.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Firestore.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Query.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Write.pbobjc.h"
#import "Firestore/Protos/objc/google/rpc/Status.pbobjc.h"
#import "Firestore/Protos/objc/google/type/Latlng.pbobjc.h"

#import "FIRFirestoreErrors.h"
#import "FIRGeoPoint.h"
#import "FIRTimestamp.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/remote/existence_filter.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "absl/types/optional.h"

namespace util = firebase::firestore::util;
using firebase::Timestamp;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::GeoPoint;
using firebase::firestore::core::Filter;
using firebase::firestore::core::Query;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::NumericIncrementTransform;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::nanopb::MakeByteString;
using firebase::firestore::nanopb::MakeNSData;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTSerializerBeta {
  DatabaseId _databaseID;
}

- (instancetype)initWithDatabaseID:(DatabaseId)databaseID {
  self = [super init];
  if (self) {
    _databaseID = std::move(databaseID);
  }
  return self;
}

#pragma mark - SnapshotVersion <=> GPBTimestamp

- (GPBTimestamp *)encodedTimestamp:(const Timestamp &)timestamp {
  GPBTimestamp *result = [GPBTimestamp message];
  result.seconds = timestamp.seconds();
  result.nanos = timestamp.nanoseconds();
  return result;
}

- (Timestamp)decodedTimestamp:(GPBTimestamp *)timestamp {
  return Timestamp{timestamp.seconds, timestamp.nanos};
}

- (GPBTimestamp *)encodedVersion:(const SnapshotVersion &)version {
  return [self encodedTimestamp:version.timestamp()];
}

- (SnapshotVersion)decodedVersion:(GPBTimestamp *)version {
  return SnapshotVersion{[self decodedTimestamp:version]};
}

#pragma mark - FIRGeoPoint <=> GTPLatLng

- (GTPLatLng *)encodedGeoPoint:(const GeoPoint &)geoPoint {
  GTPLatLng *latLng = [GTPLatLng message];
  latLng.latitude = geoPoint.latitude();
  latLng.longitude = geoPoint.longitude();
  return latLng;
}

- (GeoPoint)decodedGeoPoint:(GTPLatLng *)latLng {
  return GeoPoint(latLng.latitude, latLng.longitude);
}

#pragma mark - DocumentKey <=> Key proto

- (NSString *)encodedDocumentKey:(const DocumentKey &)key {
  return [self encodedResourcePathForDatabaseID:_databaseID path:key.path()];
}

- (DocumentKey)decodedDocumentKey:(NSString *)name {
  const ResourcePath path = [self decodedResourcePathWithDatabaseID:name];
  HARD_ASSERT(path[1] == _databaseID.project_id(),
              "Tried to deserialize key from different project.");
  HARD_ASSERT(path[3] == _databaseID.database_id(),
              "Tried to deserialize key from different datbase.");
  return DocumentKey{[self localResourcePathForQualifiedResourcePath:path]};
}

- (NSString *)encodedResourcePathForDatabaseID:(const DatabaseId &)databaseID
                                          path:(const ResourcePath &)path {
  return util::WrapNSString([self encodedResourcePathForDatabaseID:databaseID]
                                .Append("documents")
                                .Append(path)
                                .CanonicalString());
}

- (ResourcePath)decodedResourcePathWithDatabaseID:(NSString *)name {
  const ResourcePath path = ResourcePath::FromString(util::MakeString(name));
  HARD_ASSERT([self validQualifiedResourcePath:path], "Tried to deserialize invalid key %s",
              path.CanonicalString());
  return path;
}

- (NSString *)encodedQueryPath:(const ResourcePath &)path {
  return [self encodedResourcePathForDatabaseID:_databaseID path:path];
}

- (ResourcePath)decodedQueryPath:(NSString *)name {
  const ResourcePath resource = [self decodedResourcePathWithDatabaseID:name];
  if (resource.size() == 4) {
    // In v1beta1 queries for collections at the root did not have a trailing "/documents". In v1
    // all resource paths contain "/documents". Preserve the ability to read the v1beta1 form for
    // compatibility with queries persisted in the local query cache.
    return ResourcePath{};
  } else {
    return [self localResourcePathForQualifiedResourcePath:resource];
  }
}

- (ResourcePath)encodedResourcePathForDatabaseID:(const DatabaseId &)databaseID {
  return ResourcePath{"projects", databaseID.project_id(), "databases", databaseID.database_id()};
}

- (ResourcePath)localResourcePathForQualifiedResourcePath:(const ResourcePath &)resourceName {
  HARD_ASSERT(resourceName.size() > 4 && resourceName[4] == "documents",
              "Tried to deserialize invalid key %s", resourceName.CanonicalString());
  return resourceName.PopFirst(5);
}

- (BOOL)validQualifiedResourcePath:(const ResourcePath &)path {
  return path.size() >= 4 && path[0] == "projects" && path[2] == "databases";
}

- (NSString *)encodedDatabaseID {
  return util::WrapNSString([self encodedResourcePathForDatabaseID:_databaseID].CanonicalString());
}

#pragma mark - FieldValue <=> Value proto

- (GCFSValue *)encodedFieldValue:(const FieldValue &)fieldValue {
  switch (fieldValue.type()) {
    case FieldValue::Type::Null:
      return [self encodedNull];
    case FieldValue::Type::Boolean:
      return [self encodedBool:fieldValue.boolean_value()];
    case FieldValue::Type::Integer:
      return [self encodedInteger:fieldValue.integer_value()];
    case FieldValue::Type::Double:
      return [self encodedDouble:fieldValue.double_value()];
    case FieldValue::Type::Timestamp:
      return [self encodedTimestampValue:fieldValue.timestamp_value()];
    case FieldValue::Type::String:
      return [self encodedString:fieldValue.string_value()];
    case FieldValue::Type::Blob:
      return [self encodedBlobValue:fieldValue.blob_value()];
    case FieldValue::Type::Reference: {
      const auto &ref = fieldValue.reference_value();
      return [self encodedReferenceValueForDatabaseID:ref.database_id() key:ref.key()];
    }
    case FieldValue::Type::GeoPoint:
      return [self encodedGeoPointValue:fieldValue.geo_point_value()];
    case FieldValue::Type::Array: {
      GCFSValue *result = [GCFSValue message];
      result.arrayValue = [self encodedArrayValue:fieldValue.array_value()];
      return result;
    }
    case FieldValue::Type::Object: {
      GCFSValue *result = [GCFSValue message];
      result.mapValue = [self encodedMapValue:fieldValue.object_value()];
      return result;
    }

    case FieldValue::Type::ServerTimestamp:
      HARD_FAIL("Unhandled type %s on %s", fieldValue.type(), fieldValue.ToString());
  }
  UNREACHABLE();
}

- (FieldValue)decodedFieldValue:(GCFSValue *)valueProto {
  switch (valueProto.valueTypeOneOfCase) {
    case GCFSValue_ValueType_OneOfCase_NullValue:
      return FieldValue::Null();

    case GCFSValue_ValueType_OneOfCase_BooleanValue:
      return FieldValue::FromBoolean(valueProto.booleanValue);

    case GCFSValue_ValueType_OneOfCase_IntegerValue:
      return FieldValue::FromInteger(valueProto.integerValue);

    case GCFSValue_ValueType_OneOfCase_DoubleValue:
      return FieldValue::FromDouble(valueProto.doubleValue);

    case GCFSValue_ValueType_OneOfCase_StringValue:
      return FieldValue::FromString(util::MakeString(valueProto.stringValue));

    case GCFSValue_ValueType_OneOfCase_TimestampValue: {
      Timestamp value = [self decodedTimestamp:valueProto.timestampValue];
      return FieldValue::FromTimestamp(value);
    }

    case GCFSValue_ValueType_OneOfCase_GeoPointValue:
      return FieldValue::FromGeoPoint([self decodedGeoPoint:valueProto.geoPointValue]);

    case GCFSValue_ValueType_OneOfCase_BytesValue:
      return FieldValue::FromBlob(MakeByteString(valueProto.bytesValue));

    case GCFSValue_ValueType_OneOfCase_ReferenceValue:
      return [self decodedReferenceValue:valueProto.referenceValue];

    case GCFSValue_ValueType_OneOfCase_ArrayValue:
      return [self decodedArrayValue:valueProto.arrayValue];

    case GCFSValue_ValueType_OneOfCase_MapValue:
      return [self decodedMapValue:valueProto.mapValue];

    default:
      HARD_FAIL("Unhandled type %s on %s", valueProto.valueTypeOneOfCase, valueProto);
  }
}

- (GCFSValue *)encodedNull {
  GCFSValue *result = [GCFSValue message];
  result.nullValue = GPBNullValue_NullValue;
  return result;
}

- (GCFSValue *)encodedBool:(bool)value {
  GCFSValue *result = [GCFSValue message];
  result.booleanValue = value;
  return result;
}

- (GCFSValue *)encodedDouble:(double)value {
  GCFSValue *result = [GCFSValue message];
  result.doubleValue = value;
  return result;
}

- (GCFSValue *)encodedInteger:(int64_t)value {
  GCFSValue *result = [GCFSValue message];
  result.integerValue = value;
  return result;
}

- (GCFSValue *)encodedString:(absl::string_view)value {
  GCFSValue *result = [GCFSValue message];
  result.stringValue = util::WrapNSString(value);
  return result;
}

- (GCFSValue *)encodedTimestampValue:(const Timestamp &)value {
  GCFSValue *result = [GCFSValue message];
  result.timestampValue = [self encodedTimestamp:value];
  return result;
}

- (GCFSValue *)encodedGeoPointValue:(const GeoPoint &)value {
  GCFSValue *result = [GCFSValue message];
  result.geoPointValue = [self encodedGeoPoint:value];
  return result;
}

- (GCFSValue *)encodedBlobValue:(const ByteString &)value {
  GCFSValue *result = [GCFSValue message];
  result.bytesValue = MakeNSData(value);
  return result;
}

- (GCFSValue *)encodedReferenceValueForDatabaseID:(const DatabaseId &)databaseID
                                              key:(const DocumentKey &)key {
  HARD_ASSERT(databaseID == _databaseID, "Database %s:%s cannot encode reference from %s:%s",
              _databaseID.project_id(), _databaseID.database_id(), databaseID.project_id(),
              databaseID.database_id());
  GCFSValue *result = [GCFSValue message];
  result.referenceValue = [self encodedResourcePathForDatabaseID:databaseID path:key.path()];
  return result;
}

- (FieldValue)decodedReferenceValue:(NSString *)resourceName {
  const ResourcePath path = [self decodedResourcePathWithDatabaseID:resourceName];
  const std::string &project = path[1];
  const std::string &database = path[3];
  const DocumentKey key{[self localResourcePathForQualifiedResourcePath:path]};

  const DatabaseId database_id(project, database);
  HARD_ASSERT(database_id == _databaseID, "Database %s:%s cannot encode reference from %s:%s",
              _databaseID.project_id(), _databaseID.database_id(), database_id.project_id(),
              database_id.database_id());
  return FieldValue::FromReference(_databaseID, key);
}

- (GCFSArrayValue *)encodedArrayValue:(const FieldValue::Array &)arrayValue {
  GCFSArrayValue *proto = [GCFSArrayValue message];
  NSMutableArray<GCFSValue *> *protoContents = [proto valuesArray];

  for (const FieldValue &value : arrayValue) {
    GCFSValue *converted = [self encodedFieldValue:value];
    [protoContents addObject:converted];
  }
  return proto;
}

- (FieldValue)decodedArrayValue:(GCFSArrayValue *)arrayValue {
  FieldValue::Array contents;
  contents.reserve(arrayValue.valuesArray_Count);

  for (GCFSValue *value in arrayValue.valuesArray) {
    contents.push_back([self decodedFieldValue:value]);
  }

  return FieldValue::FromArray(std::move(contents));
}

- (GCFSMapValue *)encodedMapValue:(const FieldValue::Map &)value {
  GCFSMapValue *result = [GCFSMapValue message];
  result.fields = [self encodedMapFields:value];
  return result;
}

- (ObjectValue)decodedMapValue:(GCFSMapValue *)map {
  return [self decodedFields:map.fields];
}

/**
 * Encodes an FSTObjectValue into a dictionary.
 * @return a new dictionary that can be assigned to a field in another proto.
 */
- (NSMutableDictionary<NSString *, GCFSValue *> *)encodedFields:(const ObjectValue &)value {
  return [self encodedMapFields:value.GetInternalValue()];
}

- (NSMutableDictionary<NSString *, GCFSValue *> *)encodedMapFields:(const FieldValue::Map &)value {
  NSMutableDictionary<NSString *, GCFSValue *> *result = [NSMutableDictionary dictionary];

  for (const auto &kv : value) {
    NSString *key = util::WrapNSString(kv.first);
    GCFSValue *converted = [self encodedFieldValue:kv.second];
    result[key] = converted;
  }
  return result;
}

- (ObjectValue)decodedFields:(NSDictionary<NSString *, GCFSValue *> *)fields {
  __block ObjectValue result = ObjectValue::Empty();
  [fields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, GCFSValue *_Nonnull obj,
                                              BOOL *_Nonnull stop) {
    FieldPath path{util::MakeString(key)};
    FieldValue value = [self decodedFieldValue:obj];
    result = result.Set(path, std::move(value));
  }];
  return result;
}

#pragma mark - FSTObjectValue <=> Document proto

- (GCFSDocument *)encodedDocumentWithFields:(const ObjectValue &)objectValue
                                        key:(const DocumentKey &)key {
  GCFSDocument *proto = [GCFSDocument message];
  proto.name = [self encodedDocumentKey:key];
  proto.fields = [self encodedFields:objectValue];
  return proto;
}

#pragma mark - FSTMaybeDocument <= BatchGetDocumentsResponse proto

- (FSTMaybeDocument *)decodedMaybeDocumentFromBatch:(GCFSBatchGetDocumentsResponse *)response {
  switch (response.resultOneOfCase) {
    case GCFSBatchGetDocumentsResponse_Result_OneOfCase_Found:
      return [self decodedFoundDocument:response];
    case GCFSBatchGetDocumentsResponse_Result_OneOfCase_Missing:
      return [self decodedDeletedDocument:response];
    default:
      HARD_FAIL("Unknown document type: %s", response);
  }
}

- (FSTDocument *)decodedFoundDocument:(GCFSBatchGetDocumentsResponse *)response {
  HARD_ASSERT(!!response.found, "Tried to deserialize a found document from a deleted document.");
  const DocumentKey key = [self decodedDocumentKey:response.found.name];
  ObjectValue value = [self decodedFields:response.found.fields];
  SnapshotVersion version = [self decodedVersion:response.found.updateTime];
  HARD_ASSERT(version != SnapshotVersion::None(),
              "Got a document response with no snapshot version");

  return [FSTDocument documentWithData:value
                                   key:key
                               version:version
                                 state:DocumentState::kSynced
                                 proto:response.found];
}

- (FSTDeletedDocument *)decodedDeletedDocument:(GCFSBatchGetDocumentsResponse *)response {
  HARD_ASSERT(!!response.missing, "Tried to deserialize a deleted document from a found document.");
  const DocumentKey key = [self decodedDocumentKey:response.missing];
  SnapshotVersion version = [self decodedVersion:response.readTime];
  HARD_ASSERT(version != SnapshotVersion::None(),
              "Got a no document response with no snapshot version");
  return [FSTDeletedDocument documentWithKey:key version:version hasCommittedMutations:NO];
}

#pragma mark - FSTMutation => GCFSWrite proto

- (GCFSWrite *)encodedMutation:(FSTMutation *)mutation {
  GCFSWrite *proto = [GCFSWrite message];

  Class mutationClass = [mutation class];
  if (mutationClass == [FSTSetMutation class]) {
    FSTSetMutation *set = (FSTSetMutation *)mutation;
    proto.update = [self encodedDocumentWithFields:set.value key:set.key];

  } else if (mutationClass == [FSTPatchMutation class]) {
    FSTPatchMutation *patch = (FSTPatchMutation *)mutation;
    proto.update = [self encodedDocumentWithFields:patch.value key:patch.key];
    proto.updateMask = [self encodedFieldMask:*(patch.fieldMask)];

  } else if (mutationClass == [FSTTransformMutation class]) {
    FSTTransformMutation *transform = (FSTTransformMutation *)mutation;

    proto.transform = [GCFSDocumentTransform message];
    proto.transform.document = [self encodedDocumentKey:transform.key];
    proto.transform.fieldTransformsArray = [self encodedFieldTransforms:transform.fieldTransforms];
    // NOTE: We set a precondition of exists: true as a safety-check, since we always combine
    // FSTTransformMutations with an FSTSetMutation or FSTPatchMutation which (if successful) should
    // end up with an existing document.
    proto.currentDocument.exists = YES;

  } else if (mutationClass == [FSTDeleteMutation class]) {
    FSTDeleteMutation *deleteMutation = (FSTDeleteMutation *)mutation;
    proto.delete_p = [self encodedDocumentKey:deleteMutation.key];

  } else {
    HARD_FAIL("Unknown mutation type %s", NSStringFromClass(mutationClass));
  }

  if (!mutation.precondition.IsNone()) {
    proto.currentDocument = [self encodedPrecondition:mutation.precondition];
  }

  return proto;
}

- (FSTMutation *)decodedMutation:(GCFSWrite *)mutation {
  Precondition precondition = [mutation hasCurrentDocument]
                                  ? [self decodedPrecondition:mutation.currentDocument]
                                  : Precondition::None();

  switch (mutation.operationOneOfCase) {
    case GCFSWrite_Operation_OneOfCase_Update:
      if (mutation.hasUpdateMask) {
        return [[FSTPatchMutation alloc] initWithKey:[self decodedDocumentKey:mutation.update.name]
                                           fieldMask:[self decodedFieldMask:mutation.updateMask]
                                               value:[self decodedFields:mutation.update.fields]
                                        precondition:precondition];
      } else {
        return [[FSTSetMutation alloc] initWithKey:[self decodedDocumentKey:mutation.update.name]
                                             value:[self decodedFields:mutation.update.fields]
                                      precondition:precondition];
      }

    case GCFSWrite_Operation_OneOfCase_Delete_p:
      return [[FSTDeleteMutation alloc] initWithKey:[self decodedDocumentKey:mutation.delete_p]
                                       precondition:precondition];

    case GCFSWrite_Operation_OneOfCase_Transform: {
      HARD_ASSERT(precondition == Precondition::Exists(true),
                  "Transforms must have precondition \"exists == true\"");

      return [[FSTTransformMutation alloc]
              initWithKey:[self decodedDocumentKey:mutation.transform.document]
          fieldTransforms:[self decodedFieldTransforms:mutation.transform.fieldTransformsArray]];
    }

    default:
      // Note that insert is intentionally unhandled, since we don't ever deal in them.
      HARD_FAIL("Unknown mutation operation: %s", mutation.operationOneOfCase);
  }
}

- (GCFSPrecondition *)encodedPrecondition:(const Precondition &)precondition {
  HARD_ASSERT(!precondition.IsNone(), "Can't serialize an empty precondition");
  GCFSPrecondition *message = [GCFSPrecondition message];
  if (precondition.type() == Precondition::Type::UpdateTime) {
    message.updateTime = [self encodedVersion:precondition.update_time()];
  } else if (precondition.type() == Precondition::Type::Exists) {
    message.exists = precondition == Precondition::Exists(true);
  } else {
    HARD_FAIL("Unknown precondition: %s", precondition.description());
  }
  return message;
}

- (Precondition)decodedPrecondition:(GCFSPrecondition *)precondition {
  switch (precondition.conditionTypeOneOfCase) {
    case GCFSPrecondition_ConditionType_OneOfCase_GPBUnsetOneOfCase:
      return Precondition::None();

    case GCFSPrecondition_ConditionType_OneOfCase_Exists:
      return Precondition::Exists(precondition.exists);

    case GCFSPrecondition_ConditionType_OneOfCase_UpdateTime:
      return Precondition::UpdateTime([self decodedVersion:precondition.updateTime]);

    default:
      HARD_FAIL("Unrecognized Precondition one-of case %s", precondition);
  }
}

- (GCFSDocumentMask *)encodedFieldMask:(const FieldMask &)fieldMask {
  GCFSDocumentMask *mask = [GCFSDocumentMask message];
  for (const FieldPath &field : fieldMask) {
    [mask.fieldPathsArray addObject:util::WrapNSString(field.CanonicalString())];
  }
  return mask;
}

- (FieldMask)decodedFieldMask:(GCFSDocumentMask *)fieldMask {
  std::set<FieldPath> fields;
  for (NSString *path in fieldMask.fieldPathsArray) {
    fields.insert(FieldPath::FromServerFormat(util::MakeString(path)));
  }
  return FieldMask(std::move(fields));
}

- (NSMutableArray<GCFSDocumentTransform_FieldTransform *> *)encodedFieldTransforms:
    (const std::vector<FieldTransform> &)fieldTransforms {
  NSMutableArray *protos = [NSMutableArray array];
  for (const FieldTransform &fieldTransform : fieldTransforms) {
    GCFSDocumentTransform_FieldTransform *proto = [self encodedFieldTransform:fieldTransform];
    [protos addObject:proto];
  }
  return protos;
}

- (GCFSDocumentTransform_FieldTransform *)encodedFieldTransform:
    (const FieldTransform &)fieldTransform {
  GCFSDocumentTransform_FieldTransform *proto = [GCFSDocumentTransform_FieldTransform message];
  proto.fieldPath = util::WrapNSString(fieldTransform.path().CanonicalString());
  if (fieldTransform.transformation().type() == TransformOperation::Type::ServerTimestamp) {
    proto.setToServerValue = GCFSDocumentTransform_FieldTransform_ServerValue_RequestTime;

  } else if (fieldTransform.transformation().type() == TransformOperation::Type::ArrayUnion) {
    proto.appendMissingElements = [self
        encodedArrayTransformElements:ArrayTransform::Elements(fieldTransform.transformation())];

  } else if (fieldTransform.transformation().type() == TransformOperation::Type::ArrayRemove) {
    proto.removeAllFromArray_p = [self
        encodedArrayTransformElements:ArrayTransform::Elements(fieldTransform.transformation())];
  } else if (fieldTransform.transformation().type() == TransformOperation::Type::Increment) {
    const NumericIncrementTransform &incrementTransform =
        static_cast<const NumericIncrementTransform &>(fieldTransform.transformation());
    proto.increment = [self encodedFieldValue:incrementTransform.operand()];
  } else {
    HARD_FAIL("Unknown transform: %s type", fieldTransform.transformation().type());
  }
  return proto;
}

- (GCFSArrayValue *)encodedArrayTransformElements:(const std::vector<FieldValue> &)elements {
  GCFSArrayValue *proto = [GCFSArrayValue message];
  NSMutableArray<GCFSValue *> *protoContents = [proto valuesArray];

  for (const FieldValue &element : elements) {
    GCFSValue *converted = [self encodedFieldValue:element];
    [protoContents addObject:converted];
  }
  return proto;
}

- (std::vector<FieldTransform>)decodedFieldTransforms:
    (NSArray<GCFSDocumentTransform_FieldTransform *> *)protos {
  std::vector<FieldTransform> fieldTransforms;
  fieldTransforms.reserve(protos.count);

  for (GCFSDocumentTransform_FieldTransform *proto in protos) {
    switch (proto.transformTypeOneOfCase) {
      case GCFSDocumentTransform_FieldTransform_TransformType_OneOfCase_SetToServerValue: {
        HARD_ASSERT(
            proto.setToServerValue == GCFSDocumentTransform_FieldTransform_ServerValue_RequestTime,
            "Unknown transform setToServerValue: %s", proto.setToServerValue);
        fieldTransforms.emplace_back(
            FieldPath::FromServerFormat(util::MakeString(proto.fieldPath)),
            absl::make_unique<ServerTimestampTransform>(ServerTimestampTransform::Get()));
        break;
      }

      case GCFSDocumentTransform_FieldTransform_TransformType_OneOfCase_AppendMissingElements: {
        std::vector<FieldValue> elements =
            [self decodedArrayTransformElements:proto.appendMissingElements];
        fieldTransforms.emplace_back(
            FieldPath::FromServerFormat(util::MakeString(proto.fieldPath)),
            absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayUnion,
                                              std::move(elements)));
        break;
      }

      case GCFSDocumentTransform_FieldTransform_TransformType_OneOfCase_RemoveAllFromArray_p: {
        std::vector<FieldValue> elements =
            [self decodedArrayTransformElements:proto.removeAllFromArray_p];
        fieldTransforms.emplace_back(
            FieldPath::FromServerFormat(util::MakeString(proto.fieldPath)),
            absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayRemove,
                                              std::move(elements)));
        break;
      }

      case GCFSDocumentTransform_FieldTransform_TransformType_OneOfCase_Increment: {
        FieldValue operand = [self decodedFieldValue:proto.increment];
        fieldTransforms.emplace_back(FieldPath::FromServerFormat(util::MakeString(proto.fieldPath)),
                                     absl::make_unique<NumericIncrementTransform>(operand));
        break;
      }

      default:
        HARD_FAIL("Unknown transform: %s", proto);
    }
  }

  return fieldTransforms;
}

- (std::vector<FieldValue>)decodedArrayTransformElements:(GCFSArrayValue *)proto {
  __block std::vector<FieldValue> elements;
  [proto.valuesArray enumerateObjectsUsingBlock:^(GCFSValue *value, NSUInteger idx, BOOL *stop) {
    elements.push_back([self decodedFieldValue:value]);
  }];
  return elements;
}

#pragma mark - FSTMutationResult <= GCFSWriteResult proto

- (FSTMutationResult *)decodedMutationResult:(GCFSWriteResult *)mutation
                               commitVersion:(const SnapshotVersion &)commitVersion {
  // NOTE: Deletes don't have an updateTime. Use commitVersion instead.
  SnapshotVersion version =
      mutation.hasUpdateTime ? [self decodedVersion:mutation.updateTime] : commitVersion;
  absl::optional<std::vector<FieldValue>> transformResults;
  if (mutation.transformResultsArray.count > 0) {
    transformResults = std::vector<FieldValue>{};
    for (GCFSValue *result in mutation.transformResultsArray) {
      transformResults->push_back([self decodedFieldValue:result]);
    }
  }
  return [[FSTMutationResult alloc] initWithVersion:std::move(version)
                                   transformResults:std::move(transformResults)];
}

#pragma mark - FSTQueryData => GCFSTarget proto

- (nullable NSMutableDictionary<NSString *, NSString *> *)encodedListenRequestLabelsForQueryData:
    (FSTQueryData *)queryData {
  NSString *value = [self encodedLabelForPurpose:queryData.purpose];
  if (!value) {
    return nil;
  }

  NSMutableDictionary<NSString *, NSString *> *result =
      [NSMutableDictionary dictionaryWithCapacity:1];
  [result setObject:value forKey:@"goog-listen-tags"];
  return result;
}

- (nullable NSString *)encodedLabelForPurpose:(FSTQueryPurpose)purpose {
  switch (purpose) {
    case FSTQueryPurposeListen:
      return nil;
    case FSTQueryPurposeExistenceFilterMismatch:
      return @"existence-filter-mismatch";
    case FSTQueryPurposeLimboResolution:
      return @"limbo-document";
    default:
      HARD_FAIL("Unrecognized query purpose: %s", purpose);
  }
}

- (GCFSTarget *)encodedTarget:(FSTQueryData *)queryData {
  GCFSTarget *result = [GCFSTarget message];
  FSTQuery *query = queryData.query;

  if ([query isDocumentQuery]) {
    result.documents = [self encodedDocumentsTarget:query];
  } else {
    result.query = [self encodedQueryTarget:query];
  }

  result.targetId = queryData.targetID;
  if (queryData.resumeToken.length > 0) {
    result.resumeToken = queryData.resumeToken;
  }

  return result;
}

- (GCFSTarget_DocumentsTarget *)encodedDocumentsTarget:(FSTQuery *)query {
  GCFSTarget_DocumentsTarget *result = [GCFSTarget_DocumentsTarget message];
  NSMutableArray<NSString *> *docs = result.documentsArray;
  [docs addObject:[self encodedQueryPath:query.path]];
  return result;
}

- (FSTQuery *)decodedQueryFromDocumentsTarget:(GCFSTarget_DocumentsTarget *)target {
  NSArray<NSString *> *documents = target.documentsArray;
  HARD_ASSERT(documents.count == 1, "DocumentsTarget contained other than 1 document %s",
              (unsigned long)documents.count);

  NSString *name = documents[0];
  return [FSTQuery queryWithPath:[self decodedQueryPath:name]];
}

- (GCFSTarget_QueryTarget *)encodedQueryTarget:(FSTQuery *)query {
  // Dissect the path into parent, collectionId, and optional key filter.
  GCFSTarget_QueryTarget *queryTarget = [GCFSTarget_QueryTarget message];
  const ResourcePath &path = query.path;
  if (query.collectionGroup) {
    HARD_ASSERT(path.size() % 2 == 0,
                "Collection group queries should be within a document path or root.");
    queryTarget.parent = [self encodedQueryPath:path];
    GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
    from.collectionId = query.collectionGroup;
    from.allDescendants = YES;
    [queryTarget.structuredQuery.fromArray addObject:from];
  } else {
    HARD_ASSERT(path.size() % 2 != 0, "Document queries with filters are not supported.");
    queryTarget.parent = [self encodedQueryPath:path.PopLast()];
    GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
    from.collectionId = util::WrapNSString(path.last_segment());
    [queryTarget.structuredQuery.fromArray addObject:from];
  }

  // Encode the filters.
  GCFSStructuredQuery_Filter *_Nullable where = [self encodedFilters:query.filters];
  if (where) {
    queryTarget.structuredQuery.where = where;
  }

  NSArray<GCFSStructuredQuery_Order *> *orders = [self encodedSortOrders:query.sortOrders];
  if (orders.count) {
    [queryTarget.structuredQuery.orderByArray addObjectsFromArray:orders];
  }

  if (query.limit != Query::kNoLimit) {
    queryTarget.structuredQuery.limit.value = (int32_t)query.limit;
  }

  if (query.startAt) {
    queryTarget.structuredQuery.startAt = [self encodedBound:query.startAt];
  }

  if (query.endAt) {
    queryTarget.structuredQuery.endAt = [self encodedBound:query.endAt];
  }

  return queryTarget;
}

- (FSTQuery *)decodedQueryFromQueryTarget:(GCFSTarget_QueryTarget *)target {
  ResourcePath path = [self decodedQueryPath:target.parent];

  GCFSStructuredQuery *query = target.structuredQuery;
  NSString *collectionGroup;
  NSUInteger fromCount = query.fromArray_Count;
  if (fromCount > 0) {
    HARD_ASSERT(fromCount == 1,
                "StructuredQuery.from with more than one collection is not supported.");

    GCFSStructuredQuery_CollectionSelector *from = query.fromArray[0];
    if (from.allDescendants) {
      collectionGroup = from.collectionId;
    } else {
      path = path.Append(util::MakeString(from.collectionId));
    }
  }

  NSArray<FSTFilter *> *filterBy;
  if (query.hasWhere) {
    filterBy = [self decodedFilters:query.where];
  } else {
    filterBy = @[];
  }

  NSArray<FSTSortOrder *> *orderBy;
  if (query.orderByArray_Count > 0) {
    orderBy = [self decodedSortOrders:query.orderByArray];
  } else {
    orderBy = @[];
  }

  int32_t limit = Query::kNoLimit;
  if (query.hasLimit) {
    limit = query.limit.value;
  }

  FSTBound *_Nullable startAt;
  if (query.hasStartAt) {
    startAt = [self decodedBound:query.startAt];
  }

  FSTBound *_Nullable endAt;
  if (query.hasEndAt) {
    endAt = [self decodedBound:query.endAt];
  }

  return [[FSTQuery alloc] initWithPath:path
                        collectionGroup:collectionGroup
                               filterBy:filterBy
                                orderBy:orderBy
                                  limit:limit
                                startAt:startAt
                                  endAt:endAt];
}

#pragma mark Filters

- (GCFSStructuredQuery_Filter *_Nullable)encodedFilters:(NSArray<FSTFilter *> *)filters {
  if (filters.count == 0) {
    return nil;
  }
  NSMutableArray<GCFSStructuredQuery_Filter *> *protos = [NSMutableArray array];
  for (FSTFilter *filter in filters) {
    if ([filter isKindOfClass:[FSTRelationFilter class]]) {
      [protos addObject:[self encodedRelationFilter:(FSTRelationFilter *)filter]];
    } else {
      [protos addObject:[self encodedUnaryFilter:filter]];
    }
  }
  if (protos.count == 1) {
    // Special case: no existing filters and we only need to add one filter. This can be made the
    // single root filter without a composite filter.
    return protos[0];
  }
  GCFSStructuredQuery_Filter *composite = [GCFSStructuredQuery_Filter message];
  composite.compositeFilter.op = GCFSStructuredQuery_CompositeFilter_Operator_And;
  composite.compositeFilter.filtersArray = protos;
  return composite;
}

- (NSArray<FSTFilter *> *)decodedFilters:(GCFSStructuredQuery_Filter *)proto {
  NSMutableArray<FSTFilter *> *result = [NSMutableArray array];

  NSArray<GCFSStructuredQuery_Filter *> *filters;
  if (proto.filterTypeOneOfCase ==
      GCFSStructuredQuery_Filter_FilterType_OneOfCase_CompositeFilter) {
    HARD_ASSERT(proto.compositeFilter.op == GCFSStructuredQuery_CompositeFilter_Operator_And,
                "Only AND-type composite filters are supported, got %s", proto.compositeFilter.op);
    filters = proto.compositeFilter.filtersArray;
  } else {
    filters = @[ proto ];
  }

  for (GCFSStructuredQuery_Filter *filter in filters) {
    switch (filter.filterTypeOneOfCase) {
      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_CompositeFilter:
        HARD_FAIL("Nested composite filters are not supported");

      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_FieldFilter:
        [result addObject:[self decodedRelationFilter:filter.fieldFilter]];
        break;

      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_UnaryFilter:
        [result addObject:[self decodedUnaryFilter:filter.unaryFilter]];
        break;

      default:
        HARD_FAIL("Unrecognized Filter.filterType %s", filter.filterTypeOneOfCase);
    }
  }
  return result;
}

- (GCFSStructuredQuery_Filter *)encodedRelationFilter:(FSTRelationFilter *)filter {
  GCFSStructuredQuery_Filter *proto = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *fieldFilter = proto.fieldFilter;
  fieldFilter.field = [self encodedFieldPath:filter.field];
  fieldFilter.op = [self encodedRelationFilterOperator:filter.filterOperator];
  fieldFilter.value = [self encodedFieldValue:filter.value];
  return proto;
}

- (FSTRelationFilter *)decodedRelationFilter:(GCFSStructuredQuery_FieldFilter *)proto {
  FieldPath fieldPath = FieldPath::FromServerFormat(util::MakeString(proto.field.fieldPath));
  Filter::Operator filterOperator = [self decodedRelationFilterOperator:proto.op];
  FieldValue value = [self decodedFieldValue:proto.value];
  return [FSTRelationFilter filterWithField:fieldPath filterOperator:filterOperator value:value];
}

- (GCFSStructuredQuery_Filter *)encodedUnaryFilter:(FSTFilter *)filter {
  GCFSStructuredQuery_Filter *proto = [GCFSStructuredQuery_Filter message];
  proto.unaryFilter.field = [self encodedFieldPath:filter.field];
  if ([filter isKindOfClass:[FSTNanFilter class]]) {
    proto.unaryFilter.op = GCFSStructuredQuery_UnaryFilter_Operator_IsNan;
  } else if ([filter isKindOfClass:[FSTNullFilter class]]) {
    proto.unaryFilter.op = GCFSStructuredQuery_UnaryFilter_Operator_IsNull;
  } else {
    HARD_FAIL("Unrecognized filter: %s", filter);
  }
  return proto;
}

- (FSTFilter *)decodedUnaryFilter:(GCFSStructuredQuery_UnaryFilter *)proto {
  FieldPath field = FieldPath::FromServerFormat(util::MakeString(proto.field.fieldPath));
  switch (proto.op) {
    case GCFSStructuredQuery_UnaryFilter_Operator_IsNan:
      return [[FSTNanFilter alloc] initWithField:field];

    case GCFSStructuredQuery_UnaryFilter_Operator_IsNull:
      return [[FSTNullFilter alloc] initWithField:field];

    default:
      HARD_FAIL("Unrecognized UnaryFilter.operator %s", proto.op);
  }
}

- (GCFSStructuredQuery_FieldReference *)encodedFieldPath:(const FieldPath &)fieldPath {
  GCFSStructuredQuery_FieldReference *ref = [GCFSStructuredQuery_FieldReference message];
  ref.fieldPath = util::WrapNSString(fieldPath.CanonicalString());
  return ref;
}

- (GCFSStructuredQuery_FieldFilter_Operator)encodedRelationFilterOperator:
    (Filter::Operator)filterOperator {
  switch (filterOperator) {
    case Filter::Operator::LessThan:
      return GCFSStructuredQuery_FieldFilter_Operator_LessThan;
    case Filter::Operator::LessThanOrEqual:
      return GCFSStructuredQuery_FieldFilter_Operator_LessThanOrEqual;
    case Filter::Operator::Equal:
      return GCFSStructuredQuery_FieldFilter_Operator_Equal;
    case Filter::Operator::GreaterThanOrEqual:
      return GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual;
    case Filter::Operator::GreaterThan:
      return GCFSStructuredQuery_FieldFilter_Operator_GreaterThan;
    case Filter::Operator::ArrayContains:
      return GCFSStructuredQuery_FieldFilter_Operator_ArrayContains;
    default:
      HARD_FAIL("Unhandled Filter::Operator: %s", filterOperator);
  }
}

- (Filter::Operator)decodedRelationFilterOperator:
    (GCFSStructuredQuery_FieldFilter_Operator)filterOperator {
  switch (filterOperator) {
    case GCFSStructuredQuery_FieldFilter_Operator_LessThan:
      return Filter::Operator::LessThan;
    case GCFSStructuredQuery_FieldFilter_Operator_LessThanOrEqual:
      return Filter::Operator::LessThanOrEqual;
    case GCFSStructuredQuery_FieldFilter_Operator_Equal:
      return Filter::Operator::Equal;
    case GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual:
      return Filter::Operator::GreaterThanOrEqual;
    case GCFSStructuredQuery_FieldFilter_Operator_GreaterThan:
      return Filter::Operator::GreaterThan;
    case GCFSStructuredQuery_FieldFilter_Operator_ArrayContains:
      return Filter::Operator::ArrayContains;
    default:
      HARD_FAIL("Unhandled FieldFilter.operator: %s", filterOperator);
  }
}

#pragma mark Property Orders

- (NSArray<GCFSStructuredQuery_Order *> *)encodedSortOrders:(NSArray<FSTSortOrder *> *)orders {
  NSMutableArray<GCFSStructuredQuery_Order *> *protos = [NSMutableArray array];
  for (FSTSortOrder *order in orders) {
    [protos addObject:[self encodedSortOrder:order]];
  }
  return protos;
}

- (NSArray<FSTSortOrder *> *)decodedSortOrders:(NSArray<GCFSStructuredQuery_Order *> *)protos {
  NSMutableArray<FSTSortOrder *> *result = [NSMutableArray arrayWithCapacity:protos.count];
  for (GCFSStructuredQuery_Order *orderProto in protos) {
    [result addObject:[self decodedSortOrder:orderProto]];
  }
  return result;
}

- (GCFSStructuredQuery_Order *)encodedSortOrder:(FSTSortOrder *)sortOrder {
  GCFSStructuredQuery_Order *proto = [GCFSStructuredQuery_Order message];
  proto.field = [self encodedFieldPath:sortOrder.field];
  if (sortOrder.ascending) {
    proto.direction = GCFSStructuredQuery_Direction_Ascending;
  } else {
    proto.direction = GCFSStructuredQuery_Direction_Descending;
  }
  return proto;
}

- (FSTSortOrder *)decodedSortOrder:(GCFSStructuredQuery_Order *)proto {
  FieldPath fieldPath = FieldPath::FromServerFormat(util::MakeString(proto.field.fieldPath));
  BOOL ascending;
  switch (proto.direction) {
    case GCFSStructuredQuery_Direction_Ascending:
      ascending = YES;
      break;
    case GCFSStructuredQuery_Direction_Descending:
      ascending = NO;
      break;
    default:
      HARD_FAIL("Unrecognized GCFSStructuredQuery_Direction %s", proto.direction);
  }
  return [FSTSortOrder sortOrderWithFieldPath:fieldPath ascending:ascending];
}

#pragma mark - Bounds/Cursors

- (GCFSCursor *)encodedBound:(FSTBound *)bound {
  GCFSCursor *proto = [GCFSCursor message];
  proto.before = bound.isBefore;
  for (const FieldValue &fieldValue : bound.position) {
    GCFSValue *value = [self encodedFieldValue:fieldValue];
    [proto.valuesArray addObject:value];
  }
  return proto;
}

- (FSTBound *)decodedBound:(GCFSCursor *)proto {
  std::vector<FieldValue> indexComponents;

  for (GCFSValue *valueProto in proto.valuesArray) {
    FieldValue value = [self decodedFieldValue:valueProto];
    indexComponents.push_back(std::move(value));
  }

  return [FSTBound boundWithPosition:std::move(indexComponents) isBefore:proto.before];
}

#pragma mark - WatchChange <= GCFSListenResponse proto

- (std::unique_ptr<WatchChange>)decodedWatchChange:(GCFSListenResponse *)watchChange {
  switch (watchChange.responseTypeOneOfCase) {
    case GCFSListenResponse_ResponseType_OneOfCase_TargetChange:
      return [self decodedTargetChangeFromWatchChange:watchChange.targetChange];

    case GCFSListenResponse_ResponseType_OneOfCase_DocumentChange:
      return [self decodedDocumentChange:watchChange.documentChange];

    case GCFSListenResponse_ResponseType_OneOfCase_DocumentDelete:
      return [self decodedDocumentDelete:watchChange.documentDelete];

    case GCFSListenResponse_ResponseType_OneOfCase_DocumentRemove:
      return [self decodedDocumentRemove:watchChange.documentRemove];

    case GCFSListenResponse_ResponseType_OneOfCase_Filter:
      return [self decodedExistenceFilterWatchChange:watchChange.filter];

    default:
      HARD_FAIL("Unknown WatchChange.changeType %s", watchChange.responseTypeOneOfCase);
  }
}

- (SnapshotVersion)versionFromListenResponse:(GCFSListenResponse *)watchChange {
  // We have only reached a consistent snapshot for the entire stream if there is a read_time set
  // and it applies to all targets (i.e. the list of targets is empty). The backend is guaranteed to
  // send such responses.
  if (watchChange.responseTypeOneOfCase != GCFSListenResponse_ResponseType_OneOfCase_TargetChange) {
    return SnapshotVersion::None();
  }
  if (watchChange.targetChange.targetIdsArray.count != 0) {
    return SnapshotVersion::None();
  }
  return [self decodedVersion:watchChange.targetChange.readTime];
}

- (std::unique_ptr<WatchChange>)decodedTargetChangeFromWatchChange:(GCFSTargetChange *)change {
  WatchTargetChangeState state = [self decodedWatchTargetChangeState:change.targetChangeType];
  __block std::vector<TargetId> targetIDs;

  [change.targetIdsArray enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
    targetIDs.push_back(value);
  }];

  NSData *resumeToken = change.resumeToken;

  util::Status cause;
  if (change.hasCause) {
    cause = util::Status{static_cast<FirestoreErrorCode>(change.cause.code),
                         util::MakeString(change.cause.message)};
  }

  return absl::make_unique<WatchTargetChange>(state, std::move(targetIDs), resumeToken,
                                              std::move(cause));
}

- (WatchTargetChangeState)decodedWatchTargetChangeState:(GCFSTargetChange_TargetChangeType)state {
  switch (state) {
    case GCFSTargetChange_TargetChangeType_NoChange:
      return WatchTargetChangeState::NoChange;
    case GCFSTargetChange_TargetChangeType_Add:
      return WatchTargetChangeState::Added;
    case GCFSTargetChange_TargetChangeType_Remove:
      return WatchTargetChangeState::Removed;
    case GCFSTargetChange_TargetChangeType_Current:
      return WatchTargetChangeState::Current;
    case GCFSTargetChange_TargetChangeType_Reset:
      return WatchTargetChangeState::Reset;
    default:
      HARD_FAIL("Unexpected TargetChange.state: %s", state);
  }
}

- (std::vector<TargetId>)decodedIntegerArray:(GPBInt32Array *)values {
  __block std::vector<TargetId> result;
  result.reserve(values.count);
  [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
    result.push_back(value);
  }];
  return result;
}

- (std::unique_ptr<WatchChange>)decodedDocumentChange:(GCFSDocumentChange *)change {
  ObjectValue value = [self decodedFields:change.document.fields];
  DocumentKey key = [self decodedDocumentKey:change.document.name];
  SnapshotVersion version = [self decodedVersion:change.document.updateTime];
  HARD_ASSERT(version != SnapshotVersion::None(), "Got a document change with no snapshot version");
  // The document may soon be re-serialized back to protos in order to store it in local
  // persistence. Memoize the encoded form to avoid encoding it again.
  FSTMaybeDocument *document = [FSTDocument documentWithData:value
                                                         key:key
                                                     version:version
                                                       state:DocumentState::kSynced
                                                       proto:change.document];

  std::vector<TargetId> updatedTargetIDs = [self decodedIntegerArray:change.targetIdsArray];
  std::vector<TargetId> removedTargetIDs = [self decodedIntegerArray:change.removedTargetIdsArray];

  return absl::make_unique<DocumentWatchChange>(
      std::move(updatedTargetIDs), std::move(removedTargetIDs), std::move(key), document);
}

- (std::unique_ptr<WatchChange>)decodedDocumentDelete:(GCFSDocumentDelete *)change {
  DocumentKey key = [self decodedDocumentKey:change.document];
  // Note that version might be unset in which case we use SnapshotVersion::None()
  SnapshotVersion version = [self decodedVersion:change.readTime];
  FSTMaybeDocument *document = [FSTDeletedDocument documentWithKey:key
                                                           version:version
                                             hasCommittedMutations:NO];

  std::vector<TargetId> removedTargetIDs = [self decodedIntegerArray:change.removedTargetIdsArray];

  return absl::make_unique<DocumentWatchChange>(
      std::vector<TargetId>{}, std::move(removedTargetIDs), std::move(key), document);
}

- (std::unique_ptr<WatchChange>)decodedDocumentRemove:(GCFSDocumentRemove *)change {
  DocumentKey key = [self decodedDocumentKey:change.document];
  std::vector<TargetId> removedTargetIDs = [self decodedIntegerArray:change.removedTargetIdsArray];

  return absl::make_unique<DocumentWatchChange>(std::vector<TargetId>{},
                                                std::move(removedTargetIDs), std::move(key), nil);
}

- (std::unique_ptr<WatchChange>)decodedExistenceFilterWatchChange:(GCFSExistenceFilter *)filter {
  ExistenceFilter existenceFilter{filter.count};
  TargetId targetID = filter.targetId;
  return absl::make_unique<ExistenceFilterWatchChange>(existenceFilter, targetID);
}

@end

NS_ASSUME_NONNULL_END
