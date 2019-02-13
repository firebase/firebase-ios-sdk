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

#import "Firestore/Source/API/FSTUserDataConverter.h"

#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "FIRGeoPoint.h"
#import "FIRTimestamp.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/core/user_data.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::core::ParseAccumulator;
using firebase::firestore::core::ParseContext;
using firebase::firestore::core::UserDataSource;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::TransformOperation;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDocumentKeyReference

@implementation FSTDocumentKeyReference {
  DocumentKey _key;
}

- (instancetype)initWithKey:(DocumentKey)key databaseID:(const DatabaseId *)databaseID {
  self = [super init];
  if (self) {
    _key = std::move(key);
    _databaseID = databaseID;
  }
  return self;
}

- (const firebase::firestore::model::DocumentKey &)key {
  return _key;
}

@end

#pragma mark - FSTUserDataConverter

@interface FSTUserDataConverter ()
// Does not own the DatabaseId instance.
@property(assign, nonatomic, readonly) const DatabaseId *databaseID;
@property(strong, nonatomic, readonly) FSTPreConverterBlock preConverter;
@end

@implementation FSTUserDataConverter

- (instancetype)initWithDatabaseID:(const DatabaseId *)databaseID
                      preConverter:(FSTPreConverterBlock)preConverter {
  self = [super init];
  if (self) {
    _databaseID = databaseID;
    _preConverter = preConverter;
  }
  return self;
}

- (ParsedSetData)parsedSetData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::Set};
  FSTFieldValue *updateData = [self parseData:input context:accumulator.RootContext()];

  return std::move(accumulator).SetData((FSTObjectValue *)updateData);
}

- (ParsedSetData)parsedMergeData:(id)input fieldMask:(nullable NSArray<id> *)fieldMask {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::MergeSet};

  FSTObjectValue *updateData = (FSTObjectValue *)[self parseData:input
                                                         context:accumulator.RootContext()];

  if (fieldMask) {
    std::set<FieldPath> validatedFieldPaths;
    for (id fieldPath in fieldMask) {
      FieldPath path;

      if ([fieldPath isKindOfClass:[NSString class]]) {
        path = [FIRFieldPath pathWithDotSeparatedString:fieldPath].internalValue;
      } else if ([fieldPath isKindOfClass:[FIRFieldPath class]]) {
        path = ((FIRFieldPath *)fieldPath).internalValue;
      } else {
        FSTThrowInvalidArgument(
            @"All elements in mergeFields: must be NSStrings or FIRFieldPaths.");
      }

      // Verify that all elements specified in the field mask are part of the parsed context.
      if (!accumulator.Contains(path)) {
        FSTThrowInvalidArgument(
            @"Field '%s' is specified in your field mask but missing from your input data.",
            path.CanonicalString().c_str());
      }

      validatedFieldPaths.insert(path);
    }

    return std::move(accumulator).MergeData(updateData, FieldMask{std::move(validatedFieldPaths)});

  } else {
    return std::move(accumulator).MergeData(updateData);
  }
}

- (ParsedUpdateData)parsedUpdateData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  NSDictionary *dict = input;

  ParseAccumulator accumulator{UserDataSource::Update};
  __block ParseContext context = accumulator.RootContext();
  __block FSTObjectValue *updateData = [FSTObjectValue objectValue];

  [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    FieldPath path;

    if ([key isKindOfClass:[NSString class]]) {
      path = [FIRFieldPath pathWithDotSeparatedString:key].internalValue;
    } else if ([key isKindOfClass:[FIRFieldPath class]]) {
      path = ((FIRFieldPath *)key).internalValue;
    } else {
      FSTThrowInvalidArgument(
          @"Dictionary keys in updateData: must be NSStrings or FIRFieldPaths.");
    }

    value = self.preConverter(value);
    if ([value isKindOfClass:[FSTDeleteFieldValue class]]) {
      // Add it to the field mask, but don't add anything to updateData.
      context.AddToFieldMask(std::move(path));
    } else {
      FSTFieldValue *_Nullable parsedValue = [self parseData:value
                                                     context:context.ChildContext(path)];
      if (parsedValue) {
        context.AddToFieldMask(path);
        updateData = [updateData objectBySettingValue:parsedValue forPath:path];
      }
    }
  }];

  return std::move(accumulator).UpdateData(updateData);
}

- (FSTFieldValue *)parsedQueryValue:(id)input {
  ParseAccumulator accumulator{UserDataSource::Argument};

  FSTFieldValue *_Nullable parsed = [self parseData:input context:accumulator.RootContext()];
  HARD_ASSERT(parsed, "Parsed data should not be nil.");
  HARD_ASSERT(accumulator.field_transforms().empty(),
              "Field transforms should have been disallowed.");
  return parsed;
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
- (nullable FSTFieldValue *)parseData:(id)input context:(ParseContext &&)context {
  input = self.preConverter(input);
  if ([input isKindOfClass:[NSDictionary class]]) {
    return [self parseDictionary:(NSDictionary *)input context:std::move(context)];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    // FieldValues usually parse into transforms (except FieldValue.delete()) in which case we
    // do not want to include this field in our parsed data (as doing so will overwrite the field
    // directly prior to the transform trying to transform it). So we don't call appendToFieldMask
    // and we return nil as our parsing result.
    [self parseSentinelFieldValue:(FIRFieldValue *)input context:std::move(context)];
    return nil;

  } else {
    // If context path is unset we are already inside an array and we don't support field mask paths
    // more granular than the top-level array.
    if (context.path()) {
      context.AddToFieldMask(*context.path());
    }

    if ([input isKindOfClass:[NSArray class]]) {
      // TODO(b/34871131): Include the path containing the array in the error message.
      if (context.array_element()) {
        FSTThrowInvalidArgument(@"Nested arrays are not supported");
      }
      return [self parseArray:(NSArray *)input context:std::move(context)];
    } else {
      return [self parseScalarValue:input context:std::move(context)];
    }
  }
}

- (FSTFieldValue *)parseDictionary:(NSDictionary *)dict context:(ParseContext &&)context {
  NSMutableDictionary<NSString *, FSTFieldValue *> *result =
      [NSMutableDictionary dictionaryWithCapacity:dict.count];

  if ([dict count] == 0) {
    const FieldPath *path = context.path();
    if (path && !path->empty()) {
      context.AddToFieldMask(*path);
    }
    return [FSTObjectValue objectValue];
  } else {
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
      FSTFieldValue *_Nullable parsedValue =
          [self parseData:value context:context.ChildContext(util::MakeString(key))];
      if (parsedValue) {
        result[key] = parsedValue;
      }
    }];
  }
  return [[FSTObjectValue alloc] initWithDictionary:result];
}

- (FSTFieldValue *)parseArray:(NSArray *)array context:(ParseContext &&)context {
  NSMutableArray<FSTFieldValue *> *result = [NSMutableArray arrayWithCapacity:array.count];
  [array enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL *stop) {
    FSTFieldValue *_Nullable parsedEntry = [self parseData:entry context:context.ChildContext(idx)];
    if (!parsedEntry) {
      // Just include nulls in the array for fields being replaced with a sentinel.
      parsedEntry = [FSTNullValue nullValue];
    }
    [result addObject:parsedEntry];
  }];
  return [[FSTArrayValue alloc] initWithValueNoCopy:result];
}

/**
 * "Parses" the provided FIRFieldValue, adding any necessary transforms to
 * context.fieldTransforms.
 */
- (void)parseSentinelFieldValue:(FIRFieldValue *)fieldValue context:(ParseContext &&)context {
  // Sentinels are only supported with writes, and not within arrays.
  if (!context.write()) {
    FSTThrowInvalidArgument(@"%@ can only be used with updateData() and setData()%s",
                            fieldValue.methodName, context.FieldDescription().c_str());
  }
  if (!context.path()) {
    FSTThrowInvalidArgument(@"%@ is not currently supported inside arrays", fieldValue.methodName);
  }

  if ([fieldValue isKindOfClass:[FSTDeleteFieldValue class]]) {
    if (context.data_source() == UserDataSource::MergeSet) {
      // No transform to add for a delete, but we need to add it to our fieldMask so it gets
      // deleted.
      context.AddToFieldMask(*context.path());

    } else if (context.data_source() == UserDataSource::Update) {
      HARD_ASSERT(context.path()->size() > 0,
                  "FieldValue.delete() at the top level should have already been handled.");
      FSTThrowInvalidArgument(@"FieldValue.delete() can only appear at the top level of your "
                               "update data%s",
                              context.FieldDescription().c_str());
    } else {
      // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
      FSTThrowInvalidArgument(
          @"FieldValue.delete() can only be used with updateData() and setData() with "
          @"merge:true%s",
          context.FieldDescription().c_str());
    }

  } else if ([fieldValue isKindOfClass:[FSTServerTimestampFieldValue class]]) {
    context.AddToFieldTransforms(*context.path(), absl::make_unique<ServerTimestampTransform>(
                                                      ServerTimestampTransform::Get()));

  } else if ([fieldValue isKindOfClass:[FSTArrayUnionFieldValue class]]) {
    std::vector<FSTFieldValue *> parsedElements =
        [self parseArrayTransformElements:((FSTArrayUnionFieldValue *)fieldValue).elements];
    auto array_union = absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayUnion,
                                                         std::move(parsedElements));
    context.AddToFieldTransforms(*context.path(), std::move(array_union));

  } else if ([fieldValue isKindOfClass:[FSTArrayRemoveFieldValue class]]) {
    std::vector<FSTFieldValue *> parsedElements =
        [self parseArrayTransformElements:((FSTArrayRemoveFieldValue *)fieldValue).elements];
    auto array_remove = absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayRemove,
                                                          std::move(parsedElements));
    context.AddToFieldTransforms(*context.path(), std::move(array_remove));

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
- (nullable FSTFieldValue *)parseScalarValue:(nullable id)input context:(ParseContext &&)context {
  if (!input || [input isMemberOfClass:[NSNull class]]) {
    return [FSTNullValue nullValue];

  } else if ([input isKindOfClass:[NSNumber class]]) {
    // Recover the underlying type of the number, using the method described here:
    // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber
    const char *cType = [input objCType];

    // Type Encoding values taken from
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/
    // Articles/ocrtTypeEncodings.html
    switch (cType[0]) {
      case 'q':
        return [FSTIntegerValue integerValue:[input longLongValue]];

      case 'i':  // Falls through.
      case 's':  // Falls through.
      case 'l':  // Falls through.
      case 'I':  // Falls through.
      case 'S':
        // Coerce integer values that aren't long long. Allow unsigned integer types that are
        // guaranteed small enough to skip a length check.
        return [FSTIntegerValue integerValue:[input longLongValue]];

      case 'L':  // Falls through.
      case 'Q':
        // Unsigned integers that could be too large. Note that the 'L' (long) case is handled here
        // because when compiled for LP64, unsigned long is 64 bits and could overflow int64_t.
        {
          unsigned long long extended = [input unsignedLongLongValue];

          if (extended > LLONG_MAX) {
            FSTThrowInvalidArgument(@"NSNumber (%llu) is too large%s",
                                    [input unsignedLongLongValue],
                                    context.FieldDescription().c_str());

          } else {
            return [FSTIntegerValue integerValue:(int64_t)extended];
          }
        }

      case 'f':
        return [FSTDoubleValue doubleValue:[input doubleValue]];

      case 'd':
        // Double values are already the right type, so just reuse the existing boxed double.
        //
        // Note that NSNumber already performs NaN normalization to a single shared instance
        // so there's no need to treat NaN specially here.
        return [FSTDoubleValue doubleValue:[input doubleValue]];

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
        return [FSTBooleanValue booleanValue:[input boolValue]];

      default:
        // All documented codes should be handled above, so this shouldn't happen.
        HARD_FAIL("Unknown NSNumber objCType %s on %s", cType, input);
    }

  } else if ([input isKindOfClass:[NSString class]]) {
    return [FSTStringValue stringValue:input];

  } else if ([input isKindOfClass:[NSDate class]]) {
    return [FSTTimestampValue timestampValue:[FIRTimestamp timestampWithDate:input]];

  } else if ([input isKindOfClass:[FIRTimestamp class]]) {
    FIRTimestamp *originalTimestamp = (FIRTimestamp *)input;
    FIRTimestamp *truncatedTimestamp =
        [FIRTimestamp timestampWithSeconds:originalTimestamp.seconds
                               nanoseconds:originalTimestamp.nanoseconds / 1000 * 1000];
    return [FSTTimestampValue timestampValue:truncatedTimestamp];

  } else if ([input isKindOfClass:[FIRGeoPoint class]]) {
    return [FSTGeoPointValue geoPointValue:input];

  } else if ([input isKindOfClass:[NSData class]]) {
    return [FSTBlobValue blobValue:input];

  } else if ([input isKindOfClass:[FSTDocumentKeyReference class]]) {
    FSTDocumentKeyReference *reference = input;
    if (*reference.databaseID != *self.databaseID) {
      const DatabaseId *other = reference.databaseID;
      FSTThrowInvalidArgument(
          @"Document Reference is for database %s/%s but should be for database %s/%s%s",
          other->project_id().c_str(), other->database_id().c_str(),
          self.databaseID->project_id().c_str(), self.databaseID->database_id().c_str(),
          context.FieldDescription().c_str());
    }
    return [FSTReferenceValue referenceValue:[FSTDocumentKey keyWithDocumentKey:reference.key]
                                  databaseID:self.databaseID];

  } else {
    FSTThrowInvalidArgument(@"Unsupported type: %@%s", NSStringFromClass([input class]),
                            context.FieldDescription().c_str());
  }
}

- (std::vector<FSTFieldValue *>)parseArrayTransformElements:(NSArray<id> *)elements {
  ParseAccumulator accumulator{UserDataSource::Argument};

  std::vector<FSTFieldValue *> values;
  for (NSUInteger i = 0; i < elements.count; i++) {
    id element = elements[i];
    // Although array transforms are used with writes, the actual elements being unioned or removed
    // are not considered writes since they cannot contain any FieldValue sentinels, etc.
    ParseContext context = accumulator.RootContext();

    FSTFieldValue *parsedElement = [self parseData:element context:context.ChildContext(i)];
    HARD_ASSERT(parsedElement && accumulator.field_transforms().size() == 0,
                "Failed to properly parse array transform element: %s", element);
    values.push_back(parsedElement);
  }
  return values;
}

@end

NS_ASSUME_NONNULL_END
