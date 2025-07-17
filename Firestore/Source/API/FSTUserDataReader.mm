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

#import <FirebaseCore/FIRTimestamp.h>

#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FSTUserDataReader.h"

#import "FIRBSONBinaryData.h"
#import "FIRBSONObjectId.h"
#import "FIRBSONTimestamp.h"
#import "FIRDecimal128Value.h"
#import "FIRGeoPoint.h"
#import "FIRInt32Value.h"
#import "FIRMaxKey.h"
#import "FIRMinKey.h"
#import "FIRRegexValue.h"
#import "FIRVectorValue.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRGeoPoint+Internal.h"
#import "Firestore/Source/API/converters.h"
#import "Firestore/core/include/firebase/firestore/geo_point.h"

#include "Firestore/core/src/core/user_data.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_transform.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/timestamp_internal.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/read_context.h"
#include "Firestore/core/src/util/string_apple.h"

#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "absl/types/optional.h"

namespace nanopb = firebase::firestore::nanopb;
using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::GeoPoint;
using firebase::firestore::google_firestore_v1_ArrayValue;
using firebase::firestore::google_firestore_v1_MapValue;
using firebase::firestore::google_firestore_v1_MapValue_FieldsEntry;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::google_protobuf_NullValue_NULL_VALUE;
using firebase::firestore::google_protobuf_Timestamp;
using firebase::firestore::google_type_LatLng;
using firebase::firestore::core::ParseAccumulator;
using firebase::firestore::core::ParseContext;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::core::UserDataSource;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DeepClone;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::NullValue;
using firebase::firestore::model::NumericIncrementTransform;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::nanopb::CheckedSize;
using firebase::firestore::nanopb::Message;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::ReadContext;
using firebase::firestore::util::ThrowInvalidArgument;
using nanopb::StringReader;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDocumentKeyReference

@implementation FSTDocumentKeyReference {
  DocumentKey _key;
  DatabaseId _databaseID;
}

- (instancetype)initWithKey:(DocumentKey)key databaseID:(DatabaseId)databaseID {
  self = [super init];
  if (self) {
    _key = std::move(key);
    _databaseID = std::move(databaseID);
  }
  return self;
}

- (const model::DocumentKey &)key {
  return _key;
}

- (const model::DatabaseId &)databaseID {
  return _databaseID;
}

@end

#pragma mark - FSTUserDataReader

@interface FSTUserDataReader ()
@property(strong, nonatomic, readonly) FSTPreConverterBlock preConverter;
@end

@implementation FSTUserDataReader {
  DatabaseId _databaseID;
}

- (instancetype)initWithDatabaseID:(DatabaseId)databaseID
                      preConverter:(FSTPreConverterBlock)preConverter {
  self = [super init];
  if (self) {
    _databaseID = std::move(databaseID);
    _preConverter = preConverter;
  }
  return self;
}

- (ParsedSetData)parsedSetData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::Set};
  auto updateData = [self parseData:input context:accumulator.RootContext()];
  HARD_ASSERT(updateData.has_value(), "Parsed data should not be nil.");

  return std::move(accumulator).SetData(ObjectValue{std::move(*updateData)});
}

- (ParsedSetData)parsedMergeData:(id)input fieldMask:(nullable NSArray<id> *)fieldMask {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::MergeSet};

  auto updateData = [self parseData:input context:accumulator.RootContext()];
  HARD_ASSERT(updateData.has_value(), "Parsed data should not be nil.");

  ObjectValue updateObject{std::move(*updateData)};

  if (fieldMask) {
    std::set<FieldPath> validatedFieldPaths;
    for (id fieldPath in fieldMask) {
      FieldPath path;

      if ([fieldPath isKindOfClass:[NSString class]]) {
        path = FieldPath::FromDotSeparatedString(MakeString(fieldPath));
      } else if ([fieldPath isKindOfClass:[FIRFieldPath class]]) {
        path = static_cast<FIRFieldPath *>(fieldPath).internalValue;
      } else {
        ThrowInvalidArgument("All elements in mergeFields: must be NSStrings or FIRFieldPaths.");
      }

      // Verify that all elements specified in the field mask are part of the parsed context.
      if (!accumulator.Contains(path)) {
        ThrowInvalidArgument(
            "Field '%s' is specified in your field mask but missing from your input data.",
            path.CanonicalString());
      }

      validatedFieldPaths.insert(path);
    }

    return std::move(accumulator)
        .MergeData(std::move(updateObject), FieldMask{std::move(validatedFieldPaths)});

  } else {
    return std::move(accumulator).MergeData(std::move(updateObject));
  }
}

- (ParsedUpdateData)parsedUpdateData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  NSDictionary *dict = input;

  ParseAccumulator accumulator{UserDataSource::Update};
  __block ParseContext context = accumulator.RootContext();
  __block ObjectValue updateData;

  [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
    FieldPath path;

    if ([key isKindOfClass:[NSString class]]) {
      path = FieldPath::FromDotSeparatedString(MakeString(key));
    } else if ([key isKindOfClass:[FIRFieldPath class]]) {
      path = ((FIRFieldPath *)key).internalValue;
    } else {
      ThrowInvalidArgument("Dictionary keys in updateData: must be NSStrings or FIRFieldPaths.");
    }

    value = self.preConverter(value);
    if ([value isKindOfClass:[FSTDeleteFieldValue class]]) {
      // Add it to the field mask, but don't add anything to updateData.
      context.AddToFieldMask(std::move(path));
    } else {
      auto parsedValue = [self parseData:value context:context.ChildContext(path)];
      if (parsedValue) {
        context.AddToFieldMask(path);
        updateData.Set(path, std::move(*parsedValue));
      }
    }
  }];

  return std::move(accumulator).UpdateData(std::move(updateData));
}

- (Message<google_firestore_v1_Value>)parsedQueryValue:(id)input {
  return [self parsedQueryValue:input allowArrays:false];
}

- (Message<google_firestore_v1_Value>)parsedQueryValue:(id)input allowArrays:(bool)allowArrays {
  ParseAccumulator accumulator{allowArrays ? UserDataSource::ArrayArgument
                                           : UserDataSource::Argument};

  auto parsed = [self parseData:input context:accumulator.RootContext()];
  HARD_ASSERT(parsed, "Parsed data should not be nil.");
  HARD_ASSERT(accumulator.field_transforms().empty(),
              "Field transforms should have been disallowed.");
  return std::move(*parsed);
}

/**
 * Internal helper for parsing user data.
 *
 * @param input Data to be parsed.
 * @param context A context object representing the current path being parsed, the source of the
 *   data being parsed, etc.
 *
 * @return The parsed value, or nil if the value was a FieldValue sentinel that should not be
 *   included in the resulting parsed data.
 */
- (absl::optional<Message<google_firestore_v1_Value>>)parseData:(id)input
                                                        context:(ParseContext &&)context {
  input = self.preConverter(input);
  if ([input isKindOfClass:[NSDictionary class]]) {
    return [self parseDictionary:(NSDictionary *)input context:std::move(context)];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    // FieldValues usually parse into transforms (except FieldValue.delete()) in which case we
    // do not want to include this field in our parsed data (as doing so will overwrite the field
    // directly prior to the transform trying to transform it). So we don't call appendToFieldMask
    // and we return nil as our parsing result.
    [self parseSentinelFieldValue:(FIRFieldValue *)input context:std::move(context)];
    return absl::nullopt;

  } else {
    // If context path is unset we are already inside an array and we don't support field mask paths
    // more granular than the top-level array.
    if (context.path()) {
      context.AddToFieldMask(*context.path());
    }

    if ([input isKindOfClass:[NSArray class]]) {
      // TODO(b/34871131): Include the path containing the array in the error message.
      // In the case of IN queries, the parsed data is an array (representing the set of values to
      // be included for the IN query) that may directly contain additional arrays (each
      // representing an individual field value), so we disable this validation.
      if (context.array_element() && context.data_source() != UserDataSource::ArrayArgument) {
        ThrowInvalidArgument("Nested arrays are not supported");
      }
      return [self parseArray:(NSArray *)input context:std::move(context)];
    } else {
      return [self parseScalarValue:input context:std::move(context)];
    }
  }
}

- (Message<google_firestore_v1_Value>)parseDictionary:(NSDictionary<NSString *, id> *)dict
                                              context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};

  if (dict.count == 0) {
    const FieldPath *path = context.path();
    if (path && !path->empty()) {
      context.AddToFieldMask(*path);
    }
  } else {
    // Compute the final size of the fields array, which contains an entry for
    // all fields that are not FieldValue sentinels
    __block pb_size_t count = 0;
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *, id value, BOOL *) {
      if (![value isKindOfClass:[FIRFieldValue class]]) {
        ++count;
      }
    }];

    result->map_value.fields_count = count;
    result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(count);

    __block pb_size_t index = 0;
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *) {
      auto parsedValue = [self parseData:value context:context.ChildContext(MakeString(key))];
      if (parsedValue) {
        result->map_value.fields[index].key = nanopb::MakeBytesArray(MakeString(key));
        result->map_value.fields[index].value = *parsedValue->release();
        ++index;
      }
    }];
  }

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseVectorValue:(FIRVectorValue *)vectorValue
                                               context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};

  result->map_value.fields_count = 2;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(2);

  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kTypeValueFieldKey);
  result->map_value.fields[0].value = *[self encodeStringValue:MakeString(@"__vector__")].release();

  NSArray<NSNumber *> *vectorArray = vectorValue.array;

  __block Message<google_firestore_v1_Value> arrayMessage;
  arrayMessage->which_value_type = google_firestore_v1_Value_array_value_tag;
  arrayMessage->array_value.values_count = CheckedSize([vectorArray count]);
  arrayMessage->array_value.values =
      nanopb::MakeArray<google_firestore_v1_Value>(arrayMessage->array_value.values_count);

  [vectorArray enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL *) {
    if (![entry isKindOfClass:[NSNumber class]]) {
      ThrowInvalidArgument("VectorValues must only contain numeric values.",
                           context.FieldDescription());
    }

    // Vector values must always use Double encoding
    arrayMessage->array_value.values[idx] = *[self encodeDouble:[entry doubleValue]].release();
  }];

  result->map_value.fields[1].key = nanopb::CopyBytesArray(model::kVectorValueFieldKey);
  result->map_value.fields[1].value = *arrayMessage.release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseMinKey {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kMinKeyTypeFieldValue);
  result->map_value.fields[0].value = *DeepClone(NullValue()).release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseMaxKey {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kMaxKeyTypeFieldValue);
  result->map_value.fields[0].value = *DeepClone(NullValue()).release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseRegexValue:(FIRRegexValue *)regexValue
                                              context:(ParseContext &&)context {
  NSString *pattern = regexValue.pattern;
  NSString *options = regexValue.options;

  __block Message<google_firestore_v1_Value> regexMessage;
  regexMessage->which_value_type = google_firestore_v1_Value_map_value_tag;
  regexMessage->map_value = {};
  regexMessage->map_value.fields_count = 2;
  regexMessage->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(2);
  regexMessage->map_value.fields[0].key =
      nanopb::CopyBytesArray(model::kRegexTypePatternFieldValue);
  regexMessage->map_value.fields[0].value = *[self encodeStringValue:MakeString(pattern)].release();
  regexMessage->map_value.fields[1].key =
      nanopb::CopyBytesArray(model::kRegexTypeOptionsFieldValue);
  regexMessage->map_value.fields[1].value = *[self encodeStringValue:MakeString(options)].release();

  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kRegexTypeFieldValue);
  result->map_value.fields[0].value = *regexMessage.release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseInt32Value:(FIRInt32Value *)int32
                                              context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kInt32TypeFieldValue);
  // The 32-bit integer value is encoded as a 64-bit long in the proto.
  result->map_value.fields[0].value =
      *[self encodeInteger:static_cast<int64_t>(int32.value)].release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseDecimal128Value:(FIRDecimal128Value *)decimal128
                                                   context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kDecimal128TypeFieldValue);
  result->map_value.fields[0].value =
      *[self encodeStringValue:MakeString(decimal128.value)].release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseBsonObjectId:(FIRBSONObjectId *)oid
                                                context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kBsonObjectIdTypeFieldValue);
  result->map_value.fields[0].value = *[self encodeStringValue:MakeString(oid.value)].release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseBsonTimestamp:(FIRBSONTimestamp *)timestamp
                                                 context:(ParseContext &&)context {
  uint32_t seconds = timestamp.seconds;
  uint32_t increment = timestamp.increment;

  __block Message<google_firestore_v1_Value> timestampMessage;
  timestampMessage->which_value_type = google_firestore_v1_Value_map_value_tag;
  timestampMessage->map_value = {};
  timestampMessage->map_value.fields_count = 2;
  timestampMessage->map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(2);

  timestampMessage->map_value.fields[0].key =
      nanopb::CopyBytesArray(model::kBsonTimestampTypeSecondsFieldValue);
  // The 32-bit unsigned integer value is encoded as a 64-bit long in the proto.
  timestampMessage->map_value.fields[0].value =
      *[self encodeInteger:static_cast<int64_t>(seconds)].release();

  timestampMessage->map_value.fields[1].key =
      nanopb::CopyBytesArray(model::kBsonTimestampTypeIncrementFieldValue);
  // The 32-bit unsigned integer value is encoded as a 64-bit long in the proto.
  timestampMessage->map_value.fields[1].value =
      *[self encodeInteger:static_cast<int64_t>(increment)].release();

  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kBsonTimestampTypeFieldValue);
  result->map_value.fields[0].value = *timestampMessage.release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseBsonBinaryData:(FIRBSONBinaryData *)binaryData
                                                  context:(ParseContext &&)context {
  uint8_t subtypeByte = binaryData.subtype;
  NSData *data = binaryData.data;

  // We need to prepend the data with one byte representation of the subtype.
  NSMutableData *concatData = [NSMutableData data];
  [concatData appendBytes:&subtypeByte length:1];
  [concatData appendData:data];

  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = {};
  result->map_value.fields_count = 1;
  result->map_value.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key = nanopb::CopyBytesArray(model::kBsonBinaryDataTypeFieldValue);
  result->map_value.fields[0].value =
      *[self encodeBlob:(nanopb::MakeByteString(concatData))].release();

  return std::move(result);
}

- (Message<google_firestore_v1_Value>)parseArray:(NSArray<id> *)array
                                         context:(ParseContext &&)context {
  __block Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_array_value_tag;
  result->array_value.values_count = CheckedSize([array count]);
  result->array_value.values =
      nanopb::MakeArray<google_firestore_v1_Value>(result->array_value.values_count);

  [array enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL *) {
    auto parsedEntry = [self parseData:entry context:context.ChildContext(idx)];
    if (!parsedEntry) {
      // Just include nulls in the array for fields being replaced with a sentinel.
      parsedEntry.emplace(DeepClone(NullValue()));
    }
    result->array_value.values[idx] = *parsedEntry->release();
  }];

  return std::move(result);
}

/**
 * "Parses" the provided FIRFieldValue, adding any necessary transforms to
 * context.fieldTransforms.
 */
- (void)parseSentinelFieldValue:(FIRFieldValue *)fieldValue context:(ParseContext &&)context {
  // Sentinels are only supported with writes, and not within arrays.
  if (!context.write()) {
    ThrowInvalidArgument("%s can only be used with updateData() and setData()%s",
                         fieldValue.methodName, context.FieldDescription());
  }
  if (!context.path()) {
    ThrowInvalidArgument("%s is not currently supported inside arrays", fieldValue.methodName);
  }

  if ([fieldValue isKindOfClass:[FSTDeleteFieldValue class]]) {
    if (context.data_source() == UserDataSource::MergeSet) {
      // No transform to add for a delete, but we need to add it to our fieldMask so it gets
      // deleted.
      context.AddToFieldMask(*context.path());

    } else if (context.data_source() == UserDataSource::Update) {
      HARD_ASSERT(!context.path()->empty(),
                  "FieldValue.delete() at the top level should have already been handled.");
      ThrowInvalidArgument("FieldValue.delete() can only appear at the top level of your "
                           "update data%s",
                           context.FieldDescription());
    } else {
      // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
      ThrowInvalidArgument(
          "FieldValue.delete() can only be used with updateData() and setData() with merge:true%s",
          context.FieldDescription());
    }

  } else if ([fieldValue isKindOfClass:[FSTServerTimestampFieldValue class]]) {
    context.AddToFieldTransforms(*context.path(), ServerTimestampTransform());

  } else if ([fieldValue isKindOfClass:[FSTArrayUnionFieldValue class]]) {
    auto parsedElements =
        [self parseArrayTransformElements:((FSTArrayUnionFieldValue *)fieldValue).elements];
    ArrayTransform arrayUnion(TransformOperation::Type::ArrayUnion, std::move(parsedElements));
    context.AddToFieldTransforms(*context.path(), std::move(arrayUnion));

  } else if ([fieldValue isKindOfClass:[FSTArrayRemoveFieldValue class]]) {
    auto parsedElements =
        [self parseArrayTransformElements:((FSTArrayRemoveFieldValue *)fieldValue).elements];
    ArrayTransform arrayRemove(TransformOperation::Type::ArrayRemove, std::move(parsedElements));
    context.AddToFieldTransforms(*context.path(), std::move(arrayRemove));

  } else if ([fieldValue isKindOfClass:[FSTNumericIncrementFieldValue class]]) {
    auto *numericIncrementFieldValue = (FSTNumericIncrementFieldValue *)fieldValue;
    auto operand = [self parsedQueryValue:numericIncrementFieldValue.operand];
    NumericIncrementTransform numeric_increment(std::move(operand));

    context.AddToFieldTransforms(*context.path(), std::move(numeric_increment));

  } else {
    HARD_FAIL("Unknown FIRFieldValue type: %s", NSStringFromClass([fieldValue class]));
  }
}

/**
 * Helper to parse a scalar value (i.e. not an NSDictionary, NSArray, or FIRFieldValue).
 *
 * Note that it handles all NSNumber values that are encodable as int64_t or doubles
 * (depending on the underlying type of the NSNumber). Unsigned integer values are handled though
 * any value outside what is representable by int64_t (a signed 64-bit value) will throw an
 * exception.
 *
 * @return The parsed value.
 */
- (Message<google_firestore_v1_Value>)parseScalarValue:(nullable id)input
                                               context:(ParseContext &&)context {
  if (!input || [input isMemberOfClass:[NSNull class]]) {
    return DeepClone(NullValue());

  } else if ([input isKindOfClass:[NSNumber class]]) {
    // Recover the underlying type of the number, using the method described here:
    // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber
    const char *cType = [input objCType];

    // Type Encoding values taken from
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/
    // Articles/ocrtTypeEncodings.html
    switch (cType[0]) {
      case 'q':
        return [self encodeInteger:[input longLongValue]];

      case 'i':  // Falls through.
      case 's':  // Falls through.
      case 'l':  // Falls through.
      case 'I':  // Falls through.
      case 'S':
        // Coerce integer values that aren't long long. Allow unsigned integer types that are
        // guaranteed small enough to skip a length check.
        return [self encodeInteger:[input longLongValue]];

      case 'L':  // Falls through.
      case 'Q':
        // Unsigned integers that could be too large. Note that the 'L' (long) case is handled here
        // because when compiled for LP64, unsigned long is 64 bits and could overflow int64_t.
        {
          unsigned long long extended = [input unsignedLongLongValue];

          if (extended > LLONG_MAX) {
            ThrowInvalidArgument("NSNumber (%s) is too large%s", [input unsignedLongLongValue],
                                 context.FieldDescription());

          } else {
            return [self encodeInteger:static_cast<int64_t>(extended)];
          }
        }

      case 'f':
        return [self encodeDouble:[input doubleValue]];

      case 'd':
        // Double values are already the right type, so just reuse the existing boxed double.
        //
        // Note that NSNumber already performs NaN normalization to a single shared instance
        // so there's no need to treat NaN specially here.
        return [self encodeDouble:[input doubleValue]];

      case 'B':  // Falls through.
      case 'c':  // Falls through.
      case 'C':
        // Boolean values are weird.
        //
        // On arm64, objCType of a BOOL-valued NSNumber will be "c", even though @encode(BOOL)
        // returns "B". "c" is the same as @encode(signed char). Unfortunately this means that
        // legitimate usage of signed chars is impossible, but this should be rare.
        //
        // Additionally, for consistency, map unsigned chars to bools in the same way.
        return [self encodeBoolean:[input boolValue]];

      default:
        // All documented codes should be handled above, so this shouldn't happen.
        HARD_FAIL("Unknown NSNumber objCType %s on %s", cType, input);
    }

  } else if ([input isKindOfClass:[NSString class]]) {
    std::string inputString = MakeString(input);
    return [self encodeStringValue:inputString];

  } else if ([input isKindOfClass:[NSDate class]]) {
    NSDate *inputDate = input;
    return [self encodeTimestampValue:api::MakeTimestamp(inputDate)];

  } else if ([input isKindOfClass:[FIRTimestamp class]]) {
    FIRTimestamp *inputTimestamp = input;
    Timestamp timestamp = TimestampInternal::Truncate(api::MakeTimestamp(inputTimestamp));
    return [self encodeTimestampValue:timestamp];

  } else if ([input isKindOfClass:[FIRGeoPoint class]]) {
    return [self encodeGeoPoint:api::MakeGeoPoint(input)];
  } else if ([input isKindOfClass:[NSData class]]) {
    NSData *inputData = input;
    return [self encodeBlob:(nanopb::MakeByteString(inputData))];

  } else if ([input isKindOfClass:[FSTDocumentKeyReference class]]) {
    FSTDocumentKeyReference *reference = input;
    if (reference.databaseID != _databaseID) {
      const DatabaseId &other = reference.databaseID;
      ThrowInvalidArgument(
          "Document Reference is for database %s/%s but should be for database %s/%s%s",
          other.project_id(), other.database_id(), _databaseID.project_id(),
          _databaseID.database_id(), context.FieldDescription());
    }
    return [self encodeReference:_databaseID key:reference.key];
  } else if ([input isKindOfClass:[FIRVectorValue class]]) {
    FIRVectorValue *vector = input;
    return [self parseVectorValue:vector context:std::move(context)];
  } else if ([input isKindOfClass:[FIRMinKey class]]) {
    return [self parseMinKey];
  } else if ([input isKindOfClass:[FIRMaxKey class]]) {
    return [self parseMaxKey];
  } else if ([input isKindOfClass:[FIRRegexValue class]]) {
    FIRRegexValue *regex = input;
    return [self parseRegexValue:regex context:std::move(context)];
  } else if ([input isKindOfClass:[FIRInt32Value class]]) {
    FIRInt32Value *value = input;
    return [self parseInt32Value:value context:std::move(context)];
  } else if ([input isKindOfClass:[FIRDecimal128Value class]]) {
    FIRDecimal128Value *value = input;
    return [self parseDecimal128Value:value context:std::move(context)];
  } else if ([input isKindOfClass:[FIRBSONObjectId class]]) {
    FIRBSONObjectId *oid = input;
    return [self parseBsonObjectId:oid context:std::move(context)];
  } else if ([input isKindOfClass:[FIRBSONTimestamp class]]) {
    FIRBSONTimestamp *timestamp = input;
    return [self parseBsonTimestamp:timestamp context:std::move(context)];
  } else if ([input isKindOfClass:[FIRBSONBinaryData class]]) {
    FIRBSONBinaryData *binaryData = input;
    return [self parseBsonBinaryData:binaryData context:std::move(context)];
  } else {
    ThrowInvalidArgument("Unsupported type: %s%s", NSStringFromClass([input class]),
                         context.FieldDescription());
  }
}

- (Message<google_firestore_v1_Value>)encodeBoolean:(bool)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_boolean_value_tag;
  result->boolean_value = value;
  return result;
}

- (Message<google_firestore_v1_Value>)encodeInteger:(int64_t)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_integer_value_tag;
  result->integer_value = value;
  return result;
}

- (Message<google_firestore_v1_Value>)encodeDouble:(double)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_double_value_tag;
  result->double_value = value;
  return result;
}

- (Message<google_firestore_v1_Value>)encodeTimestampValue:(Timestamp)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result->timestamp_value.seconds = value.seconds();
  result->timestamp_value.nanos = value.nanoseconds();
  return result;
}

- (Message<google_firestore_v1_Value>)encodeStringValue:(const std::string &)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_string_value_tag;
  result->string_value = nanopb::MakeBytesArray(value);
  return result;
}

- (Message<google_firestore_v1_Value>)encodeBlob:(const nanopb::ByteString &)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_bytes_value_tag;
  // Copy the blob so that pb_release can do the right thing.
  result->bytes_value = nanopb::CopyBytesArray(value.get());
  return result;
}

- (Message<google_firestore_v1_Value>)encodeReference:(const DatabaseId &)databaseId
                                                  key:(const DocumentKey &)key {
  HARD_ASSERT(_databaseID == databaseId, "Database %s cannot encode reference from %s",
              _databaseID.ToString(), databaseId.ToString());

  std::string referenceName = ResourcePath({"projects", databaseId.project_id(), "databases",
                                            databaseId.database_id(), "documents", key.ToString()})
                                  .CanonicalString();

  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_reference_value_tag;
  result->reference_value = nanopb::MakeBytesArray(referenceName);
  return result;
}

- (Message<google_firestore_v1_Value>)encodeGeoPoint:(const GeoPoint &)value {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_geo_point_value_tag;
  result->geo_point_value.latitude = value.latitude();
  result->geo_point_value.longitude = value.longitude();
  return result;
}

- (Message<google_firestore_v1_ArrayValue>)parseArrayTransformElements:(NSArray<id> *)elements {
  ParseAccumulator accumulator{UserDataSource::Argument};

  Message<google_firestore_v1_ArrayValue> array_value;
  array_value->values_count = CheckedSize(elements.count);
  array_value->values = nanopb::MakeArray<google_firestore_v1_Value>(array_value->values_count);

  for (NSUInteger i = 0; i < elements.count; i++) {
    id element = elements[i];
    // Although array transforms are used with writes, the actual elements being unioned or removed
    // are not considered writes since they cannot contain any FieldValue sentinels, etc.
    ParseContext context = accumulator.RootContext();

    auto parsedElement = [self parseData:element context:context.ChildContext(i)];
    HARD_ASSERT(parsedElement && accumulator.field_transforms().empty(),
                "Failed to properly parse array transform element: %s", element);
    array_value->values[i] = *parsedElement->release();
  }
  return array_value;
}

@end

NS_ASSUME_NONNULL_END
