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

#include <inttypes.h>

#import <GRPCClient/GRPCCall.h>
#import "FIRTimestamp.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Common.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Query.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Write.pbobjc.h"
#import "Firestore/Protos/objc/google/rpc/Status.pbobjc.h"
#import "Firestore/Protos/objc/google/type/Latlng.pbobjc.h"

#import "FIRFirestoreErrors.h"
#import "FIRGeoPoint.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Remote/FSTExistenceFilter.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;

NS_ASSUME_NONNULL_BEGIN

@interface FSTSerializerBeta ()
// Does not own this DatabaseId.
@property(nonatomic, assign, readonly) const DatabaseId *databaseID;
@end

@implementation FSTSerializerBeta

- (instancetype)initWithDatabaseID:(const DatabaseId *)databaseID {
  self = [super init];
  if (self) {
    _databaseID = databaseID;
  }
  return self;
}

#pragma mark - FSTSnapshotVersion <=> GPBTimestamp

- (GPBTimestamp *)encodedTimestamp:(FIRTimestamp *)timestamp {
  GPBTimestamp *result = [GPBTimestamp message];
  result.seconds = timestamp.seconds;
  result.nanos = timestamp.nanoseconds;
  return result;
}

- (FIRTimestamp *)decodedTimestamp:(GPBTimestamp *)timestamp {
  return [[FIRTimestamp alloc] initWithSeconds:timestamp.seconds nanoseconds:timestamp.nanos];
}

- (GPBTimestamp *)encodedVersion:(FSTSnapshotVersion *)version {
  return [self encodedTimestamp:version.timestamp];
}

- (FSTSnapshotVersion *)decodedVersion:(GPBTimestamp *)version {
  return [FSTSnapshotVersion versionWithTimestamp:[self decodedTimestamp:version]];
}

#pragma mark - FIRGeoPoint <=> GTPLatLng

- (GTPLatLng *)encodedGeoPoint:(FIRGeoPoint *)geoPoint {
  GTPLatLng *latLng = [GTPLatLng message];
  latLng.latitude = geoPoint.latitude;
  latLng.longitude = geoPoint.longitude;
  return latLng;
}

- (FIRGeoPoint *)decodedGeoPoint:(GTPLatLng *)latLng {
  return [[FIRGeoPoint alloc] initWithLatitude:latLng.latitude longitude:latLng.longitude];
}

#pragma mark - FSTDocumentKey <=> Key proto

- (NSString *)encodedDocumentKey:(FSTDocumentKey *)key {
  return [self encodedResourcePathForDatabaseID:self.databaseID path:key.path];
}

- (FSTDocumentKey *)decodedDocumentKey:(NSString *)name {
  FSTResourcePath *path = [self decodedResourcePathWithDatabaseID:name];
  FSTAssert([[path segmentAtIndex:1]
                isEqualToString:util::WrapNSStringNoCopy(self.databaseID->project_id())],
            @"Tried to deserialize key from different project.");
  FSTAssert([[path segmentAtIndex:3]
                isEqualToString:util::WrapNSStringNoCopy(self.databaseID->database_id())],
            @"Tried to deserialize key from different datbase.");
  return [FSTDocumentKey keyWithPath:[self localResourcePathForQualifiedResourcePath:path]];
}

- (NSString *)encodedResourcePathForDatabaseID:(const DatabaseId *)databaseID
                                          path:(FSTResourcePath *)path {
  return [[[[self encodedResourcePathForDatabaseID:databaseID] pathByAppendingSegment:@"documents"]
      pathByAppendingPath:path] canonicalString];
}

- (FSTResourcePath *)decodedResourcePathWithDatabaseID:(NSString *)name {
  FSTResourcePath *path = [FSTResourcePath pathWithString:name];
  FSTAssert([self validQualifiedResourcePath:path], @"Tried to deserialize invalid key %@", path);
  return path;
}

- (NSString *)encodedQueryPath:(FSTResourcePath *)path {
  if (path.length == 0) {
    // If the path is empty, the backend requires we leave off the /documents at the end.
    return [self encodedDatabaseID];
  }
  return [self encodedResourcePathForDatabaseID:self.databaseID path:path];
}

- (FSTResourcePath *)decodedQueryPath:(NSString *)name {
  FSTResourcePath *resource = [self decodedResourcePathWithDatabaseID:name];
  if (resource.length == 4) {
    return [FSTResourcePath pathWithSegments:@[]];
  } else {
    return [self localResourcePathForQualifiedResourcePath:resource];
  }
}

- (FSTResourcePath *)encodedResourcePathForDatabaseID:(const DatabaseId *)databaseID {
  return [FSTResourcePath pathWithSegments:@[
    @"projects", util::WrapNSStringNoCopy(databaseID->project_id()), @"databases",
    util::WrapNSStringNoCopy(databaseID->database_id())
  ]];
}

- (FSTResourcePath *)localResourcePathForQualifiedResourcePath:(FSTResourcePath *)resourceName {
  FSTAssert(
      resourceName.length > 4 && [[resourceName segmentAtIndex:4] isEqualToString:@"documents"],
      @"Tried to deserialize invalid key %@", resourceName);
  return [resourceName pathByRemovingFirstSegments:5];
}

- (BOOL)validQualifiedResourcePath:(FSTResourcePath *)path {
  return path.length >= 4 && [[path segmentAtIndex:0] isEqualToString:@"projects"] &&
         [[path segmentAtIndex:2] isEqualToString:@"databases"];
}

- (NSString *)encodedDatabaseID {
  return [[self encodedResourcePathForDatabaseID:self.databaseID] canonicalString];
}

#pragma mark - FSTFieldValue <=> Value proto

- (GCFSValue *)encodedFieldValue:(FSTFieldValue *)fieldValue {
  Class fieldClass = [fieldValue class];
  if (fieldClass == [FSTNullValue class]) {
    return [self encodedNull];

  } else if (fieldClass == [FSTBooleanValue class]) {
    return [self encodedBool:[[fieldValue value] boolValue]];

  } else if (fieldClass == [FSTIntegerValue class]) {
    return [self encodedInteger:[[fieldValue value] longLongValue]];

  } else if (fieldClass == [FSTDoubleValue class]) {
    return [self encodedDouble:[[fieldValue value] doubleValue]];

  } else if (fieldClass == [FSTStringValue class]) {
    return [self encodedString:[fieldValue value]];

  } else if (fieldClass == [FSTTimestampValue class]) {
    return [self encodedTimestampValue:((FSTTimestampValue *)fieldValue).internalValue];

  } else if (fieldClass == [FSTGeoPointValue class]) {
    return [self encodedGeoPointValue:[fieldValue value]];

  } else if (fieldClass == [FSTBlobValue class]) {
    return [self encodedBlobValue:[fieldValue value]];

  } else if (fieldClass == [FSTReferenceValue class]) {
    FSTReferenceValue *ref = (FSTReferenceValue *)fieldValue;
    return [self encodedReferenceValueForDatabaseID:[ref databaseID] key:[ref value]];

  } else if (fieldClass == [FSTObjectValue class]) {
    GCFSValue *result = [GCFSValue message];
    result.mapValue = [self encodedMapValue:(FSTObjectValue *)fieldValue];
    return result;

  } else if (fieldClass == [FSTArrayValue class]) {
    GCFSValue *result = [GCFSValue message];
    result.arrayValue = [self encodedArrayValue:(FSTArrayValue *)fieldValue];
    return result;

  } else {
    FSTFail(@"Unhandled type %@ on %@", NSStringFromClass([fieldValue class]), fieldValue);
  }
}

- (FSTFieldValue *)decodedFieldValue:(GCFSValue *)valueProto {
  switch (valueProto.valueTypeOneOfCase) {
    case GCFSValue_ValueType_OneOfCase_NullValue:
      return [FSTNullValue nullValue];

    case GCFSValue_ValueType_OneOfCase_BooleanValue:
      return [FSTBooleanValue booleanValue:valueProto.booleanValue];

    case GCFSValue_ValueType_OneOfCase_IntegerValue:
      return [FSTIntegerValue integerValue:valueProto.integerValue];

    case GCFSValue_ValueType_OneOfCase_DoubleValue:
      return [FSTDoubleValue doubleValue:valueProto.doubleValue];

    case GCFSValue_ValueType_OneOfCase_StringValue:
      return [FSTStringValue stringValue:valueProto.stringValue];

    case GCFSValue_ValueType_OneOfCase_TimestampValue:
      return [FSTTimestampValue timestampValue:[self decodedTimestamp:valueProto.timestampValue]];

    case GCFSValue_ValueType_OneOfCase_GeoPointValue:
      return [FSTGeoPointValue geoPointValue:[self decodedGeoPoint:valueProto.geoPointValue]];

    case GCFSValue_ValueType_OneOfCase_BytesValue:
      return [FSTBlobValue blobValue:valueProto.bytesValue];

    case GCFSValue_ValueType_OneOfCase_ReferenceValue:
      return [self decodedReferenceValue:valueProto.referenceValue];

    case GCFSValue_ValueType_OneOfCase_ArrayValue:
      return [self decodedArrayValue:valueProto.arrayValue];

    case GCFSValue_ValueType_OneOfCase_MapValue:
      return [self decodedMapValue:valueProto.mapValue];

    default:
      FSTFail(@"Unhandled type %d on %@", valueProto.valueTypeOneOfCase, valueProto);
  }
}

- (GCFSValue *)encodedNull {
  GCFSValue *result = [GCFSValue message];
  result.nullValue = GPBNullValue_NullValue;
  return result;
}

- (GCFSValue *)encodedBool:(BOOL)value {
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

- (GCFSValue *)encodedString:(NSString *)value {
  GCFSValue *result = [GCFSValue message];
  result.stringValue = value;
  return result;
}

- (GCFSValue *)encodedTimestampValue:(FIRTimestamp *)value {
  GCFSValue *result = [GCFSValue message];
  result.timestampValue = [self encodedTimestamp:value];
  return result;
}

- (GCFSValue *)encodedGeoPointValue:(FIRGeoPoint *)value {
  GCFSValue *result = [GCFSValue message];
  result.geoPointValue = [self encodedGeoPoint:value];
  return result;
}

- (GCFSValue *)encodedBlobValue:(NSData *)value {
  GCFSValue *result = [GCFSValue message];
  result.bytesValue = value;
  return result;
}

- (GCFSValue *)encodedReferenceValueForDatabaseID:(const DatabaseId *)databaseID
                                              key:(FSTDocumentKey *)key {
  FSTAssert(*databaseID == *self.databaseID, @"Database %@:%@ cannot encode reference from %@:%@",
            util::WrapNSStringNoCopy(self.databaseID->project_id()),
            util::WrapNSStringNoCopy(self.databaseID->database_id()),
            util::WrapNSStringNoCopy(databaseID->project_id()),
            util::WrapNSStringNoCopy(databaseID->database_id()));
  GCFSValue *result = [GCFSValue message];
  result.referenceValue = [self encodedResourcePathForDatabaseID:databaseID path:key.path];
  return result;
}

- (FSTReferenceValue *)decodedReferenceValue:(NSString *)resourceName {
  FSTResourcePath *path = [self decodedResourcePathWithDatabaseID:resourceName];
  NSString *project = [path segmentAtIndex:1];
  NSString *database = [path segmentAtIndex:3];
  FSTDocumentKey *key =
      [FSTDocumentKey keyWithPath:[self localResourcePathForQualifiedResourcePath:path]];

  const DatabaseId database_id(util::MakeStringView(project), util::MakeStringView(database));
  FSTAssert(database_id == *self.databaseID, @"Database %@:%@ cannot encode reference from %@:%@",
            util::WrapNSStringNoCopy(self.databaseID->project_id()),
            util::WrapNSStringNoCopy(self.databaseID->database_id()),
            util::WrapNSStringNoCopy(database_id.project_id()),
            util::WrapNSStringNoCopy(database_id.database_id()));
  return [FSTReferenceValue referenceValue:key databaseID:self.databaseID];
}

- (GCFSArrayValue *)encodedArrayValue:(FSTArrayValue *)arrayValue {
  GCFSArrayValue *proto = [GCFSArrayValue message];
  NSMutableArray<GCFSValue *> *protoContents = [proto valuesArray];

  [[arrayValue internalValue]
      enumerateObjectsUsingBlock:^(FSTFieldValue *value, NSUInteger idx, BOOL *stop) {
        GCFSValue *converted = [self encodedFieldValue:value];
        [protoContents addObject:converted];
      }];
  return proto;
}

- (FSTArrayValue *)decodedArrayValue:(GCFSArrayValue *)arrayValue {
  NSMutableArray<FSTFieldValue *> *contents =
      [NSMutableArray arrayWithCapacity:arrayValue.valuesArray_Count];

  [arrayValue.valuesArray
      enumerateObjectsUsingBlock:^(GCFSValue *value, NSUInteger idx, BOOL *stop) {
        [contents addObject:[self decodedFieldValue:value]];
      }];
  return [[FSTArrayValue alloc] initWithValueNoCopy:contents];
}

- (GCFSMapValue *)encodedMapValue:(FSTObjectValue *)value {
  GCFSMapValue *result = [GCFSMapValue message];
  result.fields = [self encodedFields:value];
  return result;
}

- (FSTObjectValue *)decodedMapValue:(GCFSMapValue *)map {
  return [self decodedFields:map.fields];
}

/**
 * Encodes an FSTObjectValue into a dictionary.
 * @return a new dictionary that can be assigned to a field in another proto.
 */
- (NSMutableDictionary<NSString *, GCFSValue *> *)encodedFields:(FSTObjectValue *)value {
  FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *fields = value.internalValue;
  NSMutableDictionary<NSString *, GCFSValue *> *result = [NSMutableDictionary dictionary];
  [fields enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *obj, BOOL *stop) {
    GCFSValue *converted = [self encodedFieldValue:obj];
    result[key] = converted;
  }];
  return result;
}

- (FSTObjectValue *)decodedFields:(NSDictionary<NSString *, GCFSValue *> *)fields {
  __block FSTObjectValue *result = [FSTObjectValue objectValue];
  [fields enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, GCFSValue *_Nonnull obj,
                                              BOOL *_Nonnull stop) {
    FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ key ]];
    FSTFieldValue *value = [self decodedFieldValue:obj];
    result = [result objectBySettingValue:value forPath:path];
  }];
  return result;
}

#pragma mark - FSTObjectValue <=> Document proto

- (GCFSDocument *)encodedDocumentWithFields:(FSTObjectValue *)objectValue
                                        key:(FSTDocumentKey *)key {
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
      FSTFail(@"Unknown document type: %@", response);
  }
}

- (FSTDocument *)decodedFoundDocument:(GCFSBatchGetDocumentsResponse *)response {
  FSTAssert(!!response.found, @"Tried to deserialize a found document from a deleted document.");
  FSTDocumentKey *key = [self decodedDocumentKey:response.found.name];
  FSTObjectValue *value = [self decodedFields:response.found.fields];
  FSTSnapshotVersion *version = [self decodedVersion:response.found.updateTime];
  FSTAssert(![version isEqual:[FSTSnapshotVersion noVersion]],
            @"Got a document response with no snapshot version");

  return [FSTDocument documentWithData:value key:key version:version hasLocalMutations:NO];
}

- (FSTDeletedDocument *)decodedDeletedDocument:(GCFSBatchGetDocumentsResponse *)response {
  FSTAssert(!!response.missing, @"Tried to deserialize a deleted document from a found document.");
  FSTDocumentKey *key = [self decodedDocumentKey:response.missing];
  FSTSnapshotVersion *version = [self decodedVersion:response.readTime];
  FSTAssert(![version isEqual:[FSTSnapshotVersion noVersion]],
            @"Got a no document response with no snapshot version");
  return [FSTDeletedDocument documentWithKey:key version:version];
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
    proto.updateMask = [self encodedFieldMask:patch.fieldMask];

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
    FSTFail(@"Unknown mutation type %@", NSStringFromClass(mutationClass));
  }

  if (!mutation.precondition.isNone) {
    proto.currentDocument = [self encodedPrecondition:mutation.precondition];
  }

  return proto;
}

- (FSTMutation *)decodedMutation:(GCFSWrite *)mutation {
  FSTPrecondition *precondition = [mutation hasCurrentDocument]
                                      ? [self decodedPrecondition:mutation.currentDocument]
                                      : [FSTPrecondition none];

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
      FSTPreconditionExists exists = precondition.exists;
      FSTAssert(exists == FSTPreconditionExistsYes,
                @"Transforms must have precondition \"exists == true\"");

      return [[FSTTransformMutation alloc]
              initWithKey:[self decodedDocumentKey:mutation.transform.document]
          fieldTransforms:[self decodedFieldTransforms:mutation.transform.fieldTransformsArray]];
    }

    default:
      // Note that insert is intentionally unhandled, since we don't ever deal in them.
      FSTFail(@"Unknown mutation operation: %d", mutation.operationOneOfCase);
  }
}

- (GCFSPrecondition *)encodedPrecondition:(FSTPrecondition *)precondition {
  FSTAssert(!precondition.isNone, @"Can't serialize an empty precondition");
  GCFSPrecondition *message = [GCFSPrecondition message];
  if (precondition.updateTime) {
    message.updateTime = [self encodedVersion:precondition.updateTime];
  } else if (precondition.exists != FSTPreconditionExistsNotSet) {
    message.exists = precondition.exists == FSTPreconditionExistsYes;
  } else {
    FSTFail(@"Unknown precondition: %@", precondition);
  }
  return message;
}

- (FSTPrecondition *)decodedPrecondition:(GCFSPrecondition *)precondition {
  switch (precondition.conditionTypeOneOfCase) {
    case GCFSPrecondition_ConditionType_OneOfCase_GPBUnsetOneOfCase:
      return [FSTPrecondition none];

    case GCFSPrecondition_ConditionType_OneOfCase_Exists:
      return [FSTPrecondition preconditionWithExists:precondition.exists];

    case GCFSPrecondition_ConditionType_OneOfCase_UpdateTime:
      return [FSTPrecondition
          preconditionWithUpdateTime:[self decodedVersion:precondition.updateTime]];

    default:
      FSTFail(@"Unrecognized Precondition one-of case %@", precondition);
  }
}

- (GCFSDocumentMask *)encodedFieldMask:(FSTFieldMask *)fieldMask {
  GCFSDocumentMask *mask = [GCFSDocumentMask message];
  for (FSTFieldPath *field in fieldMask.fields) {
    [mask.fieldPathsArray addObject:field.canonicalString];
  }
  return mask;
}

- (FSTFieldMask *)decodedFieldMask:(GCFSDocumentMask *)fieldMask {
  NSMutableArray<FSTFieldPath *> *fields =
      [NSMutableArray arrayWithCapacity:fieldMask.fieldPathsArray_Count];
  for (NSString *path in fieldMask.fieldPathsArray) {
    [fields addObject:[FSTFieldPath pathWithServerFormat:path]];
  }
  return [[FSTFieldMask alloc] initWithFields:fields];
}

- (NSMutableArray<GCFSDocumentTransform_FieldTransform *> *)encodedFieldTransforms:
    (NSArray<FSTFieldTransform *> *)fieldTransforms {
  NSMutableArray *protos = [NSMutableArray array];
  for (FSTFieldTransform *fieldTransform in fieldTransforms) {
    FSTAssert([fieldTransform.transform isKindOfClass:[FSTServerTimestampTransform class]],
              @"Unknown transform: %@", fieldTransform.transform);
    GCFSDocumentTransform_FieldTransform *proto = [GCFSDocumentTransform_FieldTransform message];
    proto.fieldPath = fieldTransform.path.canonicalString;
    proto.setToServerValue = GCFSDocumentTransform_FieldTransform_ServerValue_RequestTime;
    [protos addObject:proto];
  }
  return protos;
}

- (NSArray<FSTFieldTransform *> *)decodedFieldTransforms:
    (NSArray<GCFSDocumentTransform_FieldTransform *> *)protos {
  NSMutableArray<FSTFieldTransform *> *fieldTransforms = [NSMutableArray array];
  for (GCFSDocumentTransform_FieldTransform *proto in protos) {
    FSTAssert(
        proto.setToServerValue == GCFSDocumentTransform_FieldTransform_ServerValue_RequestTime,
        @"Unknown transform setToServerValue: %d", proto.setToServerValue);
    [fieldTransforms
        addObject:[[FSTFieldTransform alloc]
                      initWithPath:[FSTFieldPath pathWithServerFormat:proto.fieldPath]
                         transform:[FSTServerTimestampTransform serverTimestampTransform]]];
  }
  return fieldTransforms;
}

#pragma mark - FSTMutationResult <= GCFSWriteResult proto

- (FSTMutationResult *)decodedMutationResult:(GCFSWriteResult *)mutation {
  // NOTE: Deletes don't have an updateTime.
  FSTSnapshotVersion *_Nullable version =
      mutation.updateTime ? [self decodedVersion:mutation.updateTime] : nil;
  NSMutableArray *_Nullable transformResults = nil;
  if (mutation.transformResultsArray.count > 0) {
    transformResults = [NSMutableArray array];
    for (GCFSValue *result in mutation.transformResultsArray) {
      [transformResults addObject:[self decodedFieldValue:result]];
    }
  }
  return [[FSTMutationResult alloc] initWithVersion:version transformResults:transformResults];
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
      FSTFail(@"Unrecognized query purpose: %lu", (unsigned long)purpose);
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
  FSTAssert(documents.count == 1, @"DocumentsTarget contained other than 1 document %lu",
            (unsigned long)documents.count);

  NSString *name = documents[0];
  return [FSTQuery queryWithPath:[self decodedQueryPath:name]];
}

- (GCFSTarget_QueryTarget *)encodedQueryTarget:(FSTQuery *)query {
  // Dissect the path into parent, collectionId, and optional key filter.
  GCFSTarget_QueryTarget *queryTarget = [GCFSTarget_QueryTarget message];
  if (query.path.length == 0) {
    queryTarget.parent = [self encodedQueryPath:query.path];
  } else {
    FSTResourcePath *path = query.path;
    FSTAssert(path.length % 2 != 0, @"Document queries with filters are not supported.");
    queryTarget.parent = [self encodedQueryPath:[path pathByRemovingLastSegment]];
    GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
    from.collectionId = path.lastSegment;
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

  if (query.limit != NSNotFound) {
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
  FSTResourcePath *path = [self decodedQueryPath:target.parent];

  GCFSStructuredQuery *query = target.structuredQuery;
  NSUInteger fromCount = query.fromArray_Count;
  if (fromCount > 0) {
    FSTAssert(fromCount == 1,
              @"StructuredQuery.from with more than one collection is not supported.");

    GCFSStructuredQuery_CollectionSelector *from = query.fromArray[0];
    path = [path pathByAppendingSegment:from.collectionId];
  }

  NSArray<id<FSTFilter>> *filterBy;
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

  NSInteger limit = NSNotFound;
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
                               filterBy:filterBy
                                orderBy:orderBy
                                  limit:limit
                                startAt:startAt
                                  endAt:endAt];
}

#pragma mark Filters

- (GCFSStructuredQuery_Filter *_Nullable)encodedFilters:(NSArray<id<FSTFilter>> *)filters {
  if (filters.count == 0) {
    return nil;
  }
  NSMutableArray<GCFSStructuredQuery_Filter *> *protos = [NSMutableArray array];
  for (id<FSTFilter> filter in filters) {
    if ([filter isKindOfClass:[FSTRelationFilter class]]) {
      [protos addObject:[self encodedRelationFilter:filter]];
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

- (NSArray<id<FSTFilter>> *)decodedFilters:(GCFSStructuredQuery_Filter *)proto {
  NSMutableArray<id<FSTFilter>> *result = [NSMutableArray array];

  NSArray<GCFSStructuredQuery_Filter *> *filters;
  if (proto.filterTypeOneOfCase ==
      GCFSStructuredQuery_Filter_FilterType_OneOfCase_CompositeFilter) {
    FSTAssert(proto.compositeFilter.op == GCFSStructuredQuery_CompositeFilter_Operator_And,
              @"Only AND-type composite filters are supported, got %d", proto.compositeFilter.op);
    filters = proto.compositeFilter.filtersArray;
  } else {
    filters = @[ proto ];
  }

  for (GCFSStructuredQuery_Filter *filter in filters) {
    switch (filter.filterTypeOneOfCase) {
      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_CompositeFilter:
        FSTFail(@"Nested composite filters are not supported");

      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_FieldFilter:
        [result addObject:[self decodedRelationFilter:filter.fieldFilter]];
        break;

      case GCFSStructuredQuery_Filter_FilterType_OneOfCase_UnaryFilter:
        [result addObject:[self decodedUnaryFilter:filter.unaryFilter]];
        break;

      default:
        FSTFail(@"Unrecognized Filter.filterType %d", filter.filterTypeOneOfCase);
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
  FSTFieldPath *fieldPath = [FSTFieldPath pathWithServerFormat:proto.field.fieldPath];
  FSTRelationFilterOperator filterOperator = [self decodedRelationFilterOperator:proto.op];
  FSTFieldValue *value = [self decodedFieldValue:proto.value];
  return [FSTRelationFilter filterWithField:fieldPath filterOperator:filterOperator value:value];
}

- (GCFSStructuredQuery_Filter *)encodedUnaryFilter:(id<FSTFilter>)filter {
  GCFSStructuredQuery_Filter *proto = [GCFSStructuredQuery_Filter message];
  proto.unaryFilter.field = [self encodedFieldPath:filter.field];
  if ([filter isKindOfClass:[FSTNanFilter class]]) {
    proto.unaryFilter.op = GCFSStructuredQuery_UnaryFilter_Operator_IsNan;
  } else if ([filter isKindOfClass:[FSTNullFilter class]]) {
    proto.unaryFilter.op = GCFSStructuredQuery_UnaryFilter_Operator_IsNull;
  } else {
    FSTFail(@"Unrecognized filter: %@", filter);
  }
  return proto;
}

- (id<FSTFilter>)decodedUnaryFilter:(GCFSStructuredQuery_UnaryFilter *)proto {
  FSTFieldPath *field = [FSTFieldPath pathWithServerFormat:proto.field.fieldPath];
  switch (proto.op) {
    case GCFSStructuredQuery_UnaryFilter_Operator_IsNan:
      return [[FSTNanFilter alloc] initWithField:field];

    case GCFSStructuredQuery_UnaryFilter_Operator_IsNull:
      return [[FSTNullFilter alloc] initWithField:field];

    default:
      FSTFail(@"Unrecognized UnaryFilter.operator %d", proto.op);
  }
}

- (GCFSStructuredQuery_FieldReference *)encodedFieldPath:(FSTFieldPath *)fieldPath {
  GCFSStructuredQuery_FieldReference *ref = [GCFSStructuredQuery_FieldReference message];
  ref.fieldPath = fieldPath.canonicalString;
  return ref;
}

- (GCFSStructuredQuery_FieldFilter_Operator)encodedRelationFilterOperator:
    (FSTRelationFilterOperator)filterOperator {
  switch (filterOperator) {
    case FSTRelationFilterOperatorLessThan:
      return GCFSStructuredQuery_FieldFilter_Operator_LessThan;
    case FSTRelationFilterOperatorLessThanOrEqual:
      return GCFSStructuredQuery_FieldFilter_Operator_LessThanOrEqual;
    case FSTRelationFilterOperatorEqual:
      return GCFSStructuredQuery_FieldFilter_Operator_Equal;
    case FSTRelationFilterOperatorGreaterThanOrEqual:
      return GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual;
    case FSTRelationFilterOperatorGreaterThan:
      return GCFSStructuredQuery_FieldFilter_Operator_GreaterThan;
    default:
      FSTFail(@"Unhandled FSTRelationFilterOperator: %ld", (long)filterOperator);
  }
}

- (FSTRelationFilterOperator)decodedRelationFilterOperator:
    (GCFSStructuredQuery_FieldFilter_Operator)filterOperator {
  switch (filterOperator) {
    case GCFSStructuredQuery_FieldFilter_Operator_LessThan:
      return FSTRelationFilterOperatorLessThan;
    case GCFSStructuredQuery_FieldFilter_Operator_LessThanOrEqual:
      return FSTRelationFilterOperatorLessThanOrEqual;
    case GCFSStructuredQuery_FieldFilter_Operator_Equal:
      return FSTRelationFilterOperatorEqual;
    case GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual:
      return FSTRelationFilterOperatorGreaterThanOrEqual;
    case GCFSStructuredQuery_FieldFilter_Operator_GreaterThan:
      return FSTRelationFilterOperatorGreaterThan;
    default:
      FSTFail(@"Unhandled FieldFilter.operator: %d", filterOperator);
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
  FSTFieldPath *fieldPath = [FSTFieldPath pathWithServerFormat:proto.field.fieldPath];
  BOOL ascending;
  switch (proto.direction) {
    case GCFSStructuredQuery_Direction_Ascending:
      ascending = YES;
      break;
    case GCFSStructuredQuery_Direction_Descending:
      ascending = NO;
      break;
    default:
      FSTFail(@"Unrecognized GCFSStructuredQuery_Direction %d", proto.direction);
  }
  return [FSTSortOrder sortOrderWithFieldPath:fieldPath ascending:ascending];
}

#pragma mark - Bounds/Cursors

- (GCFSCursor *)encodedBound:(FSTBound *)bound {
  GCFSCursor *proto = [GCFSCursor message];
  proto.before = bound.isBefore;
  for (FSTFieldValue *fieldValue in bound.position) {
    GCFSValue *value = [self encodedFieldValue:fieldValue];
    [proto.valuesArray addObject:value];
  }
  return proto;
}

- (FSTBound *)decodedBound:(GCFSCursor *)proto {
  NSMutableArray<FSTFieldValue *> *indexComponents = [NSMutableArray array];

  for (GCFSValue *valueProto in proto.valuesArray) {
    FSTFieldValue *value = [self decodedFieldValue:valueProto];
    [indexComponents addObject:value];
  }

  return [FSTBound boundWithPosition:indexComponents isBefore:proto.before];
}

#pragma mark - FSTWatchChange <= GCFSListenResponse proto

- (FSTWatchChange *)decodedWatchChange:(GCFSListenResponse *)watchChange {
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
      FSTFail(@"Unknown WatchChange.changeType %" PRId32, watchChange.responseTypeOneOfCase);
  }
}

- (FSTSnapshotVersion *)versionFromListenResponse:(GCFSListenResponse *)watchChange {
  // We have only reached a consistent snapshot for the entire stream if there is a read_time set
  // and it applies to all targets (i.e. the list of targets is empty). The backend is guaranteed to
  // send such responses.
  if (watchChange.responseTypeOneOfCase != GCFSListenResponse_ResponseType_OneOfCase_TargetChange) {
    return [FSTSnapshotVersion noVersion];
  }
  if (watchChange.targetChange.targetIdsArray.count != 0) {
    return [FSTSnapshotVersion noVersion];
  }
  return [self decodedVersion:watchChange.targetChange.readTime];
}

- (FSTWatchTargetChange *)decodedTargetChangeFromWatchChange:(GCFSTargetChange *)change {
  FSTWatchTargetChangeState state = [self decodedWatchTargetChangeState:change.targetChangeType];
  NSMutableArray<NSNumber *> *targetIDs =
      [NSMutableArray arrayWithCapacity:change.targetIdsArray_Count];

  [change.targetIdsArray enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
    [targetIDs addObject:@(value)];
  }];

  NSError *cause = nil;
  if (change.hasCause) {
    cause = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                code:change.cause.code
                            userInfo:@{NSLocalizedDescriptionKey : change.cause.message}];
  }

  return [[FSTWatchTargetChange alloc] initWithState:state
                                           targetIDs:targetIDs
                                         resumeToken:change.resumeToken
                                               cause:cause];
}

- (FSTWatchTargetChangeState)decodedWatchTargetChangeState:
    (GCFSTargetChange_TargetChangeType)state {
  switch (state) {
    case GCFSTargetChange_TargetChangeType_NoChange:
      return FSTWatchTargetChangeStateNoChange;
    case GCFSTargetChange_TargetChangeType_Add:
      return FSTWatchTargetChangeStateAdded;
    case GCFSTargetChange_TargetChangeType_Remove:
      return FSTWatchTargetChangeStateRemoved;
    case GCFSTargetChange_TargetChangeType_Current:
      return FSTWatchTargetChangeStateCurrent;
    case GCFSTargetChange_TargetChangeType_Reset:
      return FSTWatchTargetChangeStateReset;
    default:
      FSTFail(@"Unexpected TargetChange.state: %" PRId32, state);
  }
}

- (NSArray<NSNumber *> *)decodedIntegerArray:(GPBInt32Array *)values {
  NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:values.count];
  [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
    [result addObject:@(value)];
  }];
  return result;
}

- (FSTDocumentWatchChange *)decodedDocumentChange:(GCFSDocumentChange *)change {
  FSTObjectValue *value = [self decodedFields:change.document.fields];
  FSTDocumentKey *key = [self decodedDocumentKey:change.document.name];
  FSTSnapshotVersion *version = [self decodedVersion:change.document.updateTime];
  FSTAssert(![version isEqual:[FSTSnapshotVersion noVersion]],
            @"Got a document change with no snapshot version");
  FSTMaybeDocument *document =
      [FSTDocument documentWithData:value key:key version:version hasLocalMutations:NO];

  NSArray<NSNumber *> *updatedTargetIds = [self decodedIntegerArray:change.targetIdsArray];
  NSArray<NSNumber *> *removedTargetIds = [self decodedIntegerArray:change.removedTargetIdsArray];

  return [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:updatedTargetIds
                                                 removedTargetIDs:removedTargetIds
                                                      documentKey:document.key
                                                         document:document];
}

- (FSTDocumentWatchChange *)decodedDocumentDelete:(GCFSDocumentDelete *)change {
  FSTDocumentKey *key = [self decodedDocumentKey:change.document];
  // Note that version might be unset in which case we use [FSTSnapshotVersion noVersion]
  FSTSnapshotVersion *version = [self decodedVersion:change.readTime];
  FSTMaybeDocument *document = [FSTDeletedDocument documentWithKey:key version:version];

  NSArray<NSNumber *> *removedTargetIds = [self decodedIntegerArray:change.removedTargetIdsArray];

  return [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                                 removedTargetIDs:removedTargetIds
                                                      documentKey:document.key
                                                         document:document];
}

- (FSTDocumentWatchChange *)decodedDocumentRemove:(GCFSDocumentRemove *)change {
  FSTDocumentKey *key = [self decodedDocumentKey:change.document];
  NSArray<NSNumber *> *removedTargetIds = [self decodedIntegerArray:change.removedTargetIdsArray];

  return [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                                 removedTargetIDs:removedTargetIds
                                                      documentKey:key
                                                         document:nil];
}

- (FSTExistenceFilterWatchChange *)decodedExistenceFilterWatchChange:(GCFSExistenceFilter *)filter {
  // TODO(dimond): implement existence filter parsing
  FSTExistenceFilter *existenceFilter = [FSTExistenceFilter filterWithCount:filter.count];
  FSTTargetID targetID = filter.targetId;
  return [FSTExistenceFilterWatchChange changeWithFilter:existenceFilter targetID:targetID];
}

@end

NS_ASSUME_NONNULL_END
