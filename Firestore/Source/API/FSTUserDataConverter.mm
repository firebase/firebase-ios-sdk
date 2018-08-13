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

static const char *RESERVED_FIELD_DESIGNATOR = "__";

#pragma mark - FSTParsedSetData

@implementation FSTParsedSetData {
  FieldMask _fieldMask;
  std::vector<FieldTransform> _fieldTransforms;
}

- (instancetype)initWithData:(FSTObjectValue *)data
             fieldTransforms:(std::vector<FieldTransform>)fieldTransforms {
  self = [super init];
  if (self) {
    _data = data;
    _fieldTransforms = std::move(fieldTransforms);
    _isPatch = NO;
  }
  return self;
}

- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(FieldMask)fieldMask
             fieldTransforms:(std::vector<FieldTransform>)fieldTransforms {
  self = [super init];
  if (self) {
    _data = data;
    _fieldMask = std::move(fieldMask);
    _fieldTransforms = std::move(fieldTransforms);
    _isPatch = YES;
  }
  return self;
}

- (const std::vector<FieldTransform> &)fieldTransforms {
  return _fieldTransforms;
}

- (NSArray<FSTMutation *> *)mutationsWithKey:(const DocumentKey &)key
                                precondition:(const Precondition &)precondition {
  NSMutableArray<FSTMutation *> *mutations = [NSMutableArray array];
  if (self.isPatch) {
    [mutations addObject:[[FSTPatchMutation alloc] initWithKey:key
                                                     fieldMask:_fieldMask
                                                         value:self.data
                                                  precondition:precondition]];
  } else {
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:key
                                                       value:self.data
                                                precondition:precondition]];
  }
  if (!self.fieldTransforms.empty()) {
    [mutations addObject:[[FSTTransformMutation alloc] initWithKey:key
                                                   fieldTransforms:self.fieldTransforms]];
  }
  return mutations;
}

@end

#pragma mark - FSTParsedUpdateData

@implementation FSTParsedUpdateData {
  FieldMask _fieldMask;
  std::vector<FieldTransform> _fieldTransforms;
}

- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(FieldMask)fieldMask
             fieldTransforms:(std::vector<FieldTransform>)fieldTransforms {
  self = [super init];
  if (self) {
    _data = data;
    _fieldMask = std::move(fieldMask);
    _fieldTransforms = std::move(fieldTransforms);
  }
  return self;
}

- (NSArray<FSTMutation *> *)mutationsWithKey:(const DocumentKey &)key
                                precondition:(const Precondition &)precondition {
  NSMutableArray<FSTMutation *> *mutations = [NSMutableArray array];
  [mutations addObject:[[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:self.fieldMask
                                                       value:self.data
                                                precondition:precondition]];
  if (!self.fieldTransforms.empty()) {
    [mutations addObject:[[FSTTransformMutation alloc] initWithKey:key
                                                   fieldTransforms:self.fieldTransforms]];
  }
  return mutations;
}

- (const firebase::firestore::model::FieldMask &)fieldMask {
  return _fieldMask;
}

- (const std::vector<FieldTransform> &)fieldTransforms {
  return _fieldTransforms;
}

@end

/**
 * Represents what type of API method provided the data being parsed; useful for determining which
 * error conditions apply during parsing and providing better error messages.
 */
typedef NS_ENUM(NSInteger, FSTUserDataSource) {
  FSTUserDataSourceSet,
  FSTUserDataSourceMergeSet,
  FSTUserDataSourceUpdate,
  /**
   * Indicates the source is a where clause, cursor bound, arrayUnion() element, etc. In particular,
   * this will result in [FSTParseContext isWrite] returning NO.
   */
  FSTUserDataSourceArgument,
};

#pragma mark - FSTParseContext

/**
 * A "context" object passed around while parsing user data.
 */
@interface FSTParseContext : NSObject

/** Whether or not this context corresponds to an element of an array. */
@property(nonatomic, assign, readonly, getter=isArrayElement) BOOL arrayElement;

/**
 * What type of API method provided the data being parsed; useful for determining which error
 * conditions apply during parsing and providing better error messages.
 */
@property(nonatomic, assign) FSTUserDataSource dataSource;

- (instancetype)init NS_UNAVAILABLE;
/**
 * Initializes a FSTParseContext with the given source and path.
 *
 * @param dataSource Indicates what kind of API method this data came from.
 * @param path A path within the object being parsed. This could be an empty path (in which case
 *   the context represents the root of the data being parsed), or a nonempty path (indicating the
 *   context represents a nested location within the data).
 *
 * TODO(b/34871131): We don't support array paths right now, so path can be nullptr to indicate
 * the context represents any location within an array (in which case certain features will not work
 * and errors will be somewhat compromised).
 */
- (instancetype)initWithSource:(FSTUserDataSource)dataSource
                          path:(std::unique_ptr<FieldPath>)path
                  arrayElement:(BOOL)arrayElement
               fieldTransforms:(std::shared_ptr<std::vector<FieldTransform>>)fieldTransforms
                     fieldMask:(std::shared_ptr<std::vector<FieldPath>>)fieldMask
    NS_DESIGNATED_INITIALIZER;

// Helpers to get a FSTParseContext for a child field.
- (instancetype)contextForField:(NSString *)fieldName;
- (instancetype)contextForFieldPath:(const FieldPath &)fieldPath;
- (instancetype)contextForArrayIndex:(NSUInteger)index;

/** Returns true for the non-query parse contexts (Set, MergeSet and Update) */
- (BOOL)isWrite;

/** Returns 'YES' if 'fieldPath' was traversed when creating this context. */
- (BOOL)containsFieldPath:(const FieldPath &)fieldPath;

- (const FieldPath *)path;

- (const std::vector<FieldPath> *)fieldMask;

- (void)appendToFieldMaskWithFieldPath:(FieldPath)fieldPath;

- (const std::vector<FieldTransform> *)fieldTransforms;

- (void)appendToFieldTransformsWithFieldPath:(FieldPath)fieldPath
                          transformOperation:
                              (std::unique_ptr<TransformOperation>)transformOperation;
@end

@implementation FSTParseContext {
  /** The current path being parsed. */
  // TODO(b/34871131): path should never be nullptr, but we don't support array paths right now.
  std::unique_ptr<FieldPath> _path;
  // _fieldMask and _fieldTransforms are shared across all active context objects to accumulate the
  // result. For example, the result of calling any of contextForField, contextForFieldPath and
  // contextForArrayIndex shares the ownership of _fieldMask and _fieldTransforms.
  std::shared_ptr<std::vector<FieldPath>> _fieldMask;
  std::shared_ptr<std::vector<FieldTransform>> _fieldTransforms;
}

+ (instancetype)contextWithSource:(FSTUserDataSource)dataSource
                             path:(std::unique_ptr<FieldPath>)path {
  FSTParseContext *context =
      [[FSTParseContext alloc] initWithSource:dataSource
                                         path:std::move(path)
                                 arrayElement:NO
                              fieldTransforms:std::make_shared<std::vector<FieldTransform>>()
                                    fieldMask:std::make_shared<std::vector<FieldPath>>()];
  [context validatePath];
  return context;
}

- (instancetype)initWithSource:(FSTUserDataSource)dataSource
                          path:(std::unique_ptr<FieldPath>)path
                  arrayElement:(BOOL)arrayElement
               fieldTransforms:(std::shared_ptr<std::vector<FieldTransform>>)fieldTransforms
                     fieldMask:(std::shared_ptr<std::vector<FieldPath>>)fieldMask {
  if (self = [super init]) {
    _dataSource = dataSource;
    _path = std::move(path);
    _arrayElement = arrayElement;
    _fieldTransforms = std::move(fieldTransforms);
    _fieldMask = std::move(fieldMask);
  }
  return self;
}

- (instancetype)contextForField:(NSString *)fieldName {
  std::unique_ptr<FieldPath> path;
  if (_path) {
    path = absl::make_unique<FieldPath>(_path->Append(util::MakeString(fieldName)));
  }
  FSTParseContext *context = [[FSTParseContext alloc] initWithSource:self.dataSource
                                                                path:std::move(path)
                                                        arrayElement:NO
                                                     fieldTransforms:_fieldTransforms
                                                           fieldMask:_fieldMask];
  [context validatePathSegment:util::MakeString(fieldName)];
  return context;
}

- (instancetype)contextForFieldPath:(const FieldPath &)fieldPath {
  std::unique_ptr<FieldPath> path;
  if (_path) {
    path = absl::make_unique<FieldPath>(_path->Append(fieldPath));
  }
  FSTParseContext *context = [[FSTParseContext alloc] initWithSource:self.dataSource
                                                                path:std::move(path)
                                                        arrayElement:NO
                                                     fieldTransforms:_fieldTransforms
                                                           fieldMask:_fieldMask];
  [context validatePath];
  return context;
}

- (instancetype)contextForArrayIndex:(NSUInteger)index {
  // TODO(b/34871131): We don't support array paths right now; so make path nil.
  return [[FSTParseContext alloc] initWithSource:self.dataSource
                                            path:nil
                                    arrayElement:YES
                                 fieldTransforms:_fieldTransforms
                                       fieldMask:_fieldMask];
}

/**
 * Returns a string that can be appended to error messages indicating what field caused the error.
 */
- (NSString *)fieldDescription {
  // TODO(b/34871131): Remove nil check once we have proper paths for fields within arrays.
  if (!_path || _path->empty()) {
    return @"";
  } else {
    return [NSString stringWithFormat:@" (found in field %s)", _path->CanonicalString().c_str()];
  }
}

- (BOOL)isWrite {
  switch (self.dataSource) {
    case FSTUserDataSourceSet:       // Falls through.
    case FSTUserDataSourceMergeSet:  // Falls through.
    case FSTUserDataSourceUpdate:
      return YES;
    case FSTUserDataSourceArgument:
      return NO;
    default:
      FSTThrowInvalidArgument(@"Unexpected case for FSTUserDataSource: %d", self.dataSource);
  }
}

- (BOOL)containsFieldPath:(const FieldPath &)fieldPath {
  for (const FieldPath &field : *_fieldMask) {
    if (fieldPath.IsPrefixOf(field)) {
      return YES;
    }
  }

  for (const FieldTransform &fieldTransform : *_fieldTransforms) {
    if (fieldPath.IsPrefixOf(fieldTransform.path())) {
      return YES;
    }
  }

  return NO;
}

- (void)validatePath {
  // TODO(b/34871131): Remove nil check once we have proper paths for fields within arrays.
  if (_path == nullptr) {
    return;
  }
  for (const std::string &segment : *_path) {
    [self validatePathSegment:segment];
  }
}

- (void)validatePathSegment:(absl::string_view)segment {
  absl::string_view designator{RESERVED_FIELD_DESIGNATOR};
  if ([self isWrite] && absl::StartsWith(segment, designator) &&
      absl::EndsWith(segment, designator)) {
    FSTThrowInvalidArgument(@"Document fields cannot begin and end with %s%@",
                            RESERVED_FIELD_DESIGNATOR, [self fieldDescription]);
  }
}

- (const FieldPath *)path {
  return _path.get();
}

- (const std::vector<FieldPath> *)fieldMask {
  return _fieldMask.get();
}

- (void)appendToFieldMaskWithFieldPath:(FieldPath)fieldPath {
  _fieldMask->push_back(std::move(fieldPath));
}

- (const std::vector<FieldTransform> *)fieldTransforms {
  return _fieldTransforms.get();
}

- (void)appendToFieldTransformsWithFieldPath:(FieldPath)fieldPath
                          transformOperation:
                              (std::unique_ptr<TransformOperation>)transformOperation {
  _fieldTransforms->emplace_back(std::move(fieldPath), std::move(transformOperation));
}

@end

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

- (FSTParsedSetData *)parsedMergeData:(id)input fieldMask:(nullable NSArray<id> *)fieldMask {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceMergeSet
                                    path:absl::make_unique<FieldPath>(FieldPath::EmptyPath())];
  FSTObjectValue *updateData = (FSTObjectValue *)[self parseData:input context:context];

  FieldMask convertedFieldMask;
  std::vector<FieldTransform> convertedFieldTransform;

  if (fieldMask) {
    __block std::vector<FieldPath> fieldMaskPaths;
    [fieldMask enumerateObjectsUsingBlock:^(id fieldPath, NSUInteger idx, BOOL *stop) {
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
      if (![context containsFieldPath:path]) {
        FSTThrowInvalidArgument(
            @"Field '%s' is specified in your field mask but missing from your input data.",
            path.CanonicalString().c_str());
      }

      fieldMaskPaths.push_back(path);
    }];
    convertedFieldMask = FieldMask(fieldMaskPaths);
    std::copy_if(context.fieldTransforms->begin(), context.fieldTransforms->end(),
                 std::back_inserter(convertedFieldTransform),
                 [&](const FieldTransform &fieldTransform) {
                   return convertedFieldMask.covers(fieldTransform.path());
                 });
  } else {
    convertedFieldMask = FieldMask{*context.fieldMask};
    convertedFieldTransform = *context.fieldTransforms;
  }

  return [[FSTParsedSetData alloc] initWithData:updateData
                                      fieldMask:convertedFieldMask
                                fieldTransforms:convertedFieldTransform];
}

- (FSTParsedSetData *)parsedSetData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceSet
                                    path:absl::make_unique<FieldPath>(FieldPath::EmptyPath())];
  FSTObjectValue *updateData = (FSTObjectValue *)[self parseData:input context:context];

  return
      [[FSTParsedSetData alloc] initWithData:updateData fieldTransforms:*context.fieldTransforms];
}

- (FSTParsedUpdateData *)parsedUpdateData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  NSDictionary *dict = input;

  __block std::vector<FieldPath> fieldMaskPaths;
  __block FSTObjectValue *updateData = [FSTObjectValue objectValue];

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceUpdate
                                    path:absl::make_unique<FieldPath>(FieldPath::EmptyPath())];
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
      fieldMaskPaths.push_back(path);
    } else {
      FSTFieldValue *_Nullable parsedValue =
          [self parseData:value context:[context contextForFieldPath:path]];
      if (parsedValue) {
        fieldMaskPaths.push_back(path);
        updateData = [updateData objectBySettingValue:parsedValue forPath:path];
      }
    }
  }];

  return [[FSTParsedUpdateData alloc] initWithData:updateData
                                         fieldMask:FieldMask{fieldMaskPaths}
                                   fieldTransforms:*context.fieldTransforms];
}

- (FSTFieldValue *)parsedQueryValue:(id)input {
  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceArgument
                                    path:absl::make_unique<FieldPath>(FieldPath::EmptyPath())];
  FSTFieldValue *_Nullable parsed = [self parseData:input context:context];
  HARD_ASSERT(parsed, "Parsed data should not be nil.");
  HARD_ASSERT(context.fieldTransforms->empty(), "Field transforms should have been disallowed.");
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
- (nullable FSTFieldValue *)parseData:(id)input context:(FSTParseContext *)context {
  input = self.preConverter(input);
  if ([input isKindOfClass:[NSDictionary class]]) {
    return [self parseDictionary:(NSDictionary *)input context:context];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    // FieldValues usually parse into transforms (except FieldValue.delete()) in which case we
    // do not want to include this field in our parsed data (as doing so will overwrite the field
    // directly prior to the transform trying to transform it). So we don't call appendToFieldMask
    // and we return nil as our parsing result.
    [self parseSentinelFieldValue:(FIRFieldValue *)input context:context];
    return nil;

  } else {
    // If context.path is nil we are already inside an array and we don't support field mask paths
    // more granular than the top-level array.
    if (context.path) {
      [context appendToFieldMaskWithFieldPath:*context.path];
    }

    if ([input isKindOfClass:[NSArray class]]) {
      // TODO(b/34871131): Include the path containing the array in the error message.
      if (context.isArrayElement) {
        FSTThrowInvalidArgument(@"Nested arrays are not supported");
      }
      return [self parseArray:(NSArray *)input context:context];
    } else {
      return [self parseScalarValue:input context:context];
    }
  }
}

- (FSTFieldValue *)parseDictionary:(NSDictionary *)dict context:(FSTParseContext *)context {
  NSMutableDictionary<NSString *, FSTFieldValue *> *result =
      [NSMutableDictionary dictionaryWithCapacity:dict.count];
  [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    FSTFieldValue *_Nullable parsedValue =
        [self parseData:value context:[context contextForField:key]];
    if (parsedValue) {
      result[key] = parsedValue;
    }
  }];
  return [[FSTObjectValue alloc] initWithDictionary:result];
}

- (FSTFieldValue *)parseArray:(NSArray *)array context:(FSTParseContext *)context {
  NSMutableArray<FSTFieldValue *> *result = [NSMutableArray arrayWithCapacity:array.count];
  [array enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL *stop) {
    FSTFieldValue *_Nullable parsedEntry =
        [self parseData:entry context:[context contextForArrayIndex:idx]];
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
- (void)parseSentinelFieldValue:(FIRFieldValue *)fieldValue context:(FSTParseContext *)context {
  // Sentinels are only supported with writes, and not within arrays.
  if (![context isWrite]) {
    FSTThrowInvalidArgument(@"%@ can only be used with updateData() and setData()%@",
                            fieldValue.methodName, [context fieldDescription]);
  }
  if (!context.path) {
    FSTThrowInvalidArgument(@"%@ is not currently supported inside arrays", fieldValue.methodName);
  }

  if ([fieldValue isKindOfClass:[FSTDeleteFieldValue class]]) {
    if (context.dataSource == FSTUserDataSourceMergeSet) {
      // No transform to add for a delete, but we need to add it to our fieldMask so it gets
      // deleted.
      [context appendToFieldMaskWithFieldPath:*context.path];
    } else if (context.dataSource == FSTUserDataSourceUpdate) {
      HARD_ASSERT(context.path->size() > 0,
                  "FieldValue.delete() at the top level should have already been handled.");
      FSTThrowInvalidArgument(
          @"FieldValue.delete() can only appear at the top level of your "
           "update data%@",
          [context fieldDescription]);
    } else {
      // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
      FSTThrowInvalidArgument(
          @"FieldValue.delete() can only be used with updateData() and setData() with "
          @"merge:true%@",
          [context fieldDescription]);
    }

  } else if ([fieldValue isKindOfClass:[FSTServerTimestampFieldValue class]]) {
    [context appendToFieldTransformsWithFieldPath:*context.path
                               transformOperation:absl::make_unique<ServerTimestampTransform>(
                                                      ServerTimestampTransform::Get())];

  } else if ([fieldValue isKindOfClass:[FSTArrayUnionFieldValue class]]) {
    std::vector<FSTFieldValue *> parsedElements =
        [self parseArrayTransformElements:((FSTArrayUnionFieldValue *)fieldValue).elements];
    auto array_union = absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayUnion,
                                                         std::move(parsedElements));
    [context appendToFieldTransformsWithFieldPath:*context.path
                               transformOperation:std::move(array_union)];

  } else if ([fieldValue isKindOfClass:[FSTArrayRemoveFieldValue class]]) {
    std::vector<FSTFieldValue *> parsedElements =
        [self parseArrayTransformElements:((FSTArrayRemoveFieldValue *)fieldValue).elements];
    auto array_remove = absl::make_unique<ArrayTransform>(TransformOperation::Type::ArrayRemove,
                                                          std::move(parsedElements));
    [context appendToFieldTransformsWithFieldPath:*context.path
                               transformOperation:std::move(array_remove)];

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
- (FSTFieldValue *)parseScalarValue:(nullable id)input context:(FSTParseContext *)context {
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
            FSTThrowInvalidArgument(@"NSNumber (%llu) is too large%@",
                                    [input unsignedLongLongValue], [context fieldDescription]);

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
          @"Document Reference is for database %s/%s but should be for database %s/%s%@",
          other->project_id().c_str(), other->database_id().c_str(),
          self.databaseID->project_id().c_str(), self.databaseID->database_id().c_str(),
          [context fieldDescription]);
    }
    return [FSTReferenceValue referenceValue:reference.key databaseID:self.databaseID];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    if ([input isKindOfClass:[FSTDeleteFieldValue class]]) {
      if (context.dataSource == FSTUserDataSourceMergeSet) {
        return nil;
      } else if (context.dataSource == FSTUserDataSourceUpdate) {
        HARD_ASSERT(context.path->size() > 0,
                    "FieldValue.delete() at the top level should have already been handled.");
        FSTThrowInvalidArgument(
            @"FieldValue.delete() can only appear at the top level of your update data%@",
            [context fieldDescription]);
      } else {
        // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
        FSTThrowInvalidArgument(
            @"FieldValue.delete() can only be used with updateData() and setData() with "
            @"merge: true.");
      }
    } else if ([input isKindOfClass:[FSTServerTimestampFieldValue class]]) {
      if (![context isWrite]) {
        FSTThrowInvalidArgument(
            @"FieldValue.serverTimestamp() can only be used with setData() and updateData().");
      }
      if (!context.path) {
        FSTThrowInvalidArgument(
            @"FieldValue.serverTimestamp() is not currently supported inside arrays%@",
            [context fieldDescription]);
      }
      [context appendToFieldTransformsWithFieldPath:*context.path
                                 transformOperation:absl::make_unique<ServerTimestampTransform>(
                                                        ServerTimestampTransform::Get())];

      // Return nil so this value is omitted from the parsed result.
      return nil;
    } else {
      HARD_FAIL("Unknown FIRFieldValue type: %s", NSStringFromClass([input class]));
    }

  } else {
    FSTThrowInvalidArgument(@"Unsupported type: %@%@", NSStringFromClass([input class]),
                            [context fieldDescription]);
  }
}

- (std::vector<FSTFieldValue *>)parseArrayTransformElements:(NSArray<id> *)elements {
  std::vector<FSTFieldValue *> results;
  for (NSUInteger i = 0; i < elements.count; i++) {
    id element = elements[i];
    // Although array transforms are used with writes, the actual elements being unioned or removed
    // are not considered writes since they cannot contain any FieldValue sentinels, etc.
    FSTParseContext *context =
        [FSTParseContext contextWithSource:FSTUserDataSourceArgument
                                      path:absl::make_unique<FieldPath>(FieldPath::EmptyPath())];
    FSTFieldValue *parsedElement =
        [self parseData:element context:[context contextForArrayIndex:i]];
    HARD_ASSERT(parsedElement && context.fieldTransforms->size() == 0,
                "Failed to properly parse array transform element: %s", element);
    results.push_back(parsedElement);
  }
  return results;
}

@end

NS_ASSUME_NONNULL_END
