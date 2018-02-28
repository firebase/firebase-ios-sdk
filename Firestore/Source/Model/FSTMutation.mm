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

#import "Firestore/Source/Model/FSTMutation.h"

#import "FIRTimestamp.h"

#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTFieldMask

@implementation FSTFieldMask

- (instancetype)initWithFields:(NSArray<FSTFieldPath *> *)fields {
  if (self = [super init]) {
    _fields = fields;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTFieldMask class]]) {
    return NO;
  }

  FSTFieldMask *otherMask = (FSTFieldMask *)other;
  return [self.fields isEqual:otherMask.fields];
}

- (NSUInteger)hash {
  return self.fields.hash;
}
@end

#pragma mark - FSTServerTimestampTransform

@implementation FSTServerTimestampTransform

+ (instancetype)serverTimestampTransform {
  static FSTServerTimestampTransform *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTServerTimestampTransform alloc] init];
  });
  return sharedInstance;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  return [other isKindOfClass:[FSTServerTimestampTransform class]];
}

- (NSUInteger)hash {
  // arbitrary number since all instances are equal.
  return 37;
}

@end

#pragma mark - FSTFieldTransform

@implementation FSTFieldTransform

- (instancetype)initWithPath:(FSTFieldPath *)path transform:(id<FSTTransformOperation>)transform {
  self = [super init];
  if (self) {
    _path = path;
    _transform = transform;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;
  FSTFieldTransform *otherFieldTransform = other;
  return [self.path isEqual:otherFieldTransform.path] &&
         [self.transform isEqual:otherFieldTransform.transform];
}

- (NSUInteger)hash {
  NSUInteger hash = [self.path hash];
  hash = hash * 31 + [self.transform hash];
  return hash;
}

@end

#pragma mark - FSTPrecondition

@implementation FSTPrecondition

+ (FSTPrecondition *)preconditionWithExists:(BOOL)exists {
  FSTPreconditionExists existsEnum = exists ? FSTPreconditionExistsYes : FSTPreconditionExistsNo;
  return [[FSTPrecondition alloc] initWithUpdateTime:nil exists:existsEnum];
}

+ (FSTPrecondition *)preconditionWithUpdateTime:(FSTSnapshotVersion *)updateTime {
  return [[FSTPrecondition alloc] initWithUpdateTime:updateTime exists:FSTPreconditionExistsNotSet];
}

+ (FSTPrecondition *)none {
  static dispatch_once_t onceToken;
  static FSTPrecondition *noPrecondition;
  dispatch_once(&onceToken, ^{
    noPrecondition =
        [[FSTPrecondition alloc] initWithUpdateTime:nil exists:FSTPreconditionExistsNotSet];
  });
  return noPrecondition;
}

- (instancetype)initWithUpdateTime:(FSTSnapshotVersion *_Nullable)updateTime
                            exists:(FSTPreconditionExists)exists {
  if (self = [super init]) {
    _updateTime = updateTime;
    _exists = exists;
  }
  return self;
}

- (BOOL)isValidForDocument:(FSTMaybeDocument *_Nullable)maybeDoc {
  if (self.updateTime) {
    return
        [maybeDoc isKindOfClass:[FSTDocument class]] && [maybeDoc.version isEqual:self.updateTime];
  } else if (self.exists != FSTPreconditionExistsNotSet) {
    if (self.exists == FSTPreconditionExistsYes) {
      return [maybeDoc isKindOfClass:[FSTDocument class]];
    } else {
      FSTAssert(self.exists == FSTPreconditionExistsNo, @"Invalid precondition");
      return maybeDoc == nil || [maybeDoc isKindOfClass:[FSTDeletedDocument class]];
    }
  } else {
    FSTAssert(self.isNone, @"Precondition should be empty");
    return YES;
  }
}

- (BOOL)isNone {
  return self.updateTime == nil && self.exists == FSTPreconditionExistsNotSet;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  }

  if (![other isKindOfClass:[FSTPrecondition class]]) {
    return NO;
  }

  FSTPrecondition *otherPrecondition = (FSTPrecondition *)other;
  // Compare references to cover nil equality
  return (self.updateTime == otherPrecondition.updateTime ||
          [self.updateTime isEqual:otherPrecondition.updateTime]) &&
         self.exists == otherPrecondition.exists;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.updateTime hash];
  hash = hash * 31 + self.exists;
  return hash;
}

- (NSString *)description {
  if (self.isNone) {
    return @"<FSTPrecondition <none>>";
  } else {
    NSString *existsString;
    switch (self.exists) {
      case FSTPreconditionExistsYes:
        existsString = @"yes";
        break;
      case FSTPreconditionExistsNo:
        existsString = @"no";
        break;
      default:
        existsString = @"<not-set>";
        break;
    }
    return [NSString stringWithFormat:@"<FSTPrecondition updateTime=%@ exists=%@>", self.updateTime,
                                      existsString];
  }
}

@end

#pragma mark - FSTMutationResult

@implementation FSTMutationResult

- (instancetype)initWithVersion:(FSTSnapshotVersion *_Nullable)version
               transformResults:(NSArray<FSTFieldValue *> *_Nullable)transformResults {
  if (self = [super init]) {
    _version = version;
    _transformResults = transformResults;
  }
  return self;
}

@end

#pragma mark - FSTMutation

@implementation FSTMutation

- (instancetype)initWithKey:(FSTDocumentKey *)key precondition:(FSTPrecondition *)precondition {
  if (self = [super init]) {
    _key = key;
    _precondition = precondition;
  }
  return self;
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(nullable FIRTimestamp *)localWriteTime {
  return
      [self applyTo:maybeDoc baseDocument:baseDoc localWriteTime:localWriteTime mutationResult:nil];
}

@end

#pragma mark - FSTSetMutation

@implementation FSTSetMutation

- (instancetype)initWithKey:(FSTDocumentKey *)key
                      value:(FSTObjectValue *)value
               precondition:(FSTPrecondition *)precondition {
  if (self = [super initWithKey:key precondition:precondition]) {
    _value = value;
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTSetMutation key=%@ value=%@ precondition=%@>", self.key,
                                    self.value, self.precondition];
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTSetMutation class]]) {
    return NO;
  }

  FSTSetMutation *otherMutation = (FSTSetMutation *)other;
  return [self.key isEqual:otherMutation.key] && [self.value isEqual:otherMutation.value] &&
         [self.precondition isEqual:otherMutation.precondition];
}

- (NSUInteger)hash {
  NSUInteger result = [self.key hash];
  result = 31 * result + [self.precondition hash];
  result = 31 * result + [self.value hash];
  return result;
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult {
  if (mutationResult) {
    FSTAssert(!mutationResult.transformResults, @"Transform results received by FSTSetMutation.");
  }

  if (![self.precondition isValidForDocument:maybeDoc]) {
    return maybeDoc;
  }

  BOOL hasLocalMutations = (mutationResult == nil);
  if (!maybeDoc || [maybeDoc isMemberOfClass:[FSTDeletedDocument class]]) {
    // If the document didn't exist before, create it.
    return [FSTDocument documentWithData:self.value
                                     key:self.key
                                 version:[FSTSnapshotVersion noVersion]
                       hasLocalMutations:hasLocalMutations];
  }

  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown MaybeDocument type %@",
            [maybeDoc class]);
  FSTDocument *doc = (FSTDocument *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only set a document with the same key");
  return [FSTDocument documentWithData:self.value
                                   key:doc.key
                               version:doc.version
                     hasLocalMutations:hasLocalMutations];
}
@end

#pragma mark - FSTPatchMutation

@implementation FSTPatchMutation

- (instancetype)initWithKey:(FSTDocumentKey *)key
                  fieldMask:(FSTFieldMask *)fieldMask
                      value:(FSTObjectValue *)value
               precondition:(FSTPrecondition *)precondition {
  self = [super initWithKey:key precondition:precondition];
  if (self) {
    _fieldMask = fieldMask;
    _value = value;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTPatchMutation class]]) {
    return NO;
  }

  FSTPatchMutation *otherMutation = (FSTPatchMutation *)other;
  return [self.key isEqual:otherMutation.key] && [self.fieldMask isEqual:otherMutation.fieldMask] &&
         [self.value isEqual:otherMutation.value] &&
         [self.precondition isEqual:otherMutation.precondition];
}

- (NSUInteger)hash {
  NSUInteger result = [self.key hash];
  result = 31 * result + [self.precondition hash];
  result = 31 * result + [self.fieldMask hash];
  result = 31 * result + [self.value hash];
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTPatchMutation key=%@ mask=%@ value=%@ precondition=%@>",
                                    self.key, self.fieldMask, self.value, self.precondition];
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult {
  if (mutationResult) {
    FSTAssert(!mutationResult.transformResults, @"Transform results received by FSTPatchMutation.");
  }

  if (![self.precondition isValidForDocument:maybeDoc]) {
    return maybeDoc;
  }

  BOOL hasLocalMutations = (mutationResult == nil);
  if (!maybeDoc || [maybeDoc isMemberOfClass:[FSTDeletedDocument class]]) {
    // Precondition applied, so create the document if necessary
    FSTDocumentKey *key = maybeDoc ? maybeDoc.key : self.key;
    FSTSnapshotVersion *version = maybeDoc ? maybeDoc.version : [FSTSnapshotVersion noVersion];
    maybeDoc = [FSTDocument documentWithData:[FSTObjectValue objectValue]
                                         key:key
                                     version:version
                           hasLocalMutations:hasLocalMutations];
  }

  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown MaybeDocument type %@",
            [maybeDoc class]);
  FSTDocument *doc = (FSTDocument *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only patch a document with the same key");

  FSTObjectValue *newData = [self patchObjectValue:doc.data];
  return [FSTDocument documentWithData:newData
                                   key:doc.key
                               version:doc.version
                     hasLocalMutations:hasLocalMutations];
}

- (FSTObjectValue *)patchObjectValue:(FSTObjectValue *)objectValue {
  FSTObjectValue *result = objectValue;
  for (FSTFieldPath *fieldPath in self.fieldMask.fields) {
    FSTFieldValue *newValue = [self.value valueForPath:fieldPath];
    if (newValue) {
      result = [result objectBySettingValue:newValue forPath:fieldPath];
    } else {
      result = [result objectByDeletingPath:fieldPath];
    }
  }
  return result;
}

@end

@implementation FSTTransformMutation

- (instancetype)initWithKey:(FSTDocumentKey *)key
            fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms {
  // NOTE: We set a precondition of exists: true as a safety-check, since we always combine
  // FSTTransformMutations with a FSTSetMutation or FSTPatchMutation which (if successful) should
  // end up with an existing document.
  if (self = [super initWithKey:key precondition:[FSTPrecondition preconditionWithExists:YES]]) {
    _fieldTransforms = fieldTransforms;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTTransformMutation class]]) {
    return NO;
  }

  FSTTransformMutation *otherMutation = (FSTTransformMutation *)other;
  return [self.key isEqual:otherMutation.key] &&
         [self.fieldTransforms isEqual:otherMutation.fieldTransforms] &&
         [self.precondition isEqual:otherMutation.precondition];
}

- (NSUInteger)hash {
  NSUInteger result = [self.key hash];
  result = 31 * result + [self.precondition hash];
  result = 31 * result + [self.fieldTransforms hash];
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTTransformMutation key=%@ transforms=%@ precondition=%@>",
                                    self.key, self.fieldTransforms, self.precondition];
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult {
  if (mutationResult) {
    FSTAssert(mutationResult.transformResults,
              @"Transform results missing for FSTTransformMutation.");
  }

  if (![self.precondition isValidForDocument:maybeDoc]) {
    return maybeDoc;
  }

  // We only support transforms with precondition exists, so we can only apply it to an existing
  // document
  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown MaybeDocument type %@",
            [maybeDoc class]);
  FSTDocument *doc = (FSTDocument *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only patch a document with the same key");

  BOOL hasLocalMutations = (mutationResult == nil);
  NSArray<FSTFieldValue *> *transformResults =
      mutationResult
          ? mutationResult.transformResults
          : [self localTransformResultsWithBaseDocument:baseDoc writeTime:localWriteTime];
  FSTObjectValue *newData = [self transformObject:doc.data transformResults:transformResults];
  return [FSTDocument documentWithData:newData
                                   key:doc.key
                               version:doc.version
                     hasLocalMutations:hasLocalMutations];
}

/**
 * Creates an array of "transform results" (a transform result is a field value representing the
 * result of applying a transform) for use when applying an FSTTransformMutation locally.
 *
 * @param baseDocument The document prior to applying this mutation batch.
 * @param localWriteTime The local time of the transform mutation (used to generate
 * FSTServerTimestampValues).
 * @return The transform results array.
 */
- (NSArray<FSTFieldValue *> *)localTransformResultsWithBaseDocument:
                                  (FSTMaybeDocument *_Nullable)baseDocument
                                                          writeTime:(FIRTimestamp *)localWriteTime {
  NSMutableArray<FSTFieldValue *> *transformResults = [NSMutableArray array];
  for (FSTFieldTransform *fieldTransform in self.fieldTransforms) {
    if ([fieldTransform.transform isKindOfClass:[FSTServerTimestampTransform class]]) {
      FSTFieldValue *previousValue = nil;

      if ([baseDocument isMemberOfClass:[FSTDocument class]]) {
        previousValue = [((FSTDocument *)baseDocument) fieldForPath:fieldTransform.path];
      }

      [transformResults
          addObject:[FSTServerTimestampValue serverTimestampValueWithLocalWriteTime:localWriteTime
                                                                      previousValue:previousValue]];
    } else {
      FSTFail(@"Encountered unknown transform: %@", fieldTransform);
    }
  }
  return transformResults;
}

- (FSTObjectValue *)transformObject:(FSTObjectValue *)objectValue
                   transformResults:(NSArray<FSTFieldValue *> *)transformResults {
  FSTAssert(transformResults.count == self.fieldTransforms.count,
            @"Transform results length mismatch.");

  for (NSUInteger i = 0; i < self.fieldTransforms.count; i++) {
    FSTFieldTransform *fieldTransform = self.fieldTransforms[i];
    id<FSTTransformOperation> transform = fieldTransform.transform;
    FSTFieldPath *fieldPath = fieldTransform.path;
    if ([transform isKindOfClass:[FSTServerTimestampTransform class]]) {
      objectValue = [objectValue objectBySettingValue:transformResults[i] forPath:fieldPath];
    } else {
      FSTFail(@"Encountered unknown transform: %@", transform);
    }
  }
  return objectValue;
}

@end

#pragma mark - FSTDeleteMutation

@implementation FSTDeleteMutation

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTDeleteMutation class]]) {
    return NO;
  }

  FSTDeleteMutation *otherMutation = (FSTDeleteMutation *)other;
  return [self.key isEqual:otherMutation.key] &&
         [self.precondition isEqual:otherMutation.precondition];
}

- (NSUInteger)hash {
  NSUInteger result = [self.key hash];
  result = 31 * result + [self.precondition hash];
  return result;
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTDeleteMutation key=%@ precondition=%@>", self.key, self.precondition];
}

- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult {
  if (mutationResult) {
    FSTAssert(!mutationResult.transformResults,
              @"Transform results received by FSTDeleteMutation.");
  }

  if (![self.precondition isValidForDocument:maybeDoc]) {
    return maybeDoc;
  }

  if (maybeDoc) {
    FSTAssert([maybeDoc.key isEqual:self.key], @"Can only delete a document with the same key");
  }

  return [FSTDeletedDocument documentWithKey:self.key version:[FSTSnapshotVersion noVersion]];
}

@end

NS_ASSUME_NONNULL_END
