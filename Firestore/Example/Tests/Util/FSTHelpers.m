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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#import <FirebaseFirestore/FIRFieldPath.h>
#import <FirebaseFirestore/FIRGeoPoint.h>

#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Core/FSTTimestamp.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"

NS_ASSUME_NONNULL_BEGIN

/** A string sentinel that can be used with FSTTestPatchMutation() to mark a field for deletion. */
static NSString *const kDeleteSentinel = @"<DELETE>";

static const int kMicrosPerSec = 1000000;
static const int kMillisPerSec = 1000;

FSTTimestamp *FSTTestTimestamp(int year, int month, int day, int hour, int minute, int second) {
  NSDate *date = FSTTestDate(year, month, day, hour, minute, second);
  return [FSTTimestamp timestampWithDate:date];
}

NSDate *FSTTestDate(int year, int month, int day, int hour, int minute, int second) {
  NSDateComponents *comps = FSTTestDateComponents(year, month, day, hour, minute, second);
  return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

NSData *FSTTestData(int bytes, ...) {
  va_list args;
  va_start(args, bytes); /* Initialize the argument list. */

  NSMutableData *data = [NSMutableData data];

  int next = bytes;
  while (next >= 0) {
    uint8_t byte = (uint8_t)next;
    [data appendBytes:&byte length:1];
    next = va_arg(args, int);
  }

  va_end(args);
  return [data copy];
}

FIRGeoPoint *FSTTestGeoPoint(double latitude, double longitude) {
  return [[FIRGeoPoint alloc] initWithLatitude:latitude longitude:longitude];
}

NSDateComponents *FSTTestDateComponents(
    int year, int month, int day, int hour, int minute, int second) {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  comps.year = year;
  comps.month = month;
  comps.day = day;
  comps.hour = hour;
  comps.minute = minute;
  comps.second = second;

  // Force time zone to UTC to avoid these values changing due to daylight saving.
  comps.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
  return comps;
}

FSTFieldPath *FSTTestFieldPath(NSString *field) {
  return [FIRFieldPath pathWithDotSeparatedString:field].internalValue;
}

FSTFieldValue *FSTTestFieldValue(id _Nullable value) {
  FSTDatabaseID *databaseID =
      [FSTDatabaseID databaseIDWithProject:@"project" database:kDefaultDatabaseID];
  FSTUserDataConverter *converter =
      [[FSTUserDataConverter alloc] initWithDatabaseID:databaseID
                                          preConverter:^id _Nullable(id _Nullable input) {
                                            return input;
                                          }];
  // HACK: We use parsedQueryValue: since it accepts scalars as well as arrays / objects, and
  // our tests currently use FSTTestFieldValue() pretty generically so we don't know the intent.
  return [converter parsedQueryValue:value];
}

FSTObjectValue *FSTTestObjectValue(NSDictionary<NSString *, id> *data) {
  FSTFieldValue *wrapped = FSTTestFieldValue(data);
  FSTCAssert([wrapped isKindOfClass:[FSTObjectValue class]], @"Unsupported value: %@", data);
  return (FSTObjectValue *)wrapped;
}

FSTDocumentKey *FSTTestDocKey(NSString *path) {
  return [FSTDocumentKey keyWithPathString:path];
}

FSTDocumentKeySet *FSTTestDocKeySet(NSArray<FSTDocumentKey *> *keys) {
  FSTDocumentKeySet *result = [FSTDocumentKeySet keySet];
  for (FSTDocumentKey *key in keys) {
    result = [result setByAddingObject:key];
  }
  return result;
}

FSTSnapshotVersion *FSTTestVersion(FSTTestSnapshotVersion versionMicroseconds) {
  int64_t seconds = versionMicroseconds / kMicrosPerSec;
  int32_t nanos = (int32_t)(versionMicroseconds % kMicrosPerSec) * kMillisPerSec;

  FSTTimestamp *timestamp = [[FSTTimestamp alloc] initWithSeconds:seconds nanos:nanos];
  return [FSTSnapshotVersion versionWithTimestamp:timestamp];
}

FSTDocument *FSTTestDoc(NSString *path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        BOOL hasMutations) {
  FSTDocumentKey *key = FSTTestDocKey(path);
  return [FSTDocument documentWithData:FSTTestObjectValue(data)
                                   key:key
                               version:FSTTestVersion(version)
                     hasLocalMutations:hasMutations];
}

FSTDeletedDocument *FSTTestDeletedDoc(NSString *path, FSTTestSnapshotVersion version) {
  FSTDocumentKey *key = FSTTestDocKey(path);
  return [FSTDeletedDocument documentWithKey:key version:FSTTestVersion(version)];
}

static NSArray<NSString *> *FSTTestSplitPath(NSString *path) {
  if ([path isEqualToString:@""]) {
    return @[];
  } else {
    return [path componentsSeparatedByString:@"/"];
  }
}

FSTResourcePath *FSTTestPath(NSString *path) {
  return [FSTResourcePath pathWithSegments:FSTTestSplitPath(path)];
}

FSTDocumentKeyReference *FSTTestRef(NSString *projectID, NSString *database, NSString *path) {
  FSTDatabaseID *databaseID = [FSTDatabaseID databaseIDWithProject:projectID database:database];
  return [[FSTDocumentKeyReference alloc] initWithKey:FSTTestDocKey(path) databaseID:databaseID];
}

FSTQuery *FSTTestQuery(NSString *path) {
  return [FSTQuery queryWithPath:FSTTestPath(path)];
}

id<FSTFilter> FSTTestFilter(NSString *field, NSString *opString, id value) {
  FSTFieldPath *path = FSTTestFieldPath(field);
  FSTRelationFilterOperator op;
  if ([opString isEqualToString:@"<"]) {
    op = FSTRelationFilterOperatorLessThan;
  } else if ([opString isEqualToString:@"<="]) {
    op = FSTRelationFilterOperatorLessThanOrEqual;
  } else if ([opString isEqualToString:@"=="]) {
    op = FSTRelationFilterOperatorEqual;
  } else if ([opString isEqualToString:@">="]) {
    op = FSTRelationFilterOperatorGreaterThanOrEqual;
  } else if ([opString isEqualToString:@">"]) {
    op = FSTRelationFilterOperatorGreaterThan;
  } else {
    FSTCFail(@"Unsupported operator type: %@", opString);
  }

  FSTFieldValue *data = FSTTestFieldValue(value);
  if ([data isEqual:[FSTDoubleValue nanValue]]) {
    FSTCAssert(op == FSTRelationFilterOperatorEqual, @"Must use == with NAN.");
    return [[FSTNanFilter alloc] initWithField:path];
  } else if ([data isEqual:[FSTNullValue nullValue]]) {
    FSTCAssert(op == FSTRelationFilterOperatorEqual, @"Must use == with Null.");
    return [[FSTNullFilter alloc] initWithField:path];
  } else {
    return [FSTRelationFilter filterWithField:path filterOperator:op value:data];
  }
}

FSTSortOrder *FSTTestOrderBy(NSString *field, NSString *direction) {
  FSTFieldPath *path = FSTTestFieldPath(field);
  BOOL ascending;
  if ([direction isEqualToString:@"asc"]) {
    ascending = YES;
  } else if ([direction isEqualToString:@"desc"]) {
    ascending = NO;
  } else {
    FSTCFail(@"Unsupported direction: %@", direction);
  }
  return [FSTSortOrder sortOrderWithFieldPath:path ascending:ascending];
}

NSComparator FSTTestDocComparator(NSString *fieldPath) {
  FSTQuery *query = [FSTTestQuery(@"docs")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:FSTTestFieldPath(fieldPath)
                                                        ascending:YES]];
  return [query comparator];
}

FSTDocumentSet *FSTTestDocSet(NSComparator comp, NSArray<FSTDocument *> *docs) {
  FSTDocumentSet *docSet = [FSTDocumentSet documentSetWithComparator:comp];
  for (FSTDocument *doc in docs) {
    docSet = [docSet documentSetByAddingDocument:doc];
  }
  return docSet;
}

FSTSetMutation *FSTTestSetMutation(NSString *path, NSDictionary<NSString *, id> *values) {
  return [[FSTSetMutation alloc] initWithKey:FSTTestDocKey(path)
                                       value:FSTTestObjectValue(values)
                                precondition:[FSTPrecondition none]];
}

FSTPatchMutation *FSTTestPatchMutation(NSString *path,
                                       NSDictionary<NSString *, id> *values,
                                       NSArray<FSTFieldPath *> *_Nullable updateMask) {
  BOOL merge = updateMask != nil;

  __block FSTObjectValue *objectValue = [FSTObjectValue objectValue];
  NSMutableArray<FSTFieldPath *> *fieldMaskPaths = [NSMutableArray array];
  [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    FSTFieldPath *path = FSTTestFieldPath(key);
    [fieldMaskPaths addObject:path];
    if (![value isEqual:kDeleteSentinel]) {
      FSTFieldValue *parsedValue = FSTTestFieldValue(value);
      objectValue = [objectValue objectBySettingValue:parsedValue forPath:path];
    }
  }];

  FSTDocumentKey *key = [FSTDocumentKey keyWithPath:FSTTestPath(path)];
  FSTFieldMask *mask = [[FSTFieldMask alloc] initWithFields:merge ? updateMask : fieldMaskPaths];
  return [[FSTPatchMutation alloc] initWithKey:key
                                     fieldMask:mask
                                         value:objectValue
                                  precondition:[FSTPrecondition preconditionWithExists:YES]];
}

// For now this only creates TransformMutations with server timestamps.
FSTTransformMutation *FSTTestTransformMutation(NSString *path,
                                               NSArray<NSString *> *serverTimestampFields) {
  FSTDocumentKey *key = [FSTDocumentKey keyWithPath:FSTTestPath(path)];
  NSMutableArray<FSTFieldTransform *> *fieldTransforms = [NSMutableArray array];
  for (NSString *field in serverTimestampFields) {
    FSTFieldPath *fieldPath = FSTTestFieldPath(field);
    id<FSTTransformOperation> transformOp = [FSTServerTimestampTransform serverTimestampTransform];
    FSTFieldTransform *transform =
        [[FSTFieldTransform alloc] initWithPath:fieldPath transform:transformOp];
    [fieldTransforms addObject:transform];
  }
  return [[FSTTransformMutation alloc] initWithKey:key fieldTransforms:fieldTransforms];
}

FSTDeleteMutation *FSTTestDeleteMutation(NSString *path) {
  return [[FSTDeleteMutation alloc] initWithKey:FSTTestDocKey(path)
                                   precondition:[FSTPrecondition none]];
}

FSTMaybeDocumentDictionary *FSTTestDocUpdates(NSArray<FSTMaybeDocument *> *docs) {
  FSTMaybeDocumentDictionary *updates = [FSTMaybeDocumentDictionary maybeDocumentDictionary];
  for (FSTMaybeDocument *doc in docs) {
    updates = [updates dictionaryBySettingObject:doc forKey:doc.key];
  }
  return updates;
}

FSTViewSnapshot *_Nullable FSTTestApplyChanges(FSTView *view,
                                               NSArray<FSTMaybeDocument *> *docs,
                                               FSTTargetChange *_Nullable targetChange) {
  return [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(docs)]
                          targetChange:targetChange]
      .snapshot;
}

FSTRemoteEvent *FSTTestUpdateRemoteEvent(FSTMaybeDocument *doc,
                                         NSArray<NSNumber *> *updatedInTargets,
                                         NSArray<NSNumber *> *removedFromTargets) {
  FSTDocumentWatchChange *change =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:updatedInTargets
                                              removedTargetIDs:removedFromTargets
                                                   documentKey:doc.key
                                                      document:doc];
  NSMutableDictionary<NSNumber *, FSTQueryData *> *listens = [NSMutableDictionary dictionary];
  FSTQueryData *dummyQueryData = [FSTQueryData alloc];
  for (NSNumber *targetID in updatedInTargets) {
    listens[targetID] = dummyQueryData;
  }
  for (NSNumber *targetID in removedFromTargets) {
    listens[targetID] = dummyQueryData;
  }
  NSMutableDictionary<NSNumber *, NSNumber *> *pending = [NSMutableDictionary dictionary];
  FSTWatchChangeAggregator *aggregator =
      [[FSTWatchChangeAggregator alloc] initWithSnapshotVersion:doc.version
                                                  listenTargets:listens
                                         pendingTargetResponses:pending];
  [aggregator addWatchChange:change];
  return [aggregator remoteEvent];
}

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion snapshotVersion) {
  if (snapshotVersion == 0) {
    return nil;
  }

  NSString *snapshotString = [NSString stringWithFormat:@"snapshot-%" PRId64, snapshotVersion];
  return [snapshotString dataUsingEncoding:NSUTF8StringEncoding];
}

FSTLocalViewChanges *FSTTestViewChanges(FSTQuery *query,
                                        NSArray<NSString *> *addedKeys,
                                        NSArray<NSString *> *removedKeys) {
  FSTDocumentKeySet *added = [FSTDocumentKeySet keySet];
  for (NSString *keyPath in addedKeys) {
    FSTDocumentKey *key = FSTTestDocKey(keyPath);
    added = [added setByAddingObject:key];
  }
  FSTDocumentKeySet *removed = [FSTDocumentKeySet keySet];
  for (NSString *keyPath in removedKeys) {
    FSTDocumentKey *key = FSTTestDocKey(keyPath);
    removed = [removed setByAddingObject:key];
  }
  return [FSTLocalViewChanges changesForQuery:query addedKeys:added removedKeys:removed];
}

NS_ASSUME_NONNULL_END
