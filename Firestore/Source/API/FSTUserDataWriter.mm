// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Firestore/Source/API/FSTUserDataWriter.h"

#import <Foundation/Foundation.h>

#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/Source/API/FIRDocumentReference+Internal.h"
#include "Firestore/Source/API/FIRFieldValue+Internal.h"
#include "Firestore/Source/API/converters.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRBSONBinaryData.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRBSONObjectId.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRBSONTimestamp.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRDecimal128Value.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRInt32Value.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRMaxKey.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRMinKey.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRRegexValue.h"
#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/string_apple.h"

@class FIRTimestamp;

namespace api = firebase::firestore::api;
namespace model = firebase::firestore::model;
namespace nanopb = firebase::firestore::nanopb;

using api::MakeFIRDocumentReference;
using api::MakeFIRGeoPoint;
using api::MakeFIRTimestamp;
using firebase::firestore::GeoPoint;
using firebase::firestore::google_firestore_v1_ArrayValue;
using firebase::firestore::google_firestore_v1_MapValue;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::google_protobuf_Timestamp;
using firebase::firestore::model::kRawBsonTimestampTypeIncrementFieldValue;
using firebase::firestore::model::kRawBsonTimestampTypeSecondsFieldValue;
using firebase::firestore::model::kRawDecimal128TypeFieldValue;
using firebase::firestore::model::kRawInt32TypeFieldValue;
using firebase::firestore::model::kRawRegexTypeOptionsFieldValue;
using firebase::firestore::model::kRawRegexTypePatternFieldValue;
using firebase::firestore::model::kRawVectorValueFieldKey;
using firebase::firestore::util::MakeNSString;
using model::DatabaseId;
using model::DocumentKey;
using model::GetLocalWriteTime;
using model::GetPreviousValue;
using model::GetTypeOrder;
using model::TypeOrder;
using nanopb::MakeBytesArray;
using nanopb::MakeByteString;
using nanopb::MakeNSData;
using nanopb::MakeString;
using nanopb::MakeStringView;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTUserDataWriter {
  std::shared_ptr<api::Firestore> _firestore;
  FIRServerTimestampBehavior _serverTimestampBehavior;
}

- (instancetype)initWithFirestore:(std::shared_ptr<api::Firestore>)firestore
          serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  self = [super init];
  if (self) {
    _firestore = std::move(firestore);
    _serverTimestampBehavior = serverTimestampBehavior;
  }
  return self;
}

- (id)convertedValue:(const google_firestore_v1_Value &)value {
  switch (GetTypeOrder(value)) {
    case TypeOrder::kMap:
      return [self convertedObject:value.map_value];
    case TypeOrder::kArray:
      return [self convertedArray:value.array_value];
    case TypeOrder::kReference:
      return [self convertedReference:value];
    case TypeOrder::kTimestamp:
      return [self convertedTimestamp:value.timestamp_value];
    case TypeOrder::kServerTimestamp:
      return [self convertedServerTimestamp:value];
    case TypeOrder::kNull:
      return [NSNull null];
    case TypeOrder::kBoolean:
      return value.boolean_value ? @YES : @NO;
    case TypeOrder::kNumber:
      if (value.which_value_type == google_firestore_v1_Value_map_value_tag) {
        absl::string_view key = MakeStringView(value.map_value.fields[0].key);
        if (key.compare(absl::string_view(kRawInt32TypeFieldValue)) == 0) {
          return [self convertedInt32:value.map_value];
        } else if (key.compare(absl::string_view(kRawDecimal128TypeFieldValue)) == 0) {
          return [self convertedDecimal128Value:value.map_value];
        }
      }
      return value.which_value_type == google_firestore_v1_Value_integer_value_tag
                 ? @(value.integer_value)
                 : @(value.double_value);
    case TypeOrder::kString:
      return MakeNSString(MakeStringView(value.string_value));
    case TypeOrder::kBlob:
      return MakeNSData(value.bytes_value);
    case TypeOrder::kGeoPoint:
      return MakeFIRGeoPoint(
          GeoPoint(value.geo_point_value.latitude, value.geo_point_value.longitude));
    case TypeOrder::kMinKey:
      return [FIRMinKey shared];
    case TypeOrder::kMaxKey:
      return [FIRMaxKey shared];
    case TypeOrder::kRegex:
      return [self convertedRegex:value.map_value];
    case TypeOrder::kBsonObjectId:
      return [self convertedBsonObjectId:value.map_value];
    case TypeOrder::kBsonTimestamp:
      return [self convertedBsonTimestamp:value.map_value];
    case TypeOrder::kBsonBinaryData:
      return [self convertedBsonBinaryData:value.map_value];
    case TypeOrder::kVector:
      return [self convertedVector:value.map_value];
    case TypeOrder::kInternalMaxValue:
      // It is not possible for users to construct a kInternalMaxValue manually.
      break;
  }

  UNREACHABLE();
}

- (NSDictionary<NSString *, id> *)convertedObject:(const google_firestore_v1_MapValue &)mapValue {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  for (pb_size_t i = 0; i < mapValue.fields_count; ++i) {
    absl::string_view key = MakeStringView(mapValue.fields[i].key);
    const google_firestore_v1_Value &value = mapValue.fields[i].value;
    result[MakeNSString(key)] = [self convertedValue:value];
  }
  return result;
}

- (FIRVectorValue *)convertedVector:(const google_firestore_v1_MapValue &)mapValue {
  for (pb_size_t i = 0; i < mapValue.fields_count; ++i) {
    absl::string_view key = MakeStringView(mapValue.fields[i].key);
    const google_firestore_v1_Value &value = mapValue.fields[i].value;
    if ((key.compare(absl::string_view(kRawVectorValueFieldKey)) == 0) &&
        value.which_value_type == google_firestore_v1_Value_array_value_tag) {
      return [FIRFieldValue vectorWithArray:[self convertedArray:value.array_value]];
    }
  }
  return [FIRFieldValue vectorWithArray:@[]];
}

- (FIRRegexValue *)convertedRegex:(const google_firestore_v1_MapValue &)mapValue {
  NSString *pattern = @"";
  NSString *options = @"";
  if (mapValue.fields_count == 1) {
    const google_firestore_v1_Value &innerValue = mapValue.fields[0].value;
    if (innerValue.which_value_type == google_firestore_v1_Value_map_value_tag) {
      for (pb_size_t i = 0; i < innerValue.map_value.fields_count; ++i) {
        absl::string_view key = MakeStringView(innerValue.map_value.fields[i].key);
        const google_firestore_v1_Value &value = innerValue.map_value.fields[i].value;
        if ((key.compare(absl::string_view(kRawRegexTypePatternFieldValue)) == 0) &&
            value.which_value_type == google_firestore_v1_Value_string_value_tag) {
          pattern = MakeNSString(MakeStringView(value.string_value));
        }
        if ((key.compare(absl::string_view(kRawRegexTypeOptionsFieldValue)) == 0) &&
            value.which_value_type == google_firestore_v1_Value_string_value_tag) {
          options = MakeNSString(MakeStringView(value.string_value));
        }
      }
    }
  }

  return [[FIRRegexValue alloc] initWithPattern:pattern options:options];
}

- (FIRInt32Value *)convertedInt32:(const google_firestore_v1_MapValue &)mapValue {
  int32_t value = 0;
  if (mapValue.fields_count == 1) {
    value = static_cast<int32_t>(mapValue.fields[0].value.integer_value);
  }

  return [[FIRInt32Value alloc] initWithValue:value];
}

- (FIRDecimal128Value *)convertedDecimal128Value:(const google_firestore_v1_MapValue &)mapValue {
  NSString *decimalString = @"";
  if (mapValue.fields_count == 1) {
    const google_firestore_v1_Value &decimalValue = mapValue.fields[0].value;
    if (decimalValue.which_value_type == google_firestore_v1_Value_string_value_tag) {
      decimalString = MakeNSString(MakeStringView(decimalValue.string_value));
    }
  }

  return [[FIRDecimal128Value alloc] initWithValue:decimalString];
}

- (FIRBSONObjectId *)convertedBsonObjectId:(const google_firestore_v1_MapValue &)mapValue {
  NSString *oid = @"";
  if (mapValue.fields_count == 1) {
    const google_firestore_v1_Value &oidValue = mapValue.fields[0].value;
    if (oidValue.which_value_type == google_firestore_v1_Value_string_value_tag) {
      oid = MakeNSString(MakeStringView(oidValue.string_value));
    }
  }

  return [[FIRBSONObjectId alloc] initWithValue:oid];
}

- (FIRBSONTimestamp *)convertedBsonTimestamp:(const google_firestore_v1_MapValue &)mapValue {
  uint32_t seconds = 0;
  uint32_t increment = 0;
  if (mapValue.fields_count == 1) {
    const google_firestore_v1_Value &innerValue = mapValue.fields[0].value;
    if (innerValue.which_value_type == google_firestore_v1_Value_map_value_tag) {
      for (pb_size_t i = 0; i < innerValue.map_value.fields_count; ++i) {
        absl::string_view key = MakeStringView(innerValue.map_value.fields[i].key);
        const google_firestore_v1_Value &value = innerValue.map_value.fields[i].value;
        if ((key.compare(absl::string_view(kRawBsonTimestampTypeSecondsFieldValue)) == 0) &&
            value.which_value_type == google_firestore_v1_Value_integer_value_tag) {
          // The value from the server is guaranteed to fit in a 32-bit unsigned integer.
          seconds = static_cast<uint32_t>(value.integer_value);
        }
        if ((key.compare(absl::string_view(kRawBsonTimestampTypeIncrementFieldValue)) == 0) &&
            value.which_value_type == google_firestore_v1_Value_integer_value_tag) {
          // The value from the server is guaranteed to fit in a 32-bit unsigned integer.
          increment = static_cast<uint32_t>(value.integer_value);
        }
      }
    }
  }

  return [[FIRBSONTimestamp alloc] initWithSeconds:seconds increment:increment];
}

- (FIRBSONBinaryData *)convertedBsonBinaryData:(const google_firestore_v1_MapValue &)mapValue {
  uint8_t subtype = 0;
  NSData *data = [[NSData alloc] init];

  if (mapValue.fields_count == 1) {
    const google_firestore_v1_Value &dataValue = mapValue.fields[0].value;
    if (dataValue.which_value_type == google_firestore_v1_Value_bytes_value_tag) {
      NSData *concatData = MakeNSData(dataValue.bytes_value);
      if (concatData.length > 0) {
        uint8_t buffer[1];
        [concatData getBytes:buffer length:1];
        subtype = buffer[0];
      }
      if (concatData.length > 1) {
        data = [concatData subdataWithRange:NSMakeRange(1, concatData.length - 1)];
      }
    }
  }

  return [[FIRBSONBinaryData alloc] initWithSubtype:subtype data:data];
}

- (NSArray<id> *)convertedArray:(const google_firestore_v1_ArrayValue &)arrayValue {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:arrayValue.values_count];
  for (pb_size_t i = 0; i < arrayValue.values_count; ++i) {
    [result addObject:[self convertedValue:arrayValue.values[i]]];
  }
  return result;
}

- (id)convertedServerTimestamp:(const google_firestore_v1_Value &)serverTimestampValue {
  switch (_serverTimestampBehavior) {
    case FIRServerTimestampBehavior::FIRServerTimestampBehaviorNone:
      return [NSNull null];
    case FIRServerTimestampBehavior::FIRServerTimestampBehaviorEstimate:
      return [self convertedTimestamp:GetLocalWriteTime(serverTimestampValue)];
    case FIRServerTimestampBehavior::FIRServerTimestampBehaviorPrevious: {
      auto previous_value = GetPreviousValue(serverTimestampValue);
      return previous_value ? [self convertedValue:*previous_value] : [NSNull null];
    }
  }

  UNREACHABLE();
}

- (FIRTimestamp *)convertedTimestamp:(const google_protobuf_Timestamp &)value {
  return MakeFIRTimestamp(firebase::Timestamp{value.seconds, value.nanos});
}

- (FIRDocumentReference *)convertedReference:(const google_firestore_v1_Value &)value {
  std::string ref = MakeString(value.reference_value);
  DatabaseId databaseID = DatabaseId::FromName(ref);
  DocumentKey key = DocumentKey::FromName(ref);
  if (databaseID != _firestore->database_id()) {
    LOG_WARN("Document reference is for a different database (%s/%s) which "
             "is not supported. It will be treated as a reference within the current database "
             "(%s/%s) instead.",
             databaseID.project_id(), databaseID.database_id(), databaseID.project_id(),
             databaseID.database_id());
  }
  return MakeFIRDocumentReference(key, _firestore);
}

@end

NS_ASSUME_NONNULL_END
