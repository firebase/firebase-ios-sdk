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
#include <set>
#include <utility>

#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::core::Filter;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::remote::WatchChangeAggregator;

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
  FSTUserDataConverter *converter =
      [[FSTUserDataConverter alloc] initWithDatabaseID:DatabaseId("project")
                                          preConverter:^id _Nullable(id _Nullable input) {
                                            return input;
                                          }];
  return converter;
}

FieldValue FSTTestFieldValue(id _Nullable value) {
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  // HACK: We use parsedQueryValue: since it accepts scalars as well as arrays / objects, and
  // our tests currently use FSTTestFieldValue() pretty generically so we don't know the intent.
  return [converter parsedQueryValue:value];
}

ObjectValue FSTTestObjectValue(NSDictionary<NSString *, id> *data) {
  FieldValue wrapped = FSTTestFieldValue(data);
  HARD_ASSERT(wrapped.type() == FieldValue::Type::Object, "Unsupported value: %s", data);
  return ObjectValue(std::move(wrapped));
}

DocumentKey FSTTestDocKey(NSString *path) {
  return DocumentKey::FromPathString(util::MakeString(path));
}

FSTDocument *FSTTestDoc(const absl::string_view path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        DocumentState documentState) {
  DocumentKey key = testutil::Key(path);
  return [FSTDocument documentWithData:FSTTestObjectValue(data)
                                   key:key
                               version:testutil::Version(version)
                                 state:documentState];
}

FSTDeletedDocument *FSTTestDeletedDoc(const absl::string_view path,
                                      FSTTestSnapshotVersion version,
                                      BOOL hasCommittedMutations) {
  DocumentKey key = testutil::Key(path);
  return [FSTDeletedDocument documentWithKey:key
                                     version:testutil::Version(version)
                       hasCommittedMutations:hasCommittedMutations];
}

FSTUnknownDocument *FSTTestUnknownDoc(const absl::string_view path,
                                      FSTTestSnapshotVersion version) {
  DocumentKey key = testutil::Key(path);
  return [FSTUnknownDocument documentWithKey:key version:testutil::Version(version)];
}

FSTDocumentKeyReference *FSTTestRef(std::string projectID, std::string database, NSString *path) {
  return [[FSTDocumentKeyReference alloc] initWithKey:FSTTestDocKey(path)
                                           databaseID:DatabaseId(projectID, database)];
}

FSTQuery *FSTTestQuery(const absl::string_view path) {
  return [FSTQuery queryWithPath:testutil::Resource(path)];
}

FSTFilter *FSTTestFilter(const absl::string_view field, NSString *opString, id value) {
  const FieldPath path = testutil::Field(field);
  Filter::Operator op;
  if ([opString isEqualToString:@"<"]) {
    op = Filter::Operator::LessThan;
  } else if ([opString isEqualToString:@"<="]) {
    op = Filter::Operator::LessThanOrEqual;
  } else if ([opString isEqualToString:@"=="]) {
    op = Filter::Operator::Equal;
  } else if ([opString isEqualToString:@">="]) {
    op = Filter::Operator::GreaterThanOrEqual;
  } else if ([opString isEqualToString:@">"]) {
    op = Filter::Operator::GreaterThan;
  } else if ([opString isEqualToString:@"array_contains"]) {
    op = Filter::Operator::ArrayContains;
  } else {
    HARD_FAIL("Unsupported operator type: %s", opString);
  }

  FieldValue data = FSTTestFieldValue(value);

  return [FSTFilter filterWithField:path filterOperator:op value:data];
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

DocumentComparator FSTTestDocComparator(const absl::string_view fieldPath) {
  FSTQuery *query = [FSTTestQuery("docs")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field(fieldPath)
                                                        ascending:YES]];
  return [query comparator];
}

DocumentSet FSTTestDocSet(DocumentComparator comp, NSArray<FSTDocument *> *docs) {
  DocumentSet docSet{std::move(comp)};
  for (FSTDocument *doc in docs) {
    docSet = docSet.insert(doc);
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

  __block ObjectValue objectValue = ObjectValue::Empty();
  __block std::set<FieldPath> fieldMaskPaths;
  [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    const FieldPath path = testutil::Field(util::MakeString(key));
    fieldMaskPaths.insert(path);
    if (![value isEqual:kDeleteSentinel]) {
      FieldValue parsedValue = FSTTestFieldValue(value);
      objectValue = objectValue.Set(path, std::move(parsedValue));
    }
  }];

  DocumentKey key = testutil::Key(path);
  FieldMask mask(merge ? std::set<FieldPath>(updateMask.begin(), updateMask.end())
                       : fieldMaskPaths);
  return [[FSTPatchMutation alloc]
       initWithKey:key
         fieldMask:mask
             value:objectValue
      precondition:merge ? Precondition::None() : Precondition::Exists(true)];
}

FSTTransformMutation *FSTTestTransformMutation(NSString *path, NSDictionary<NSString *, id> *data) {
  DocumentKey key{testutil::Resource(util::MakeString(path))};
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  ParsedUpdateData result = [converter parsedUpdateData:data];
  HARD_ASSERT(result.data().size() == 0,
              "FSTTestTransformMutation() only expects transforms; no other data");
  return [[FSTTransformMutation alloc] initWithKey:key fieldTransforms:result.field_transforms()];
}

FSTDeleteMutation *FSTTestDeleteMutation(NSString *path) {
  return [[FSTDeleteMutation alloc] initWithKey:FSTTestDocKey(path)
                                   precondition:Precondition::None()];
}

MaybeDocumentMap FSTTestDocUpdates(NSArray<FSTMaybeDocument *> *docs) {
  MaybeDocumentMap updates;
  for (FSTMaybeDocument *doc in docs) {
    updates = updates.insert(doc.key, doc);
  }
  return updates;
}

absl::optional<ViewSnapshot> FSTTestApplyChanges(FSTView *view,
                                                 NSArray<FSTMaybeDocument *> *docs,
                                                 const absl::optional<TargetChange> &targetChange) {
  FSTViewChange *change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(docs)]
                       targetChange:targetChange];
  return std::move(change.snapshot);
}

namespace firebase {
namespace firestore {
namespace remote {

TestTargetMetadataProvider TestTargetMetadataProvider::CreateSingleResultProvider(
    DocumentKey document_key,
    const std::vector<TargetId> &listen_targets,
    const std::vector<TargetId> &limbo_targets) {
  TestTargetMetadataProvider metadata_provider;
  FSTQuery *query = [FSTQuery queryWithPath:document_key.path()];

  for (TargetId target_id : listen_targets) {
    FSTQueryData *query_data = [[FSTQueryData alloc] initWithQuery:query
                                                          targetID:target_id
                                              listenSequenceNumber:0
                                                           purpose:FSTQueryPurposeListen];
    metadata_provider.SetSyncedKeys(DocumentKeySet{document_key}, query_data);
  }
  for (TargetId target_id : limbo_targets) {
    FSTQueryData *query_data = [[FSTQueryData alloc] initWithQuery:query
                                                          targetID:target_id
                                              listenSequenceNumber:0
                                                           purpose:FSTQueryPurposeLimboResolution];
    metadata_provider.SetSyncedKeys(DocumentKeySet{document_key}, query_data);
  }

  return metadata_provider;
}

TestTargetMetadataProvider TestTargetMetadataProvider::CreateSingleResultProvider(
    DocumentKey document_key, const std::vector<TargetId> &targets) {
  return CreateSingleResultProvider(document_key, targets, /*limbo_targets=*/{});
}

TestTargetMetadataProvider TestTargetMetadataProvider::CreateEmptyResultProvider(
    const DocumentKey &document_key, const std::vector<TargetId> &targets) {
  TestTargetMetadataProvider metadata_provider;
  FSTQuery *query = [FSTQuery queryWithPath:document_key.path()];

  for (TargetId target_id : targets) {
    FSTQueryData *query_data = [[FSTQueryData alloc] initWithQuery:query
                                                          targetID:target_id
                                              listenSequenceNumber:0
                                                           purpose:FSTQueryPurposeListen];
    metadata_provider.SetSyncedKeys(DocumentKeySet{}, query_data);
  }

  return metadata_provider;
}

void TestTargetMetadataProvider::SetSyncedKeys(DocumentKeySet keys, FSTQueryData *query_data) {
  synced_keys_[query_data.targetID] = keys;
  query_data_[query_data.targetID] = query_data;
}

DocumentKeySet TestTargetMetadataProvider::GetRemoteKeysForTarget(TargetId target_id) const {
  auto it = synced_keys_.find(target_id);
  HARD_ASSERT(it != synced_keys_.end(), "Cannot process unknown target %s", target_id);
  return it->second;
}

FSTQueryData *TestTargetMetadataProvider::GetQueryDataForTarget(TargetId target_id) const {
  auto it = query_data_.find(target_id);
  HARD_ASSERT(it != query_data_.end(), "Cannot process unknown target %s", target_id);
  return it->second;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

using firebase::firestore::remote::TestTargetMetadataProvider;

RemoteEvent FSTTestAddedRemoteEvent(FSTMaybeDocument *doc,
                                    const std::vector<TargetId> &addedToTargets) {
  HARD_ASSERT(![doc isKindOfClass:[FSTDocument class]] || ![(FSTDocument *)doc hasLocalMutations],
              "Docs from remote updates shouldn't have local changes.");
  DocumentWatchChange change{addedToTargets, {}, doc.key, doc};
  auto metadataProvider =
      TestTargetMetadataProvider::CreateEmptyResultProvider(doc.key, addedToTargets);
  WatchChangeAggregator aggregator{&metadataProvider};
  aggregator.HandleDocumentChange(change);
  return aggregator.CreateRemoteEvent(doc.version);
}

TargetChange FSTTestTargetChangeMarkCurrent() {
  return {[NSData data],
          /*current=*/true,
          /*added_documents=*/DocumentKeySet{},
          /*modified_documents=*/DocumentKeySet{},
          /*removed_documents=*/DocumentKeySet{}};
}

TargetChange FSTTestTargetChangeAckDocuments(DocumentKeySet docs) {
  return {[NSData data],
          /*current=*/true,
          /*added_documents*/ std::move(docs),
          /*modified_documents*/ DocumentKeySet{},
          /*removed_documents*/ DocumentKeySet{}};
}

RemoteEvent FSTTestUpdateRemoteEventWithLimboTargets(
    FSTMaybeDocument *doc,
    const std::vector<TargetId> &updatedInTargets,
    const std::vector<TargetId> &removedFromTargets,
    const std::vector<TargetId> &limboTargets) {
  HARD_ASSERT(![doc isKindOfClass:[FSTDocument class]] || ![(FSTDocument *)doc hasLocalMutations],
              "Docs from remote updates shouldn't have local changes.");
  DocumentWatchChange change{updatedInTargets, removedFromTargets, doc.key, doc};

  std::vector<TargetId> listens = updatedInTargets;
  listens.insert(listens.end(), removedFromTargets.begin(), removedFromTargets.end());

  auto metadataProvider =
      TestTargetMetadataProvider::CreateSingleResultProvider(doc.key, listens, limboTargets);
  WatchChangeAggregator aggregator{&metadataProvider};
  aggregator.HandleDocumentChange(change);
  return aggregator.CreateRemoteEvent(doc.version);
}

RemoteEvent FSTTestUpdateRemoteEvent(FSTMaybeDocument *doc,
                                     const std::vector<TargetId> &updatedInTargets,
                                     const std::vector<TargetId> &removedFromTargets) {
  return FSTTestUpdateRemoteEventWithLimboTargets(doc, updatedInTargets, removedFromTargets, {});
}

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion snapshotVersion) {
  if (snapshotVersion == 0) {
    return nil;
  }

  NSString *snapshotString = [NSString stringWithFormat:@"snapshot-%" PRId64, snapshotVersion];
  return [snapshotString dataUsingEncoding:NSUTF8StringEncoding];
}

FSTLocalViewChanges *FSTTestViewChanges(TargetId targetID,
                                        NSArray<NSString *> *addedKeys,
                                        NSArray<NSString *> *removedKeys) {
  DocumentKeySet added;
  for (NSString *keyPath in addedKeys) {
    added = added.insert(testutil::Key(util::MakeString(keyPath)));
  }
  DocumentKeySet removed;
  for (NSString *keyPath in removedKeys) {
    removed = removed.insert(testutil::Key(util::MakeString(keyPath)));
  }
  return [FSTLocalViewChanges changesForTarget:targetID
                                     addedKeys:std::move(added)
                                   removedKeys:std::move(removed)];
}

NS_ASSUME_NONNULL_END
