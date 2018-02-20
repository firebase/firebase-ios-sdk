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

#import "FIRTimestamp.h"

#import "FIRGeoPoint.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRSetOptions+Internal.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const RESERVED_FIELD_DESIGNATOR = @"__";

#pragma mark - FSTParsedSetData

@implementation FSTParsedSetData
- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(nullable FSTFieldMask *)fieldMask
             fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms {
  self = [super init];
  if (self) {
    _data = data;
    _fieldMask = fieldMask;
    _fieldTransforms = fieldTransforms;
  }
  return self;
}

- (NSArray<FSTMutation *> *)mutationsWithKey:(FSTDocumentKey *)key
                                precondition:(FSTPrecondition *)precondition {
  NSMutableArray<FSTMutation *> *mutations = [NSMutableArray array];
  if (self.fieldMask) {
    [mutations addObject:[[FSTPatchMutation alloc] initWithKey:key
                                                     fieldMask:self.fieldMask
                                                         value:self.data
                                                  precondition:precondition]];
  } else {
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:key
                                                       value:self.data
                                                precondition:precondition]];
  }
  if (self.fieldTransforms.count > 0) {
    [mutations addObject:[[FSTTransformMutation alloc] initWithKey:key
                                                   fieldTransforms:self.fieldTransforms]];
  }
  return mutations;
}

@end

#pragma mark - FSTParsedUpdateData

@implementation FSTParsedUpdateData
- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(FSTFieldMask *)fieldMask
             fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms {
  self = [super init];
  if (self) {
    _data = data;
    _fieldMask = fieldMask;
    _fieldTransforms = fieldTransforms;
  }
  return self;
}

- (NSArray<FSTMutation *> *)mutationsWithKey:(FSTDocumentKey *)key
                                precondition:(FSTPrecondition *)precondition {
  NSMutableArray<FSTMutation *> *mutations = [NSMutableArray array];
  [mutations addObject:[[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:self.fieldMask
                                                       value:self.data
                                                precondition:precondition]];
  if (self.fieldTransforms.count > 0) {
    [mutations addObject:[[FSTTransformMutation alloc] initWithKey:key
                                                   fieldTransforms:self.fieldTransforms]];
  }
  return mutations;
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
  FSTUserDataSourceQueryValue,  // from a where clause or cursor bound.
};

#pragma mark - FSTParseContext

/**
 * A "context" object passed around while parsing user data.
 */
@interface FSTParseContext : NSObject
/** The current path being parsed. */
// TODO(b/34871131): path should never be nil, but we don't support array paths right now.
@property(nonatomic, strong, readonly, nullable) FSTFieldPath *path;

/** Whether or not this context corresponds to an element of an array. */
@property(nonatomic, assign, readonly, getter=isArrayElement) BOOL arrayElement;

/**
 * What type of API method provided the data being parsed; useful for determining which error
 * conditions apply during parsing and providing better error messages.
 */
@property(nonatomic, assign) FSTUserDataSource dataSource;
@property(nonatomic, strong, readonly) NSMutableArray<FSTFieldTransform *> *fieldTransforms;
@property(nonatomic, strong, readonly) NSMutableArray<FSTFieldPath *> *fieldMask;

- (instancetype)init NS_UNAVAILABLE;
/**
 * Initializes a FSTParseContext with the given source and path.
 *
 * @param dataSource Indicates what kind of API method this data came from.
 * @param path A path within the object being parsed. This could be an empty path (in which case
 *   the context represents the root of the data being parsed), or a nonempty path (indicating the
 *   context represents a nested location within the data).
 *
 * TODO(b/34871131): We don't support array paths right now, so path can be nil to indicate
 * the context represents any location within an array (in which case certain features will not work
 * and errors will be somewhat compromised).
 */
- (instancetype)initWithSource:(FSTUserDataSource)dataSource
                          path:(nullable FSTFieldPath *)path
                  arrayElement:(BOOL)arrayElement
               fieldTransforms:(NSMutableArray<FSTFieldTransform *> *)fieldTransforms
                     fieldMask:(NSMutableArray<FSTFieldPath *> *)fieldMask
    NS_DESIGNATED_INITIALIZER;

// Helpers to get a FSTParseContext for a child field.
- (instancetype)contextForField:(NSString *)fieldName;
- (instancetype)contextForFieldPath:(FSTFieldPath *)fieldPath;
- (instancetype)contextForArrayIndex:(NSUInteger)index;

/** Returns true for the non-query parse contexts (Set, MergeSet and Update) */
- (BOOL)isWrite;
@end

@implementation FSTParseContext

+ (instancetype)contextWithSource:(FSTUserDataSource)dataSource path:(nullable FSTFieldPath *)path {
  FSTParseContext *context = [[FSTParseContext alloc] initWithSource:dataSource
                                                                path:path
                                                        arrayElement:NO
                                                     fieldTransforms:[NSMutableArray array]
                                                           fieldMask:[NSMutableArray array]];
  [context validatePath];
  return context;
}

- (instancetype)initWithSource:(FSTUserDataSource)dataSource
                          path:(nullable FSTFieldPath *)path
                  arrayElement:(BOOL)arrayElement
               fieldTransforms:(NSMutableArray<FSTFieldTransform *> *)fieldTransforms
                     fieldMask:(NSMutableArray<FSTFieldPath *> *)fieldMask {
  if (self = [super init]) {
    _dataSource = dataSource;
    _path = path;
    _arrayElement = arrayElement;
    _fieldTransforms = fieldTransforms;
    _fieldMask = fieldMask;
  }
  return self;
}

- (instancetype)contextForField:(NSString *)fieldName {
  FSTParseContext *context =
      [[FSTParseContext alloc] initWithSource:self.dataSource
                                         path:[self.path pathByAppendingSegment:fieldName]
                                 arrayElement:NO
                              fieldTransforms:self.fieldTransforms
                                    fieldMask:self.fieldMask];
  [context validatePathSegment:fieldName];
  return context;
}

- (instancetype)contextForFieldPath:(FSTFieldPath *)fieldPath {
  FSTParseContext *context =
      [[FSTParseContext alloc] initWithSource:self.dataSource
                                         path:[self.path pathByAppendingPath:fieldPath]
                                 arrayElement:NO
                              fieldTransforms:self.fieldTransforms
                                    fieldMask:self.fieldMask];
  [context validatePath];
  return context;
}

- (instancetype)contextForArrayIndex:(NSUInteger)index {
  // TODO(b/34871131): We don't support array paths right now; so make path nil.
  return [[FSTParseContext alloc] initWithSource:self.dataSource
                                            path:nil
                                    arrayElement:YES
                                 fieldTransforms:self.fieldTransforms
                                       fieldMask:self.fieldMask];
}

/**
 * Returns a string that can be appended to error messages indicating what field caused the error.
 */
- (NSString *)fieldDescription {
  // TODO(b/34871131): Remove nil check once we have proper paths for fields within arrays.
  if (!self.path || self.path.empty) {
    return @"";
  } else {
    return [NSString stringWithFormat:@" (found in field %@)", self.path];
  }
}

- (BOOL)isWrite {
  switch (self.dataSource) {
    case FSTUserDataSourceSet:       // Falls through.
    case FSTUserDataSourceMergeSet:  // Falls through.
    case FSTUserDataSourceUpdate:
      return YES;
    case FSTUserDataSourceQueryValue:
      return NO;
    default:
      FSTThrowInvalidArgument(@"Unexpected case for FSTUserDataSource: %d", self.dataSource);
  }
}

- (void)validatePath {
  // TODO(b/34871131): Remove nil check once we have proper paths for fields within arrays.
  if (self.path == nil) {
    return;
  }
  for (int i = 0; i < self.path.length; i++) {
    [self validatePathSegment:[self.path segmentAtIndex:i]];
  }
}

- (void)validatePathSegment:(NSString *)segment {
  if ([self isWrite] && [segment hasPrefix:RESERVED_FIELD_DESIGNATOR] &&
      [segment hasSuffix:RESERVED_FIELD_DESIGNATOR]) {
    FSTThrowInvalidArgument(@"Document fields cannot begin and end with %@%@",
                            RESERVED_FIELD_DESIGNATOR, [self fieldDescription]);
  }
}

@end

#pragma mark - FSTDocumentKeyReference

@implementation FSTDocumentKeyReference

- (instancetype)initWithKey:(FSTDocumentKey *)key databaseID:(const DatabaseId *)databaseID {
  self = [super init];
  if (self) {
    _key = key;
    _databaseID = databaseID;
  }
  return self;
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

- (FSTParsedSetData *)parsedMergeData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceMergeSet path:[FSTFieldPath emptyPath]];
  FSTObjectValue *updateData = (FSTObjectValue *)[self parseData:input context:context];

  return
      [[FSTParsedSetData alloc] initWithData:updateData
                                   fieldMask:[[FSTFieldMask alloc] initWithFields:context.fieldMask]
                             fieldTransforms:context.fieldTransforms];
}

- (FSTParsedSetData *)parsedSetData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceSet path:[FSTFieldPath emptyPath]];
  FSTObjectValue *updateData = (FSTObjectValue *)[self parseData:input context:context];

  return [[FSTParsedSetData alloc] initWithData:updateData
                                      fieldMask:nil
                                fieldTransforms:context.fieldTransforms];
}

- (FSTParsedUpdateData *)parsedUpdateData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    FSTThrowInvalidArgument(@"Data to be written must be an NSDictionary.");
  }

  NSDictionary *dict = input;

  NSMutableArray<FSTFieldPath *> *fieldMaskPaths = [NSMutableArray array];
  __block FSTObjectValue *updateData = [FSTObjectValue objectValue];

  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceUpdate path:[FSTFieldPath emptyPath]];
  [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    FSTFieldPath *path;

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
      [fieldMaskPaths addObject:path];
    } else {
      FSTFieldValue *_Nullable parsedValue =
          [self parseData:value context:[context contextForFieldPath:path]];
      if (parsedValue) {
        [fieldMaskPaths addObject:path];
        updateData = [updateData objectBySettingValue:parsedValue forPath:path];
      }
    }
  }];

  FSTFieldMask *mask = [[FSTFieldMask alloc] initWithFields:fieldMaskPaths];
  return [[FSTParsedUpdateData alloc] initWithData:updateData
                                         fieldMask:mask
                                   fieldTransforms:context.fieldTransforms];
}

- (FSTFieldValue *)parsedQueryValue:(id)input {
  FSTParseContext *context =
      [FSTParseContext contextWithSource:FSTUserDataSourceQueryValue path:[FSTFieldPath emptyPath]];
  FSTFieldValue *_Nullable parsed = [self parseData:input context:context];
  FSTAssert(parsed, @"Parsed data should not be nil.");
  FSTAssert(context.fieldTransforms.count == 0, @"Field transforms should have been disallowed.");
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
  if ([input isKindOfClass:[NSArray class]]) {
    // TODO(b/34871131): Include the path containing the array in the error message.
    if (context.isArrayElement) {
      FSTThrowInvalidArgument(@"Nested arrays are not supported");
    }
    NSArray *array = input;
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
    // If context.path is nil we are already inside an array and we don't support field mask paths
    // more granular than the top-level array.
    if (context.path) {
      [context.fieldMask addObject:context.path];
    }
    return [[FSTArrayValue alloc] initWithValueNoCopy:result];

  } else if ([input isKindOfClass:[NSDictionary class]]) {
    NSDictionary *dict = input;
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

  } else {
    // If context.path is null, we are inside an array and we should have already added the root of
    // the array to the field mask.
    if (context.path) {
      [context.fieldMask addObject:context.path];
    }
    return [self parseScalarValue:input context:context];
  }
}

/**
 * Helper to parse a scalar value (i.e. not an NSDictionary or NSArray).
 *
 * Note that it handles all NSNumber values that are encodable as int64_t or doubles
 * (depending on the underlying type of the NSNumber). Unsigned integer values are handled though
 * any value outside what is representable by int64_t (a signed 64-bit value) will throw an
 * exception.
 *
 * @return The parsed value, or nil if the value was a FieldValue sentinel that should not be
 *   included in the resulting parsed data.
 */
- (nullable FSTFieldValue *)parseScalarValue:(nullable id)input context:(FSTParseContext *)context {
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
        FSTCFail(@"Unknown NSNumber objCType %s on %@", cType, input);
    }

  } else if ([input isKindOfClass:[NSString class]]) {
    return [FSTStringValue stringValue:input];

  } else if ([input isKindOfClass:[NSDate class]]) {
    return [FSTTimestampValue timestampValue:[FIRTimestamp timestampWithDate:input]];

  } else if ([input isKindOfClass:[FIRGeoPoint class]]) {
    return [FSTGeoPointValue geoPointValue:input];

  } else if ([input isKindOfClass:[NSData class]]) {
    return [FSTBlobValue blobValue:input];

  } else if ([input isKindOfClass:[FSTDocumentKeyReference class]]) {
    FSTDocumentKeyReference *reference = input;
    if (*reference.databaseID != *self.databaseID) {
      const DatabaseId *other = reference.databaseID;
      FSTThrowInvalidArgument(
          @"Document Reference is for database %@/%@ but should be for database %@/%@%@",
          util::WrapNSStringNoCopy(other->project_id()),
          util::WrapNSStringNoCopy(other->database_id()),
          util::WrapNSStringNoCopy(self.databaseID->project_id()),
          util::WrapNSStringNoCopy(self.databaseID->database_id()), [context fieldDescription]);
    }
    return [FSTReferenceValue referenceValue:reference.key databaseID:self.databaseID];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    if ([input isKindOfClass:[FSTDeleteFieldValue class]]) {
      if (context.dataSource == FSTUserDataSourceMergeSet) {
        return nil;
      } else if (context.dataSource == FSTUserDataSourceUpdate) {
        FSTAssert(context.path.length > 0,
                  @"FieldValue.delete() at the top level should have already been handled.");
        FSTThrowInvalidArgument(
            @"FieldValue.delete() can only appear at the top level of your "
             "update data%@",
            [context fieldDescription]);
      } else {
        // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
        FSTThrowInvalidArgument(
            @"FieldValue.delete() can only be used with updateData() and setData() with "
            @"SetOptions.merge().");
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
      [context.fieldTransforms
          addObject:[[FSTFieldTransform alloc]
                        initWithPath:context.path
                           transform:[FSTServerTimestampTransform serverTimestampTransform]]];

      // Return nil so this value is omitted from the parsed result.
      return nil;
    } else {
      FSTFail(@"Unknown FIRFieldValue type: %@", NSStringFromClass([input class]));
    }

  } else {
    FSTThrowInvalidArgument(@"Unsupported type: %@%@", NSStringFromClass([input class]),
                            [context fieldDescription]);
  }
}

@end

NS_ASSUME_NONNULL_END
