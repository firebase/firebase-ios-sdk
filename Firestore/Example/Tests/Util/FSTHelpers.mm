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
#import <FirebaseFirestore/FIRTimestamp.h>

#include <cinttypes>
#include <list>
#include <map>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

/** A string sentinel that can be used with FSTTestPatchMutation() to mark a field for deletion. */
static NSString *const kDeleteSentinel = @"<DELETE>";

FIRTimestamp *FSTTestTimestamp(int year, int month, int day, int hour, int minute, int second) {
  NSDate *date = FSTTestDate(year, month, day, hour, minute, second);
  return [FIRTimestamp timestampWithDate:date];
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

FSTUserDataConverter *FSTTestUserDataConverter() {
  // This owns the DatabaseIds since we do not have FirestoreClient instance to own them.
  static DatabaseId database_id{"project", DatabaseId::kDefault};
  FSTUserDataConverter *converter =
      [[FSTUserDataConverter alloc] initWithDatabaseID:&database_id
                                          preConverter:^id _Nullable(id _Nullable input) {
                                            return input;
                                          }];
  return converter;
}

FSTFieldValue *FSTTestFieldValue(id _Nullable value) {
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  // HACK: We use parsedQueryValue: since it accepts scalars as well as arrays / objects, and
  // our tests currently use FSTTestFieldValue() pretty generically so we don't know the intent.
  return [converter parsedQueryValue:value];
}

FSTObjectValue *FSTTestObjectValue(NSDictionary<NSString *, id> *data) {
  FSTFieldValue *wrapped = FSTTestFieldValue(data);
  HARD_ASSERT([wrapped isKindOfClass:[FSTObjectValue class]], "Unsupported value: %s", data);
  return (FSTObjectValue *)wrapped;
}

FSTDocumentKey *FSTTestDocKey(NSString *path) {
  return [FSTDocumentKey keyWithPathString:path];
}

FSTDocument *FSTTestDoc(const absl::string_view path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        BOOL hasMutations) {
  DocumentKey key = testutil::Key(path);
  return [FSTDocument documentWithData:FSTTestObjectValue(data)
                                   key:key
                               version:testutil::Version(version)
                     hasLocalMutations:hasMutations];
}

FSTDeletedDocument *FSTTestDeletedDoc(const absl::string_view path,
                                      FSTTestSnapshotVersion version) {
  DocumentKey key = testutil::Key(path);
  return [FSTDeletedDocument documentWithKey:key version:testutil::Version(version)];
}

FSTDocumentKeyReference *FSTTestRef(const absl::string_view projectID,
                                    const absl::string_view database,
                                    NSString *path) {
  // This owns the DatabaseIds since we do not have FirestoreClient instance to own them.
  static std::list<DatabaseId> database_ids;
  database_ids.emplace_back(projectID, database);
  return [[FSTDocumentKeyReference alloc] initWithKey:FSTTestDocKey(path)
                                           databaseID:&database_ids.back()];
}

FSTQuery *FSTTestQuery(const absl::string_view path) {
  return [FSTQuery queryWithPath:testutil::Resource(path)];
}

id<FSTFilter> FSTTestFilter(const absl::string_view field, NSString *opString, id value) {
  const FieldPath path = testutil::Field(field);
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
  } else if ([opString isEqualToString:@"array_contains"]) {
    op = FSTRelationFilterOperatorArrayContains;
  } else {
    HARD_FAIL("Unsupported operator type: %s", opString);
  }

  FSTFieldValue *data = FSTTestFieldValue(value);
  if ([data isEqual:[FSTDoubleValue nanValue]]) {
    HARD_ASSERT(op == FSTRelationFilterOperatorEqual, "Must use == with NAN.");
    return [[FSTNanFilter alloc] initWithField:path];
  } else if ([data isEqual:[FSTNullValue nullValue]]) {
    HARD_ASSERT(op == FSTRelationFilterOperatorEqual, "Must use == with Null.");
    return [[FSTNullFilter alloc] initWithField:path];
  } else {
    return [FSTRelationFilter filterWithField:path filterOperator:op value:data];
  }
}

FSTSortOrder *FSTTestOrderBy(const absl::string_view field, NSString *direction) {
  const FieldPath path = testutil::Field(field);
  BOOL ascending;
  if ([direction isEqualToString:@"asc"]) {
    ascending = YES;
  } else if ([direction isEqualToString:@"desc"]) {
    ascending = NO;
  } else {
    HARD_FAIL("Unsupported direction: %s", direction);
  }
  return [FSTSortOrder sortOrderWithFieldPath:path ascending:ascending];
}

NSComparator FSTTestDocComparator(const absl::string_view fieldPath) {
  FSTQuery *query = [FSTTestQuery("docs")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field(fieldPath)
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
                                precondition:Precondition::None()];
}

FSTPatchMutation *FSTTestPatchMutation(const absl::string_view path,
                                       NSDictionary<NSString *, id> *values,
                                       const std::vector<FieldPath> &updateMask) {
  BOOL merge = !updateMask.empty();

  __block FSTObjectValue *objectValue = [FSTObjectValue objectValue];
  __block std::vector<FieldPath> fieldMaskPaths;
  [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    const FieldPath path = testutil::Field(util::MakeStringView(key));
    fieldMaskPaths.push_back(path);
    if (![value isEqual:kDeleteSentinel]) {
      FSTFieldValue *parsedValue = FSTTestFieldValue(value);
      objectValue = [objectValue objectBySettingValue:parsedValue forPath:path];
    }
  }];

  DocumentKey key = testutil::Key(path);
  FieldMask mask(merge ? updateMask : fieldMaskPaths);
  return [[FSTPatchMutation alloc] initWithKey:key
                                     fieldMask:mask
                                         value:objectValue
                                  precondition:Precondition::Exists(true)];
}

FSTTransformMutation *FSTTestTransformMutation(NSString *path, NSDictionary<NSString *, id> *data) {
  FSTDocumentKey *key = [FSTDocumentKey keyWithPath:testutil::Resource(util::MakeStringView(path))];
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  FSTParsedUpdateData *result = [converter parsedUpdateData:data];
  HARD_ASSERT(result.data.value.count == 0,
              "FSTTestTransformMutation() only expects transforms; no other data");
  return [[FSTTransformMutation alloc] initWithKey:key
                                   fieldTransforms:std::move(result.fieldTransforms)];
}

FSTDeleteMutation *FSTTestDeleteMutation(NSString *path) {
  return
      [[FSTDeleteMutation alloc] initWithKey:FSTTestDocKey(path) precondition:Precondition::None()];
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
  DocumentKeySet added;
  for (NSString *keyPath in addedKeys) {
    added = added.insert(testutil::Key(util::MakeStringView(keyPath)));
  }
  DocumentKeySet removed;
  for (NSString *keyPath in removedKeys) {
    removed = removed.insert(testutil::Key(util::MakeStringView(keyPath)));
  }
  return [FSTLocalViewChanges changesForQuery:query
                                    addedKeys:std::move(added)
                                  removedKeys:std::move(removed)];
}

NS_ASSUME_NONNULL_END
